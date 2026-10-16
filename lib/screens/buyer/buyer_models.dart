// Buyer-side models. Field names mirror the Laravel transforms the web
// buyer already consumes (ProductController, Buyer\OrderController,
// Buyer\AddressController, CouponService) — parsing is defensive because
// several columns are nullable.

double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? fallback;
double? _dn(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
int _i(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;
String? _s(dynamic v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse('$v');
Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _maps(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

class ProductOption {
  final String name;
  final List<String> values;

  const ProductOption({required this.name, required this.values});

  factory ProductOption.fromJson(Map<String, dynamic> j) => ProductOption(
        name: _s(j['name']) ?? 'Option',
        values: _maps(j['values']).map((v) => _s(v['value']) ?? '').where((v) => v.isNotEmpty).toList(),
      );
}

class ProductVariant {
  final String id;
  final String? sku;
  final double price;
  final int stock;
  final String? image;
  final String status;
  final Map<String, String> optionValues;

  const ProductVariant({
    required this.id,
    this.sku,
    required this.price,
    required this.stock,
    this.image,
    required this.status,
    required this.optionValues,
  });

  bool get isActive => status == 'active';
  bool get isBuyable => isActive && stock > 0;

  /// `Color: Red, Size: M` — the same label the web cart stores.
  String get label => optionValues.entries.map((e) => '${e.key}: ${e.value}').join(', ');

  factory ProductVariant.fromJson(Map<String, dynamic> j, double fallbackPrice) => ProductVariant(
        id: '${j['id']}',
        sku: _s(j['sku']),
        price: _d(j['price'], fallbackPrice),
        stock: _i(j['stock']),
        image: _s(_map(j['image'])['url']),
        status: _s(j['status']) ?? 'active',
        optionValues: _map(j['option_values']).map((k, v) => MapEntry(k, '$v')),
      );
}

class Product {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? brand;
  final String? condition;
  final String? sku;
  final double price;
  final double? oldPrice;
  final int? stock;
  final String? status;
  final String? image;
  final List<String> images;
  final String? sellerId;
  final String seller;
  final String? sellerLocation; // "City, Province"
  final double? rating;
  final int reviewCount;
  final int soldCount; // units on delivered orders
  final bool hasVariants;
  final List<ProductOption> options;
  final List<ProductVariant> variants;
  final List<MapEntry<String, String>> specifications;

  const Product({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.brand,
    this.condition,
    this.sku,
    required this.price,
    this.oldPrice,
    this.stock,
    this.status,
    this.image,
    this.images = const [],
    this.sellerId,
    required this.seller,
    this.sellerLocation,
    this.rating,
    this.reviewCount = 0,
    this.soldCount = 0,
    this.hasVariants = false,
    this.options = const [],
    this.variants = const [],
    this.specifications = const [],
  });

  String? get primaryImage => images.isNotEmpty ? images.first : image;

  int get discountPercent {
    final old = oldPrice;
    if (old == null || old <= price || old <= 0) return 0;
    return ((1 - price / old) * 100).round();
  }

  bool get usesVariants => hasVariants && variants.isNotEmpty;

  /// Total purchasable units across active variants (or the simple stock).
  int? get availableStock {
    if (usesVariants) {
      return variants.where((v) => v.isActive).fold<int>(0, (sum, v) => sum + v.stock);
    }
    return stock;
  }

  bool get isSoldOut => availableStock == 0;

  /// Lowest / highest active variant price, for the "₱100 – ₱250" range.
  (double, double) get priceRange {
    final active = variants.where((v) => v.isActive).map((v) => v.price).toList();
    if (!usesVariants || active.isEmpty) return (price, price);
    active.sort();
    return (active.first, active.last);
  }

  factory Product.fromJson(Map<String, dynamic> j) {
    final price = _d(j['price']);
    final specs = <MapEntry<String, String>>[];
    final rawSpecs = j['specifications'];
    if (rawSpecs is List) {
      for (final s in _maps(rawSpecs)) {
        final label = _s(s['label'] ?? s['name'] ?? s['key']);
        final value = _s(s['value']);
        if (label != null && value != null) specs.add(MapEntry(label, value));
      }
    } else if (rawSpecs is Map) {
      rawSpecs.forEach((k, v) {
        final value = _s(v is Map ? v['value'] : v);
        if (value != null) specs.add(MapEntry(_s(v is Map ? v['label'] : null) ?? '$k', value));
      });
    }

    return Product(
      id: '${j['id']}',
      name: _s(j['name']) ?? 'Untitled product',
      description: _s(j['description']),
      category: _s(j['category']),
      brand: _s(j['brand']),
      condition: _s(j['condition']),
      sku: _s(j['sku']),
      price: price,
      oldPrice: _dn(j['oldPrice']),
      stock: j['stock'] is num ? (j['stock'] as num).toInt() : null,
      status: _s(j['status']),
      image: _s(j['image']),
      images: (j['images'] is List ? (j['images'] as List) : const []).map((e) => '$e').where((e) => e.isNotEmpty).toList(),
      sellerId: _s(j['seller_id']),
      seller: _s(j['seller']) ?? 'BuyTheWay Seller',
      sellerLocation: _s(j['seller_location']),
      rating: _dn(j['rating']),
      reviewCount: _i(j['reviewCount']),
      soldCount: _i(j['soldCount']),
      hasVariants: j['hasVariants'] == true,
      options: _maps(j['options']).map(ProductOption.fromJson).toList(),
      variants: _maps(j['variants']).map((v) => ProductVariant.fromJson(v, price)).toList(),
      specifications: specs,
    );
  }
}

/// Line-item statuses set by cart validation. Blocking ones stop checkout;
/// `price_changed` is a heads-up only (the server reprices anyway).
const kBlockingCartStatuses = {'unavailable', 'out_of_stock', 'variant_unavailable', 'insufficient_stock'};

class CartItem {
  final String cartId;
  final String productId;
  final String? variantId;
  String? sku;
  String name;
  double price;
  String? category;
  String? variation;
  int quantity;
  String seller;
  String? sellerId;
  String? image;
  double? oldPrice;
  int? maxStock;
  double? serverPrice;
  String status;
  bool selected;

  CartItem({
    required this.cartId,
    required this.productId,
    this.variantId,
    this.sku,
    required this.name,
    required this.price,
    this.category,
    this.variation,
    required this.quantity,
    required this.seller,
    this.sellerId,
    this.image,
    this.oldPrice,
    this.maxStock,
    this.serverPrice,
    this.status = 'ok',
    this.selected = true,
  });

  bool get isBlocked => kBlockingCartStatuses.contains(status);

  /// What the buyer will actually be charged per unit.
  double get effectivePrice => status == 'price_changed' && serverPrice != null ? serverPrice! : price;

  String? get statusMessage {
    switch (status) {
      case 'unavailable':
        return 'This product is no longer available.';
      case 'variant_unavailable':
        return 'This variation is no longer available.';
      case 'out_of_stock':
        return 'Out of stock.';
      case 'insufficient_stock':
        return 'Only ${maxStock ?? 0} left — lower the quantity.';
      case 'price_changed':
        return 'Price changed from ${_pesoPlain(price)} to ${_pesoPlain(serverPrice ?? price)}.';
      default:
        return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'cartId': cartId,
        'productId': productId,
        'variantId': variantId,
        'sku': sku,
        'name': name,
        'price': price,
        'category': category,
        'variation': variation,
        'quantity': quantity,
        'seller': seller,
        'sellerId': sellerId,
        'image': image,
        'oldPrice': oldPrice,
        'maxStock': maxStock,
        'serverPrice': serverPrice,
        'status': status,
        'selected': selected,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        cartId: '${j['cartId']}',
        productId: '${j['productId']}',
        variantId: _s(j['variantId']),
        sku: _s(j['sku']),
        name: _s(j['name']) ?? 'Item',
        price: _d(j['price']),
        category: _s(j['category']),
        variation: _s(j['variation']),
        quantity: _i(j['quantity'], 1).clamp(1, 9999),
        seller: _s(j['seller']) ?? 'BuyTheWay Seller',
        sellerId: _s(j['sellerId']),
        image: _s(j['image']),
        oldPrice: _dn(j['oldPrice']),
        maxStock: j['maxStock'] is num ? (j['maxStock'] as num).toInt() : null,
        serverPrice: _dn(j['serverPrice']),
        status: _s(j['status']) ?? 'ok',
        selected: j['selected'] != false,
      );
}

String _pesoPlain(double v) => '₱${v.toStringAsFixed(2)}';

class Address {
  final String id;
  final String fullName;
  final String phone;
  final String? houseNo;
  final String line1;
  final String region;
  final String provinceCode;
  final String province;
  final String municipalityCode;
  final String city;
  final String barangay;
  final String? postalCode;
  final String label;
  final bool isDefault;
  final bool isComplete;
  final double? lat; // map pin
  final double? lng;

  const Address({
    required this.id,
    required this.fullName,
    required this.phone,
    this.houseNo,
    required this.line1,
    required this.region,
    required this.provinceCode,
    required this.province,
    required this.municipalityCode,
    required this.city,
    required this.barangay,
    this.postalCode,
    required this.label,
    required this.isDefault,
    required this.isComplete,
    this.lat,
    this.lng,
  });

  bool get hasPin => lat != null && lng != null;

  String get formatted => [
        [houseNo, line1].whereType<String>().where((s) => s.isNotEmpty).join(' '),
        barangay,
        city,
        province,
        postalCode,
      ].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  factory Address.fromJson(Map<String, dynamic> j) => Address(
        id: '${j['id']}',
        fullName: _s(j['fullName']) ?? '',
        phone: _s(j['phone']) ?? '',
        houseNo: _s(j['houseNo']),
        line1: _s(j['line1']) ?? '',
        region: _s(j['region']) ?? '',
        provinceCode: _s(j['provinceCode']) ?? '',
        province: _s(j['province']) ?? '',
        municipalityCode: _s(j['municipalityCode']) ?? '',
        city: _s(j['city']) ?? '',
        barangay: _s(j['barangay']) ?? '',
        postalCode: _s(j['postalCode']),
        label: _s(j['label']) ?? 'Home',
        isDefault: j['isDefault'] == true,
        isComplete: j['isComplete'] != false,
        lat: j['pin'] is Map ? _dn((j['pin'] as Map)['lat']) : null,
        lng: j['pin'] is Map ? _dn((j['pin'] as Map)['lng']) : null,
      );
}

class ShippingOption {
  final String id;
  final String name;
  final String? description;
  final double fee;
  final bool available;
  final String? unavailableReason;

  const ShippingOption({
    required this.id,
    required this.name,
    this.description,
    required this.fee,
    required this.available,
    this.unavailableReason,
  });

  factory ShippingOption.fromJson(Map<String, dynamic> j) => ShippingOption(
        id: '${j['id']}',
        name: _s(j['name']) ?? '${j['id']}',
        description: _s(j['description']),
        fee: _d(j['fee']),
        available: j['available'] != false,
        unavailableReason: _s(j['unavailableReason']),
      );
}

class CheckoutPaymentMethod {
  final String id;
  final String name;
  final String? description;
  final bool available;
  final String? unavailableReason;

  const CheckoutPaymentMethod({
    required this.id,
    required this.name,
    this.description,
    required this.available,
    this.unavailableReason,
  });

  factory CheckoutPaymentMethod.fromJson(Map<String, dynamic> j) => CheckoutPaymentMethod(
        id: '${j['id']}',
        name: _s(j['name']) ?? '${j['id']}',
        description: _s(j['description']),
        available: j['available'] != false,
        unavailableReason: _s(j['unavailableReason']),
      );
}

/// A coupon — either a claimable product coupon or a wallet entry. For
/// wallet entries [id] is the buyer_coupons id the checkout payload needs.
class Coupon {
  final String id;
  final String? couponId;
  final String? productId;
  final String? productName;
  final String label;
  final String? code;
  final double? discount;
  final int? remaining;
  final bool runningLow;
  final DateTime? expiresAt;
  final String status;
  final String type; // discount | shipping
  final String scope; // product | shop
  final String discountType; // percentage | fixed
  final double? discountValue;
  final double minSpend;
  final double? maxDiscount;
  final bool stackable;
  final String? sellerId;
  final String? shopName;
  final int productsCount;
  final String source; // seller | platform
  final List<String> categories;
  final bool autoApplied; // BuyTheWay voucher applied at checkout without claiming

  bool get isShipping => type == 'shipping';
  bool get isPlatform => source == 'platform';

  const Coupon({
    required this.id,
    this.couponId,
    this.productId,
    this.productName,
    required this.label,
    this.code,
    this.discount,
    this.remaining,
    this.runningLow = false,
    this.expiresAt,
    this.status = 'active',
    this.type = 'discount',
    this.scope = 'shop',
    this.discountType = 'fixed',
    this.discountValue,
    this.minSpend = 0,
    this.maxDiscount,
    this.stackable = true,
    this.sellerId,
    this.shopName,
    this.productsCount = 0,
    this.source = 'seller',
    this.categories = const [],
    this.autoApplied = false,
  });

  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
        id: '${j['id']}',
        couponId: _s(j['couponId']),
        productId: _s(j['productId']),
        productName: _s(j['productName']),
        label: _s(j['label']) ?? 'Voucher',
        code: _s(j['code']),
        discount: _dn(j['discount']),
        remaining: j['remaining'] is num ? (j['remaining'] as num).toInt() : null,
        runningLow: j['runningLow'] == true,
        expiresAt: _date(j['expiresAt']),
        status: _s(j['status']) ?? 'active',
        type: _s(j['type']) ?? 'discount',
        scope: _s(j['scope']) ?? 'shop',
        discountType: _s(j['discountType']) ?? 'fixed',
        discountValue: _dn(j['discountValue']),
        minSpend: _dn(j['minSpend']) ?? 0,
        maxDiscount: _dn(j['maxDiscount']),
        stackable: j['stackable'] != false,
        sellerId: _s(j['sellerId']),
        shopName: _s(j['shopName']),
        productsCount: j['productsCount'] is num ? (j['productsCount'] as num).toInt() : 0,
        source: _s(j['source']) ?? 'seller',
        autoApplied: j['autoApplied'] == true,
        categories: j['categories'] is List ? (j['categories'] as List).map((e) => '$e').toList() : const [],
      );
}

class PaymentMethod {
  final String id;
  final String type; // card | wallet
  final String? provider;
  final String display;
  final bool isPrimary;
  final String? holder;
  final String? expiry; // MM/YY

  const PaymentMethod({required this.id, required this.type, this.provider, required this.display, required this.isPrimary, this.holder, this.expiry});

  /// The checkout payment_method string this saved method satisfies.
  String get checkoutCode => type == 'card' ? 'card' : ((provider ?? '').toLowerCase().contains('maya') ? 'maya' : 'gcash');

  factory PaymentMethod.fromJson(Map<String, dynamic> j) {
    final type = _s(j['type']) ?? 'card';
    final label = _s(j['label']);
    String display;
    if (type == 'wallet') {
      display = [_s(j['provider']) ?? 'Wallet', _s(j['phoneMasked'])].whereType<String>().join(' · ');
    } else {
      final last4 = _s(j['last4']);
      display = [_s(j['brand']) ?? 'Card', if (last4 != null) '•••• $last4'].join(' ');
    }
    final month = _s(j['expMonth']);
    final year = _s(j['expYear']);
    return PaymentMethod(
      id: '${j['id']}',
      type: type,
      provider: _s(j['provider']),
      display: label ?? display,
      isPrimary: j['isPrimary'] == true,
      holder: _s(j['holder']),
      expiry: month != null && year != null ? '${month.padLeft(2, '0')}/${year.substring(year.length - 2)}' : null,
    );
  }
}

// ---------------- Chat ----------------

class ChatAttachment {
  final String? id;
  final String name;
  final String? url;
  final String? mime;

  const ChatAttachment({this.id, required this.name, this.url, this.mime});

  bool get isImage => (mime ?? '').startsWith('image/') || RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false).hasMatch(name);

  factory ChatAttachment.fromJson(Map<String, dynamic> j) =>
      ChatAttachment(id: _s(j['id']), name: _s(j['name']) ?? 'attachment', url: _s(j['url']), mime: _s(j['mime']));
}

class ChatMessage {
  final String id;
  final String from; // buyer | seller | courier | system
  final String? text;
  final List<ChatAttachment> attachments;
  final DateTime? at;
  final DateTime? readAt;
  final Map<String, dynamic>? orderContext;
  final Map<String, dynamic>? productContext;
  final String? source;
  final String? quickQuestionKey;
  final bool isAutomatic;

  /// Local-only: optimistic bubble still being sent / failed to send.
  final bool pending;
  final bool failed;

  const ChatMessage({
    required this.id,
    required this.from,
    this.text,
    this.attachments = const [],
    this.at,
    this.readAt,
    this.orderContext,
    this.productContext,
    this.source,
    this.quickQuestionKey,
    this.isAutomatic = false,
    this.pending = false,
    this.failed = false,
  });

  bool get mine => from == 'buyer';

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: '${j['id']}',
        from: _s(j['from']) ?? 'system',
        text: _s(j['text']),
        attachments: _maps(j['attachments']).map(ChatAttachment.fromJson).toList(),
        at: _date(j['at']),
        readAt: _date(j['readAt']),
        orderContext: j['orderContext'] is Map ? _map(j['orderContext']) : null,
        productContext: j['productContext'] is Map ? _map(j['productContext']) : null,
        source: _s(j['source']),
        quickQuestionKey: _s(j['quickQuestionKey']),
        isAutomatic: j['isAutomatic'] == true,
      );
}

class ChatConversation {
  final String id;
  final String type; // direct | delivery
  final String name;
  final String? counterpartId;
  final String? avatarUrl;
  final String role; // seller | courier
  final String status;
  final bool archived;
  final bool online;
  final int unread;
  final DateTime? updatedAt;
  final String? preview;
  final String? productName;
  final String? productId;
  final double? productPrice;
  final double? productOldPrice;
  final String? productImage;
  final String? orderNumber;
  final String? orderStatus;
  final String? orderName;
  final String? orderImage;
  final bool blocked;
  final bool locked;
  final String? lockReason;
  final double? rating; // seller shops only (single-thread fetch)
  final int reviewCount;
  final String? courierCompany; // courier threads only (single-thread fetch)

  const ChatConversation({
    required this.id,
    required this.type,
    required this.name,
    this.counterpartId,
    this.avatarUrl,
    required this.role,
    required this.status,
    this.archived = false,
    this.online = false,
    this.unread = 0,
    this.updatedAt,
    this.preview,
    this.productName,
    this.productId,
    this.productPrice,
    this.productOldPrice,
    this.productImage,
    this.orderNumber,
    this.orderStatus,
    this.orderName,
    this.orderImage,
    this.blocked = false,
    this.locked = false,
    this.lockReason,
    this.rating,
    this.reviewCount = 0,
    this.courierCompany,
  });

  bool get isCourier => role == 'courier';
  bool get isSeller => role == 'seller';
  bool get readOnly => blocked || locked;

  factory ChatConversation.fromJson(Map<String, dynamic> j) => ChatConversation(
        id: '${j['id']}',
        type: _s(j['type']) ?? 'direct',
        name: _s(j['seller']) ?? 'Seller',
        counterpartId: _s(j['sellerId']),
        avatarUrl: _s(j['sellerAvatarUrl']),
        role: _s(j['sellerRole']) ?? 'seller',
        status: _s(j['status']) ?? 'open',
        archived: j['archived'] == true,
        online: j['sellerOnline'] == true,
        unread: _i(j['unread']),
        updatedAt: _date(j['updatedAt']),
        preview: _s(j['lastMessagePreview']),
        productName: _s(_map(j['product'])['name']),
        productId: _s(_map(j['product'])['id']),
        productPrice: _dn(_map(j['product'])['price']),
        productOldPrice: _dn(_map(j['product'])['oldPrice']),
        productImage: _s(_map(j['product'])['image']),
        orderNumber: _s(_map(j['order'])['orderNumber']),
        orderStatus: _s(_map(j['order'])['status']),
        orderName: _s(_map(j['order'])['previewName']),
        orderImage: _s(_map(j['order'])['previewImage']),
        blocked: j['blocked'] == true,
        locked: j['locked'] == true,
        lockReason: _s(j['lockReason']),
        rating: _dn(j['sellerRating']),
        reviewCount: _i(j['sellerReviewCount']),
        courierCompany: _s(j['courierCompany']),
      );

  ChatConversation copyWith({bool? blocked, bool? archived, String? status}) => ChatConversation(
        id: id,
        type: type,
        name: name,
        counterpartId: counterpartId,
        avatarUrl: avatarUrl,
        role: role,
        status: status ?? this.status,
        archived: archived ?? this.archived,
        online: online,
        unread: unread,
        updatedAt: updatedAt,
        preview: preview,
        productName: productName,
        productId: productId,
        productPrice: productPrice,
        productOldPrice: productOldPrice,
        productImage: productImage,
        orderNumber: orderNumber,
        orderStatus: orderStatus,
        orderName: orderName,
        orderImage: orderImage,
        blocked: blocked ?? this.blocked,
        locked: locked,
        lockReason: lockReason,
        rating: rating,
        reviewCount: reviewCount,
        courierCompany: courierCompany,
      );
}

/// A canned question from the web's shop assistant (chat_quick_questions).
class QuickQuestion {
  final String key;
  final String question;
  final String contextType; // general | order
  final String? orderId;

  const QuickQuestion({required this.key, required this.question, required this.contextType, this.orderId});

  bool get isStock => key == 'stock_availability';
  bool get needsOrder => contextType == 'order' && orderId == null;

  factory QuickQuestion.fromJson(Map<String, dynamic> j) => QuickQuestion(
        key: '${j['key']}',
        question: _s(j['question']) ?? '',
        contextType: _s(j['contextType']) ?? 'general',
        orderId: _s(j['orderId']),
      );
}

// ---------------- Reviews / profile ----------------

class MyReview {
  final String id;
  final String? productId;
  final String productName;
  final String? category;
  final String? image;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final bool isEdited;
  final String? sellerResponse;

  const MyReview({
    required this.id,
    this.productId,
    required this.productName,
    this.category,
    this.image,
    required this.rating,
    this.comment,
    this.createdAt,
    this.isEdited = false,
    this.sellerResponse,
  });

  factory MyReview.fromJson(Map<String, dynamic> j) {
    final img = j['image'];
    return MyReview(
      id: '${j['id']}',
      productId: _s(j['productId']),
      productName: _s(j['productName']) ?? 'Product',
      category: _s(j['category']),
      image: img is Map ? _s(img['url']) : _s(img),
      rating: _i(j['rating']),
      comment: _s(j['comment']),
      createdAt: _date(j['createdAt']),
      isEdited: j['isEdited'] == true,
      sellerResponse: _s(j['sellerResponse']),
    );
  }
}

class BuyerProfile {
  final String firstName;
  final String? middleInitial;
  final String lastName;
  final String? sex;
  final String? contactNo;
  final DateTime? birthday;
  final String email;
  final String? avatarUrl;
  final DateTime? memberSince;

  const BuyerProfile({
    required this.firstName,
    this.middleInitial,
    required this.lastName,
    this.sex,
    this.contactNo,
    this.birthday,
    required this.email,
    this.avatarUrl,
    this.memberSince,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory BuyerProfile.fromJson(Map<String, dynamic> j) => BuyerProfile(
        firstName: _s(j['first_name']) ?? '',
        middleInitial: _s(j['middle_initial']),
        lastName: _s(j['last_name']) ?? '',
        sex: _s(j['sex']),
        contactNo: _s(j['contact_no']),
        birthday: _date(j['birthday']),
        email: _s(j['email']) ?? '',
        avatarUrl: _s(j['avatar_url']),
        memberSince: _date(j['created_at']),
      );
}

/// Return reasons — must match OrderReturnRequest::REASONS.
const kReturnReasons = [
  ('damaged', 'Arrived damaged'),
  ('wrong_item', 'Wrong item received'),
  ('incomplete', 'Missing parts or items'),
  ('not_as_described', 'Not as described'),
  ('quality_issue', 'Poor quality'),
  ('other', 'Other'),
];

class Review {
  final String id;
  final String author;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final String? variant;
  final bool verifiedPurchase;
  final List<String> images;
  final String? sellerResponse;
  final String? productName; // set on store-wide review lists
  final String? avatarUrl; // null when the reviewer posted anonymously
  final bool anonymous;
  final int helpfulCount;
  final bool isHelpful;
  final bool canLike;

  const Review({
    required this.id,
    required this.author,
    required this.rating,
    this.comment,
    this.createdAt,
    this.variant,
    this.verifiedPurchase = false,
    this.images = const [],
    this.sellerResponse,
    this.productName,
    this.avatarUrl,
    this.anonymous = false,
    this.helpfulCount = 0,
    this.isHelpful = false,
    this.canLike = false,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: '${j['id']}',
        author: _s(j['author']) ?? 'BuyTheWay Buyer',
        rating: _i(j['rating']).clamp(0, 5),
        comment: _s(j['comment']),
        createdAt: _date(j['createdAt']),
        variant: _s(j['variant']),
        verifiedPurchase: j['verifiedPurchase'] == true,
        images: (j['images'] is List ? (j['images'] as List) : const []).map((e) => '$e').toList(),
        sellerResponse: _s(j['sellerResponse']),
        productName: j['product'] is Map ? _s((j['product'] as Map)['name']) : null,
        avatarUrl: _s(j['avatar']),
        anonymous: j['anonymous'] == true,
        helpfulCount: _i(j['helpfulCount']),
        isHelpful: j['isHelpful'] == true,
        canLike: j['canLike'] == true,
      );
}

class ReviewSummary {
  final double? average;
  final int total;
  final Map<int, int> breakdown;
  final int withImages;

  const ReviewSummary({this.average, this.total = 0, this.breakdown = const {}, this.withImages = 0});

  factory ReviewSummary.fromJson(Map<String, dynamic> j) {
    final breakdown = <int, int>{};
    final raw = j['breakdown'];
    if (raw is Map) {
      raw.forEach((k, v) => breakdown[_i(k)] = _i(v));
    } else if (raw is List) {
      // PHP serialises [5=>..,1=>..] as an object, but be safe if it's a list.
      for (var i = 0; i < raw.length; i++) {
        breakdown[5 - i] = _i(raw[i]);
      }
    }
    return ReviewSummary(
      average: _dn(j['average']),
      total: _i(j['total']),
      breakdown: breakdown,
      withImages: _i(j['with_images']),
    );
  }
}

/// Canonical order statuses (Order::STATUSES on the server).
class OrderStatus {
  OrderStatus._();

  static const toShip = 'New';
  static const processing = 'Processing';
  static const inTransit = 'In Transit';
  static const delivered = 'Delivered';
  static const cancelled = 'Cancelled';
}

class OrderItem {
  final String id;
  final String? productId;
  final String name;
  final String? category;
  final String? image;
  final String? variation;
  final int quantity;
  final double unitPrice;
  final String? couponCode;
  final double couponDiscount;
  final String? reviewId;
  final int? reviewRating;
  final String? reviewComment;
  final String? returnStatus;
  final String? returnType;
  final String? returnResolution;

  const OrderItem({
    required this.id,
    this.productId,
    required this.name,
    this.category,
    this.image,
    this.variation,
    required this.quantity,
    required this.unitPrice,
    this.couponCode,
    this.couponDiscount = 0,
    this.reviewId,
    this.reviewRating,
    this.reviewComment,
    this.returnStatus,
    this.returnType,
    this.returnResolution,
  });

  bool get reviewed => reviewId != null;

  factory OrderItem.fromJson(Map<String, dynamic> j) {
    final review = _map(j['review']);
    final ret = _map(j['returnRequest']);
    return OrderItem(
      id: '${j['id']}',
      productId: _s(j['product_id']),
      name: _s(j['name']) ?? 'Item',
      category: _s(j['category']),
      image: _s(j['image']),
      variation: _s(j['variation']),
      quantity: _i(j['quantity'], 1),
      unitPrice: _d(j['unit_price']),
      couponCode: _s(j['coupon_code']),
      couponDiscount: _d(j['coupon_discount']),
      reviewId: _s(review['id']),
      reviewRating: review['rating'] == null ? null : _i(review['rating']),
      reviewComment: _s(review['comment']),
      returnStatus: _s(ret['status']),
      returnType: _s(ret['requestType']),
      returnResolution: _s(ret['resolutionNote']),
    );
  }
}

class StatusEvent {
  final String status;
  final String? note;
  final DateTime? at;

  const StatusEvent({required this.status, this.note, this.at});
}

class Order {
  final String orderId; // "#SN-40412"
  final DateTime? createdAt;
  final String status;
  final String seller;
  final String? sellerId;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? returnState;
  final DateTime? receivedAt;
  final String? shippingMethod;
  final String? shippingCarrier;
  final double subtotal;
  final double shippingFee;
  final double discount;
  final double total;
  final String? trackingNumber;
  final String? recipientName;
  final String? contactNumber;
  final String? address;
  final List<StatusEvent> history;
  final List<OrderItem> items;
  final String? courierName;

  const Order({
    required this.orderId,
    this.createdAt,
    required this.status,
    required this.seller,
    this.sellerId,
    this.paymentMethod,
    this.paymentStatus,
    this.returnState,
    this.receivedAt,
    this.shippingMethod,
    this.shippingCarrier,
    required this.subtotal,
    required this.shippingFee,
    required this.discount,
    required this.total,
    this.trackingNumber,
    this.recipientName,
    this.contactNumber,
    this.address,
    this.history = const [],
    this.items = const [],
    this.courierName,
  });

  /// Order number without the leading '#', as the API routes expect.
  String get number => orderId.replaceFirst('#', '');

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  /// Return progress overrides the raw status in lists — same as web.
  String get displayStatus {
    if (returnState == 'to_return') return 'To Return';
    if (returnState == 'returned') return 'Returned';
    return status;
  }

  bool get canCancel => status == OrderStatus.toShip;
  bool get awaitingReceipt => status == OrderStatus.delivered && receivedAt == null;

  factory Order.fromJson(Map<String, dynamic> j) {
    final delivery = _map(j['delivery_address']);
    final parcel = _map(j['parcel']);
    return Order(
      orderId: _s(j['orderId']) ?? _s(j['id']) ?? '',
      createdAt: _date(j['createdAt']),
      status: _s(j['status']) ?? OrderStatus.toShip,
      seller: _s(j['seller']) ?? 'BuyTheWay Seller',
      sellerId: _s(j['seller_id']),
      paymentMethod: _s(j['payment_method']),
      paymentStatus: _s(j['payment_status']),
      returnState: _s(j['returnState']),
      receivedAt: _date(j['receivedAt']),
      shippingMethod: _s(j['shipping_method']),
      shippingCarrier: _s(j['shipping_carrier']),
      subtotal: _d(j['subtotal']),
      shippingFee: _d(j['shipping_fee']),
      discount: _d(j['discount']),
      total: _d(j['total']),
      trackingNumber: _s(j['tracking_number']),
      recipientName: _s(delivery['recipient_name']),
      contactNumber: _s(delivery['contact_number']),
      address: _s(delivery['address']),
      history: _maps(j['statusHistory']).map((h) => StatusEvent(status: _s(h['status']) ?? '', note: _s(h['note']), at: _date(h['createdAt']))).toList(),
      items: _maps(j['items']).map(OrderItem.fromJson).toList(),
      courierName: _s(_map(parcel['courier'])['name']),
    );
  }
}

/// One map point on a parcel's route (seller → hubs → buyer).
class JourneyStop {
  const JourneyStop({required this.lat, required this.lng, required this.name, required this.role, this.reached = false});

  final double lat;
  final double lng;
  final String name;
  final String role; // origin | hub | destination
  final bool reached;
}

/// Payload of GET /buyer/orders/{n}/tracking (OrderTrackingService::journey).
class ParcelJourney {
  const ParcelJourney({
    required this.mappable,
    required this.active,
    required this.live,
    required this.statusLabel,
    required this.disclaimer,
    required this.stops,
    required this.trail,
    this.parcel,
  });

  final bool mappable;
  final bool active; // worth polling
  final bool live;
  final String statusLabel;
  final String? disclaimer;
  final List<JourneyStop> stops;
  final List<({double lat, double lng})> trail;
  final ({double lat, double lng})? parcel;

  factory ParcelJourney.fromJson(Map<String, dynamic> j) {
    final reachedIndex = (j['reachedIndex'] as num?)?.toInt() ?? 0;
    final stops = <JourneyStop>[];
    for (final (i, s) in _maps(j['stops']).indexed) {
      final lat = _dn(s['lat']), lng = _dn(s['lng']);
      if (lat == null || lng == null) continue;
      stops.add(JourneyStop(lat: lat, lng: lng, name: _s(s['name']) ?? '', role: _s(s['role']) ?? 'hub', reached: i <= reachedIndex));
    }
    final p = _map(j['parcel']);
    final pl = _dn(p['lat']), pg = _dn(p['lng']);
    return ParcelJourney(
      mappable: j['mappable'] == true && stops.length > 1,
      active: j['active'] == true,
      live: j['live'] == true,
      statusLabel: _s(j['statusLabel']) ?? 'Tracking',
      disclaimer: _s(j['disclaimer']),
      stops: stops,
      trail: [
        for (final t in _maps(j['trail']))
          if (_dn(t['lat']) != null && _dn(t['lng']) != null) (lat: _dn(t['lat'])!, lng: _dn(t['lng'])!),
      ],
      parcel: pl != null && pg != null ? (lat: pl, lng: pg) : null,
    );
  }
}

String paymentLabel(String? code) {
  switch (code) {
    case 'cod':
      return 'Cash on Delivery';
    case 'card':
      return 'Credit / Debit Card';
    case 'gcash':
      return 'GCash';
    case 'maya':
      return 'Maya';
    default:
      return code ?? '—';
  }
}
