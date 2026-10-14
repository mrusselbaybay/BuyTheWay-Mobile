import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../screens/buyer/checkout/voucher_quote.dart';

import '../screens/buyer/buyer_models.dart';
import 'api_service.dart';

/// Buyer storefront + account API — the same endpoints the web buyer uses
/// (public /api/products* catalog and the bearer-authenticated
/// /api/buyer/* group in routes/buyer.php). Kept apart from [ApiService]
/// so the buyer module stays self-contained; it reuses its base URL and
/// [ApiException].
class BuyerApiService {
  BuyerApiService({this.token});

  String? token;

  static const _timeout = Duration(seconds: 20);

  /// Web origin (base URL without `/api`) — product images can come back
  /// as site-relative paths such as the placeholder.
  static String get origin => ApiService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  Uri _uri(String path, [String? query]) =>
      Uri.parse('${ApiService.baseUrl}$path${query == null || query.isEmpty ? '' : '?$query'}');

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _send(String method, String path, {String? query, Object? body}) async {
    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);
    http.Response response;
    try {
      final future = switch (method) {
        'GET' => http.get(uri, headers: _headers),
        'POST' => http.post(uri, headers: _headers, body: encoded),
        'PUT' => http.put(uri, headers: _headers, body: encoded),
        'DELETE' => http.delete(uri, headers: _headers, body: encoded),
        _ => throw ArgumentError(method),
      };
      response = await future.timeout(_timeout);
    } on TimeoutException {
      throw ApiException(message: 'The server took too long to respond. Please try again.', statusCode: 408);
    } on SocketException {
      throw ApiException(message: 'No internet connection. Check your network and try again.', statusCode: 0);
    } on http.ClientException {
      throw ApiException(message: 'Could not reach the server. Please try again.', statusCode: 0);
    }

    Map<String, dynamic> decoded = {};
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map) decoded = Map<String, dynamic>.from(raw);
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    final errors = decoded['errors'];
    var message = decoded['message'] is String ? decoded['message'] as String : '';
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) message = '${first.first}';
    }
    if (response.statusCode == 401) message = 'Your session has expired. Please sign in again.';
    throw ApiException(
      message: message.isEmpty ? 'Request failed (${response.statusCode}).' : message,
      statusCode: response.statusCode,
      errors: errors is Map ? Map<String, dynamic>.from(errors) : null,
    );
  }

  List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

  String _q(Map<String, String?> params) => params.entries
      .where((e) => e.value != null && e.value!.isNotEmpty)
      .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value!)}')
      .join('&');

  // ---------------- Catalog (public) ----------------

  /// Newest-first catalog page. Returns the products and the last page.
  Future<(List<Product>, int)> products({
    String? search,
    String? category,
    String? sellerId,
    String? sort,
    num? priceMin,
    num? priceMax,
    num? minRating,
    bool inStock = false,
    bool onSale = false,
    int page = 1,
    int perPage = 20,
  }) async {
    final body = await _send('GET', '/products',
        query: _q({
          'search': search,
          'category': category,
          'seller_id': sellerId,
          'sort': sort,
          'price_min': priceMin?.toString(),
          'price_max': priceMax?.toString(),
          'min_rating': minRating?.toString(),
          'in_stock': inStock ? '1' : null,
          'on_sale': onSale ? '1' : null,
          'page': '$page',
          'per_page': '$perPage',
        }));
    final meta = body['meta'] is Map ? body['meta'] as Map : const {};
    final lastPage = meta['last_page'] is num ? (meta['last_page'] as num).toInt() : page;
    return (_list(body['data']).map(Product.fromJson).toList(), lastPage);
  }

  /// Category counts, price range and rating availability for a search's results.
  Future<Map<String, dynamic>> searchFacets(String search, {String? sellerId}) async {
    final body = await _send('GET', '/products', query: _q({'search': search, 'seller_id': sellerId, 'facets': '1', 'per_page': '1'}));
    return body['facets'] is Map ? Map<String, dynamic>.from(body['facets'] as Map) : {};
  }

  /// Header-search suggestions: a few products and stores matching [query].
  Future<({List<Map<String, dynamic>> products, List<Map<String, dynamic>> stores})> searchSuggestions(String query, {String? sellerId}) async {
    final body = await _send('GET', '/search/suggestions', query: _q({'q': query, 'seller_id': sellerId}));
    return (products: _list(body['products']), stores: _list(body['stores']));
  }

  /// null when the product no longer exists (404).
  /// Marks a review helpful / removes the mark. Returns the new (count, liked).
  Future<(int, bool)> setReviewLike(String reviewId, bool liked) async {
    final path = '/reviews/${Uri.encodeComponent(reviewId)}/like';
    final body = await _send(liked ? 'PUT' : 'DELETE', path);
    final data = body['data'] is Map ? body['data'] as Map : const {};
    return ((data['helpfulCount'] as num?)?.toInt() ?? 0, data['isHelpful'] == true);
  }

  /// A shop's claimable vouchers (shop discounts and free shipping).
  Future<List<Coupon>> storeVouchers(String id) async {
    final body = await _send('GET', '/stores/${Uri.encodeComponent(id)}/vouchers');
    return _list(body['data']).map(Coupon.fromJson).toList();
  }

  /// Category names with product counts for one shop.
  Future<List<(String, int)>> storeCategories(String id) async {
    final body = await _send('GET', '/products', query: 'seller_id=${Uri.encodeQueryComponent(id)}&facets=1&per_page=1');
    final facets = body['facets'] is Map ? body['facets'] as Map : const {};
    return _list(facets['categories']).map((c) => ('${c['name']}', (c['count'] as num?)?.toInt() ?? 0)).toList();
  }

  /// Reports a shop (reason is one of the server's report reason keys).
  Future<void> reportStore(String storeId,
          {required String reason, required String details, bool anonymous = false, List<String> evidence = const []}) =>
      _send('POST', '/buyer/reports',
          body: {'target_type': 'store', 'target_id': storeId, 'reason': reason, 'details': details, 'anonymous': anonymous, 'evidence': evidence});

  /// Stages one report evidence file; pass the returned paths to [reportStore].
  Future<String> uploadReportEvidence(List<int> bytes, String fileName) async {
    final body = await _multipart('/buyer/reports/evidence', 'file', bytes, fileName);
    return '${body['path']}';
  }

  Future<void> blockShop(String id) => _send('POST', '/buyer/stores/${Uri.encodeComponent(id)}/block');

  /// Reviews across every product of a shop (newest first), with the shop-wide star breakdown.
  Future<(List<Review>, ReviewSummary, int)> storeReviews(String id, {int page = 1, int perPage = 10, int? rating, bool withImages = false}) async {
    final body = await _send('GET', '/stores/${Uri.encodeComponent(id)}/reviews',
        query: _q({'page': '$page', 'per_page': '$perPage', 'rating': rating?.toString(), 'has_images': withImages ? '1' : null}));
    final meta = body['meta'] is Map ? body['meta'] as Map : const {};
    final lastPage = meta['last_page'] is num ? (meta['last_page'] as num).toInt() : page;
    final summary = body['summary'] is Map ? ReviewSummary.fromJson(Map<String, dynamic>.from(body['summary'])) : const ReviewSummary();
    return (_list(body['data']).map(Review.fromJson).toList(), summary, lastPage);
  }

  /// Public store profile (name, logo, rating, counts) for the product page's shop card.
  Future<Map<String, dynamic>> storeInfo(String id) async {
    final body = await _send('GET', '/stores/${Uri.encodeComponent(id)}');
    return body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : {};
  }

  Future<Product?> product(String id) async {
    try {
      final body = await _send('GET', '/products/${Uri.encodeComponent(id)}');
      return body['data'] is Map ? Product.fromJson(Map<String, dynamic>.from(body['data'])) : null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<(List<Review>, ReviewSummary, int)> productReviews(String id,
      {int page = 1, int perPage = 10, int? rating, bool withImages = false}) async {
    final body = await _send('GET', '/products/${Uri.encodeComponent(id)}/reviews',
        query: _q({
          'page': '$page',
          'per_page': '$perPage',
          'rating': rating?.toString(),
          'has_images': withImages ? '1' : null,
        }));
    final meta = body['meta'] is Map ? body['meta'] as Map : const {};
    final lastPage = meta['last_page'] is num ? (meta['last_page'] as num).toInt() : page;
    final summary = body['summary'] is Map ? ReviewSummary.fromJson(Map<String, dynamic>.from(body['summary'])) : const ReviewSummary();
    return (_list(body['data']).map(Review.fromJson).toList(), summary, lastPage);
  }

  Future<List<Coupon>> productCoupons(String id) async {
    final body = await _send('GET', '/products/${Uri.encodeComponent(id)}/coupons');
    return _list(body['data']).map(Coupon.fromJson).toList();
  }

  // ---------------- Coupons ----------------

  Future<List<Coupon>> couponWallet() async {
    final body = await _send('GET', '/buyer/coupons');
    return _list(body['data']).map(Coupon.fromJson).toList();
  }

  /// Wallet plus the total vouchers have saved this buyer so far.
  Future<(List<Coupon>, double)> voucherWallet() async {
    final body = await _send('GET', '/buyer/vouchers');
    final meta = body['meta'] is Map ? body['meta'] as Map : const {};
    return (_list(body['data']).map(Coupon.fromJson).toList(), (meta['saved'] as num?)?.toDouble() ?? 0);
  }

  // ---------------- Cart (shared with the website) ----------------

  Future<List<Map<String, dynamic>>> fetchCart() async => _list((await _send('GET', '/buyer/cart'))['data']);

  /// Replaces the saved cart with [items] (last write wins).
  Future<List<Map<String, dynamic>>> saveCart(List<Map<String, dynamic>> items) async => _list((await _send('PUT', '/buyer/cart', body: {'items': items}))['data']);

  /// Folds this device's cart into the saved one (done once, on first sync).
  Future<List<Map<String, dynamic>>> mergeCart(List<Map<String, dynamic>> items) async => _list((await _send('POST', '/buyer/cart/merge', body: {'items': items}))['data']);

  Future<Coupon> claimCoupon(String couponId) async {
    final body = await _send('POST', '/buyer/coupons/${Uri.encodeComponent(couponId)}/claim');
    return Coupon.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// [lines]: `{key, product_id, variant_id}` — returns quotes by key.
  /// Values every applicable shop voucher and BuyTheWay voucher for this cart
  /// (server prices) and returns the server's best pick for each.
  /// [selected]: the buyer's own picks, `{sellerId: {discount, shipping}}`.
  Future<VoucherQuote> quoteVouchers(
    List<Map<String, dynamic>> lines, {
    required String shippingMethod,
    String? addressId,
    Map<String, Map<String, String?>>? selected,
  }) async {
    final body = await _send('POST', '/buyer/vouchers/quote', body: {
      'lines': lines,
      'shipping_method': shippingMethod,
      if (addressId != null) 'address_id': addressId,
      if (selected != null) 'selected': selected,
    });
    final data = body['data'];
    return data is Map ? VoucherQuote.fromJson(Map<String, dynamic>.from(data)) : VoucherQuote.empty;
  }

  // ---------------- Checkout ----------------

  Future<(List<ShippingOption>, int)> shippingOptions(List<String> productIds, {String? addressId}) async {
    final query = [
      ...productIds.map((id) => 'product_ids[]=${Uri.encodeQueryComponent(id)}'),
      if (addressId != null) 'address_id=${Uri.encodeQueryComponent(addressId)}',
    ].join('&');
    final body = await _send('GET', '/buyer/checkout/shipping-options', query: query);
    final data = body['data'] is Map ? Map<String, dynamic>.from(body['data']) : <String, dynamic>{};
    final count = data['sellerCount'] is num ? (data['sellerCount'] as num).toInt() : 1;
    return (_list(data['options']).map(ShippingOption.fromJson).toList(), count < 1 ? 1 : count);
  }

  /// Creates one order per seller; returns the created order references.
  Future<List<String>> checkout(Map<String, dynamic> payload) async {
    final body = await _send('POST', '/buyer/checkout', body: payload);
    return _list(body['data']).map((o) => '${o['id']}').toList();
  }

  // ---------------- Orders ----------------

  Future<List<Order>> orders() async {
    final body = await _send('GET', '/buyer/orders');
    return _list(body['data']).map(Order.fromJson).toList();
  }

  Future<ParcelJourney> orderTracking(String number) async {
    final body = await _send('GET', '/buyer/orders/${Uri.encodeComponent(number)}/tracking');
    return ParcelJourney.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<Order> order(String number) async {
    final body = await _send('GET', '/buyer/orders/${Uri.encodeComponent(number)}');
    return Order.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<Order> cancelOrder(String number, String? reason) async {
    final body = await _send('POST', '/buyer/orders/${Uri.encodeComponent(number)}/cancel', body: {'reason': reason});
    return Order.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<Order> receiveOrder(String number) async {
    final body = await _send('POST', '/buyer/orders/${Uri.encodeComponent(number)}/receive');
    return Order.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  // ---------------- Addresses ----------------

  Future<List<Address>> addresses() async {
    final body = await _send('GET', '/buyer/addresses');
    return _list(body['data']).map(Address.fromJson).toList();
  }

  Future<Address> saveAddress(Map<String, dynamic> payload, {String? id}) async {
    final body = id == null
        ? await _send('POST', '/buyer/addresses', body: payload)
        : await _send('PUT', '/buyer/addresses/${Uri.encodeComponent(id)}', body: payload);
    return Address.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<void> deleteAddress(String id) => _send('DELETE', '/buyer/addresses/${Uri.encodeComponent(id)}');

  Future<void> setDefaultAddress(String id) => _send('PUT', '/buyer/addresses/${Uri.encodeComponent(id)}/default');

  // ---------------- Wishlist ----------------

  Future<List<String>> wishlist() async {
    final body = await _send('GET', '/buyer/wishlist');
    final data = body['data'];
    return data is List ? data.map((e) => e is Map ? '${e['product_id'] ?? e['id']}' : '$e').toList() : [];
  }

  Future<void> addToWishlist(String productId) => _send('POST', '/buyer/wishlist', body: {'product_id': productId});

  Future<void> removeFromWishlist(String productId) => _send('DELETE', '/buyer/wishlist/${Uri.encodeComponent(productId)}');

  // ---------------- Payment methods ----------------

  Future<List<PaymentMethod>> paymentMethods() async {
    final body = await _send('GET', '/buyer/payment-methods');
    return _list(body['data']).map(PaymentMethod.fromJson).toList();
  }

  /// Only display-safe fields (brand, last4, expiry / masked phone) are
  /// ever sent — never a full card number or CVC.
  Future<void> addPaymentMethod(Map<String, dynamic> payload) => _send('POST', '/buyer/payment-methods', body: payload);

  Future<void> deletePaymentMethod(String id) => _send('DELETE', '/buyer/payment-methods/${Uri.encodeComponent(id)}');

  Future<void> setPrimaryPaymentMethod(String id) => _send('PUT', '/buyer/payment-methods/${Uri.encodeComponent(id)}/primary');

  // ---------------- Reviews ----------------

  Future<List<MyReview>> myReviews() async {
    final body = await _send('GET', '/buyer/reviews');
    return _list(body['data']).map(MyReview.fromJson).toList();
  }

  Future<void> createReview(String orderItemId, int rating, String? comment, {bool anonymous = false}) =>
      _send('POST', '/buyer/reviews', body: {'order_item_id': orderItemId, 'rating': rating, 'comment': comment, 'anonymous': anonymous});

  Future<void> deleteReview(String reviewId) => _send('DELETE', '/buyer/reviews/${Uri.encodeComponent(reviewId)}');

  // ---------------- Returns ----------------

  /// [evidence] are image URLs (data: URLs are accepted, max 3).
  Future<void> requestReturn({
    required String orderItemId,
    required String requestType,
    required String reason,
    String? otherReason,
    required String details,
    required int quantity,
    required List<String> evidence,
  }) =>
      _send('POST', '/buyer/returns', body: {
        'order_item_id': orderItemId,
        'request_type': requestType,
        'reason': reason,
        'other_reason': otherReason,
        'details': details,
        'quantity': quantity,
        'evidence': evidence,
      });

  // ---------------- Profile ----------------

  Future<BuyerProfile> profile() async {
    final body = await _send('GET', '/buyer/profile');
    final data = body['data'] is Map ? Map<String, dynamic>.from(body['data']) : body;
    return BuyerProfile.fromJson(data['profile'] is Map ? Map<String, dynamic>.from(data['profile']) : data);
  }

  Future<void> updateProfile(Map<String, dynamic> payload) => _send('PUT', '/buyer/account/profile', body: payload);

  /// Returns the new avatar URL.
  Future<String?> uploadAvatar(List<int> bytes, String fileName) async {
    final body = await _multipart('/buyer/profile/avatar', 'avatar', bytes, fileName);
    final data = body['data'] is Map ? body['data'] as Map : body;
    return data['avatar_url']?.toString();
  }

  Future<void> deactivateAccount(String password) =>
      _send('DELETE', '/buyer/account/deactivate', body: {'confirmation_phrase': 'DEACTIVATE', 'password': password});

  // ---------------- Account settings ----------------

  Future<Map<String, dynamic>> notificationPreferences() async {
    final body = await _send('GET', '/buyer/account/preferences');
    return body['data'] is Map ? Map<String, dynamic>.from(body['data']) : {};
  }

  Future<Map<String, dynamic>> saveNotificationPreference(
      String key, bool value) async {
    final body =
        await _send('PUT', '/buyer/account/preferences', body: {key: value});
    return body['data'] is Map ? Map<String, dynamic>.from(body['data']) : {};
  }

  Future<List<Map<String, dynamic>>> reportNotifications() async {
    final body = await _send('GET', '/buyer/report-notifications');
    return _list(body['data']);
  }

  Future<Map<String, dynamic>> exportAccountData() =>
      _send('GET', '/buyer/account/export');

  Future<void> signOutOtherDevices() =>
      _send('POST', '/buyer/profile/sign-out-others');

  Future<void> removeAvatar() => _send('DELETE', '/buyer/account/avatar');

  Future<(List<Map<String, dynamic>>, int)> followedStores(
      {int page = 1}) async {
    final body =
        await _send('GET', '/buyer/follows', query: 'page=$page&per_page=12');
    final meta = body['meta'] is Map ? body['meta'] as Map : const {};
    return (_list(body['data']), (meta['last_page'] as num?)?.toInt() ?? page);
  }

  /// Where to open the pin map for a typed address: (point, zoom, precision).
  Future<(LatLng, double, String)> locateAddress({String street = '', String barangay = '', String municipality = '', String province = ''}) async {
    final query = {'street': street, 'barangay': barangay, 'municipality': municipality, 'province': province}.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    final body = await _send('GET', '/geo/locate', query: query);
    final d = Map<String, dynamic>.from(body['data'] as Map);
    return (LatLng((d['lat'] as num).toDouble(), (d['lng'] as num).toDouble()), (d['zoom'] as num?)?.toDouble() ?? 15, '${d['precision'] ?? 'approximate'}');
  }

  Future<void> unfollowStore(String id) =>
      _send('DELETE', '/buyer/follows/${Uri.encodeComponent(id)}');

  Future<bool> followsStore(String id) async {
    final body =
        await _send('GET', '/buyer/follows/${Uri.encodeComponent(id)}');
    return body['data'] is Map && (body['data'] as Map)['isFollowing'] == true;
  }

  Future<bool> followStore(String id) async {
    final body =
        await _send('POST', '/buyer/follows/${Uri.encodeComponent(id)}');
    return body['data'] is Map && (body['data'] as Map)['isFollowing'] == true;
  }

  Future<(List<Map<String, dynamic>>, int)> blockedShops({int page = 1}) async {
    final body =
        await _send('GET', '/buyer/blocked-shops', query: 'page=$page');
    final meta = body['meta'] is Map ? body['meta'] as Map : const {};
    return (_list(body['data']), (meta['lastPage'] as num?)?.toInt() ?? page);
  }

  Future<void> unblockShop(String id) =>
      _send('DELETE', '/buyer/stores/${Uri.encodeComponent(id)}/block');

  Future<({List<Map<String, dynamic>> items, int lastPage, int open, int closed})> myReports({String state = 'open', int page = 1}) async {
    final body = await _send('GET', '/buyer/my-reports', query: 'state=$state&page=$page');
    final meta = body['meta'] is Map ? body['meta'] as Map : const {};
    int n(String key, int fallback) => (meta[key] as num?)?.toInt() ?? fallback;
    return (items: _list(body['data']), lastPage: n('lastPage', page), open: n('openCount', 0), closed: n('closedCount', 0));
  }

  Future<Map<String, dynamic>> myReport(String id) async {
    final body =
        await _send('GET', '/buyer/my-reports/${Uri.encodeComponent(id)}');
    return body['data'] is Map ? Map<String, dynamic>.from(body['data']) : {};
  }

  // ---------------- Messages ----------------

  Future<(List<ChatConversation>, int)> conversations({bool archived = false, int page = 1}) async {
    final body = await _send('GET', '/buyer/messages/conversations',
        query: _q({'page': '$page', 'per_page': '30', 'status': archived ? 'archived' : null}));
    final meta = body['meta'] is Map ? body['meta'] as Map : const {};
    final last = meta['lastPage'] is num ? (meta['lastPage'] as num).toInt() : page;
    return (_list(body['data']).map(ChatConversation.fromJson).toList(), last);
  }

  Future<ChatConversation> conversation(String id) async {
    final body = await _send('GET', '/buyer/messages/conversations/${Uri.encodeComponent(id)}');
    return ChatConversation.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// Finds or opens the buyer↔seller thread, optionally about a product
  /// or an order (with an optional first message).
  Future<ChatConversation> startSellerChat({required String sellerId, String? productId, String? orderNumber, String? body}) async {
    final res = await _send('POST', '/buyer/messages/conversations', body: {
      'seller_id': sellerId,
      'product_id': productId,
      'order_number': orderNumber,
      'body': body,
    });
    return ChatConversation.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<ChatConversation> startCourierChat(String orderNumber) async {
    final res = await _send('POST', '/buyer/messages/courier-conversations', body: {'order_number': orderNumber});
    return ChatConversation.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  /// Latest page (no cursor), older history ([before]) or new messages
  /// since a message id ([after], the polling path). Messages come back
  /// oldest → newest. Returns (messages, hasMore, nextCursor).
  Future<(List<ChatMessage>, bool, String?)> messages(String conversationId, {String? before, String? after, int limit = 30}) async {
    final body = await _send('GET', '/buyer/messages/conversations/${Uri.encodeComponent(conversationId)}/messages',
        query: _q({'limit': '$limit', 'before': before, 'after': after}));
    final meta = body['meta'] is Map ? body['meta'] as Map : const {};
    return (
      _list(body['data']).map(ChatMessage.fromJson).toList(),
      meta['hasMore'] == true,
      meta['nextCursor']?.toString(),
    );
  }

  /// Returns the sent message plus the shop assistant's instant auto-reply, if any.
  Future<(ChatMessage, ChatMessage?)> sendMessage(
    String conversationId, {
    String? text,
    List<String> attachmentIds = const [],
    String? quickQuestionKey,
    String? orderId,
    String? productId,
    String? variantId,
    bool contactSeller = false,
  }) async {
    final body = await _send('POST', '/buyer/messages/conversations/${Uri.encodeComponent(conversationId)}/messages', body: {
      if (text != null && text.isNotEmpty) 'body': text,
      if (attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
      if (quickQuestionKey != null) 'quick_question_key': quickQuestionKey,
      if (orderId != null) 'order_id': orderId,
      if (productId != null) 'product_id': productId,
      if (variantId != null) 'variant_id': variantId,
      if (contactSeller) 'contact_seller': true,
    });
    final data = Map<String, dynamic>.from(body['data'] as Map);
    final auto = data['autoReply'];
    return (ChatMessage.fromJson(data), auto is Map ? ChatMessage.fromJson(Map<String, dynamic>.from(auto)) : null);
  }

  Future<List<QuickQuestion>> quickQuestions(String conversationId, {bool menu = false}) async {
    final body = await _send('GET', '/buyer/messages/quick-questions', query: _q({'conversation_id': conversationId, 'menu': menu ? '1' : null}));
    return _list(body['data']).map(QuickQuestion.fromJson).toList();
  }

  /// The "which product / which order?" pickers behind quick questions.
  /// Returns (items, lastPage).
  Future<(List<Map<String, dynamic>>, int)> chatPickerItems(String conversationId, {required bool orders, bool active = false, String search = '', int page = 1}) async {
    // active: the buyer's undelivered orders with this shop, newest first.
    final path = active ? 'orders' : (orders ? 'products' : 'catalog-products');
    final body = await _send('GET', '/buyer/messages/conversations/${Uri.encodeComponent(conversationId)}/$path',
        query: _q({'page': '$page', 'search': orders || search.isEmpty ? null : search}));
    final meta = body['meta'] is Map ? body['meta'] as Map : const {};
    return (_list(body['data']), (meta['lastPage'] as num?)?.toInt() ?? page);
  }

  /// Stages a file; send its returned id with [sendMessage].
  Future<String> uploadChatAttachment(List<int> bytes, String fileName) async {
    final body = await _multipart('/buyer/messages/attachments', 'file', bytes, fileName);
    return '${(body['data'] as Map)['id']}';
  }

  Future<void> markConversationRead(String id) => _send('PUT', '/buyer/messages/conversations/${Uri.encodeComponent(id)}/read');

  Future<void> setConversationStatus(String id, String status) =>
      _send('PUT', '/buyer/messages/conversations/${Uri.encodeComponent(id)}/status', body: {'status': status});

  Future<void> deleteConversation(String id) => _send('DELETE', '/buyer/messages/conversations/${Uri.encodeComponent(id)}');

  Future<int> unreadMessages() async {
    final body = await _send('GET', '/buyer/messages/unread-count');
    final data = body['data'];
    return data is Map && data['count'] is num ? (data['count'] as num).toInt() : 0;
  }

  // ---------------- Multipart ----------------

  Future<Map<String, dynamic>> _multipart(String path, String field, List<int> bytes, String fileName) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers['Accept'] = 'application/json'
      ..files.add(http.MultipartFile.fromBytes(field, bytes, filename: fileName));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    try {
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      Map<String, dynamic> decoded = {};
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map) decoded = Map<String, dynamic>.from(raw);
      } catch (_) {}
      if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
      final errors = decoded['errors'];
      var message = decoded['message'] is String ? decoded['message'] as String : 'Upload failed (${response.statusCode}).';
      if (errors is Map && errors.isNotEmpty && errors.values.first is List) message = '${(errors.values.first as List).first}';
      throw ApiException(message: message, statusCode: response.statusCode);
    } on TimeoutException {
      throw ApiException(message: 'The upload took too long. Please try again.', statusCode: 408);
    } on SocketException {
      throw ApiException(message: 'No internet connection. Check your network and try again.', statusCode: 0);
    }
  }
}
