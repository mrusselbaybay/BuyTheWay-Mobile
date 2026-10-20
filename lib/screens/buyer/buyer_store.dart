import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../services/buyer_api_service.dart';
import '../../services/poller.dart';
import '../../services/push_service.dart';
import 'buyer_models.dart';

/// Outcome of an add-to-cart, carrying the user-facing message.
class CartAddResult {
  final bool ok;
  final String message;

  const CartAddResult(this.ok, this.message);
}

/// App-wide buyer state: session, cart, wishlist, addresses and orders.
///
/// The cart is client-side only, exactly like the web buyer (there is no
/// cart table — checkout takes the cart as a payload and CheckoutService
/// re-validates price/stock/seller server-side), persisted to
/// SharedPreferences so it survives restarts.
class BuyerStore extends ChangeNotifier {
  BuyerStore._();

  static final BuyerStore instance = BuyerStore._();

  static const _cartKey = 'buytheway_buyer_cart';
  static const _cartMergedKey = 'buytheway_cart_merged';
  static const _cartPendingKey = 'buytheway_cart_pending';
  static const _recentSearchKey = 'buytheway_recent_searches';

  final BuyerApiService api = BuyerApiService();

  bool _notifyQueued = false;

  /// Screens kick off loads from initState, which can run mid-build (e.g.
  /// a tab created by the shell's IndexedStack). Notifying then throws
  /// "setState() called during build", so defer to the end of the frame.
  @override
  void notifyListeners() {
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      super.notifyListeners();
      return;
    }
    if (_notifyQueued) return;
    _notifyQueued = true;
    scheduler.addPostFrameCallback((_) {
      _notifyQueued = false;
      super.notifyListeners();
    });
  }

  bool initialized = false;
  bool sessionExpired = false;
  String? token;
  String displayName = '';
  String email = '';
  bool? emailVerified;
  bool canSell = false;

  // ---------------- Session ----------------

  Future<void> init() async {
    if (initialized) return;
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');
    api.token = token;
    _cart = _readCart(prefs);
    _cartMerged = prefs.getBool(_cartMergedKey) ?? false;
    _cartPending = prefs.getBool(_cartPendingKey) ?? false;
    recentSearches = prefs.getStringList(_recentSearchKey) ?? [];
    initialized = true;
    sessionExpired = token == null || token!.isEmpty;
    notifyListeners();
    if (sessionExpired) return;
    unawaited(PushService.instance.register(token));

    unawaited(_loadUser());
    unawaited(loadProfile());
    unawaited(refreshChatUnread());
    chatPoller.start();
    unawaited(refreshNotifUnread());
    notifPoller.start();
    unawaited(loadWishlist());
    unawaited(refreshCart());
    unawaited(loadOrders());
    ordersPoller.start();
    cartPoller.start();
  }

  Future<void> _loadUser() async {
    try {
      final raw = await ApiService().getUser(token!);
      final user = raw['user'] is Map ? Map<String, dynamic>.from(raw['user']) : raw;
      final meta = user['user_metadata'] is Map ? user['user_metadata'] as Map : const {};
      final name = '${meta['first_name'] ?? ''} ${meta['last_name'] ?? ''}'.trim();
      email = '${user['email'] ?? ''}';
      emailVerified = user['email_confirmed_at'] != null;
      canSell = (user['roles'] as List? ?? const []).contains('seller');
      displayName = name.isNotEmpty ? name : (email.isNotEmpty ? email.split('@').first : 'Shopper');
      notifyListeners();
    } on ApiException catch (e) {
      handleError(e);
    } catch (_) {}
  }

  /// Flags an expired session (401) so the shell can route to sign-in;
  /// returns a message suitable for a toast or inline error.
  String handleError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401 && !sessionExpired) {
        sessionExpired = true;
        notifyListeners();
      }
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> signOut() async {
    ordersPoller.stop();
    cartPoller.stop();
    chatPoller.stop();
    notifPoller.stop();
    chatUnread = 0;
    notifUnread = 0;
    profile = null;
    canSell = false;
    final current = token;
    // Before the session is cleared: the server needs it to drop this phone's push token.
    unawaited(PushService.instance.unregister(authToken: current));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    // The cart lives on the account now; don't leave it for the next person on this device.
    _pushTimer?.cancel();
    _persistTimer?.cancel();
    await prefs.remove(_cartKey);
    await prefs.remove(_cartMergedKey);
    await prefs.remove(_cartPendingKey);
    _cart = [];
    _cartMerged = false;
    _cartPending = false;
    if (current != null) {
      unawaited(ApiService().logout(current).catchError((_) {}));
    }
    token = null;
    api.token = null;
    initialized = false;
    sessionExpired = false;
    displayName = '';
    email = '';
    emailVerified = null;
    favorites = {};
    addresses = [];
    orders = [];
    _addressesLoaded = false;
    _ordersLoaded = false;
    notifyListeners();
  }

  // ---------------- Profile / chat badge ----------------

  BuyerProfile? profile;
  int chatUnread = 0;

  /// Header/tab chat badge: 45s, paused in the background, backs off on
  /// failures. Only writes (and notifies) when the count actually changes.
  late final Poller chatPoller = Poller(
    (isActive) async {
      final count = await api.unreadMessages();
      if (!isActive() || sessionExpired || token == null) return;
      _setChatUnread(count);
    },
    interval: const Duration(seconds: 45),
    shouldSkip: () => sessionExpired || token == null,
    onError: handleError,
  );

  void _setChatUnread(int count) {
    final next = count < 0 ? 0 : count;
    if (next == chatUnread) return;
    chatUnread = next;
    notifyListeners();
  }

  // ---------------- Notification bell ----------------

  int notifUnread = 0;

  /// Bell badge: 45s, paused in the background, backs off on failures.
  late final Poller notifPoller = Poller(
    (isActive) async {
      final count = await api.unreadNotifications();
      if (!isActive() || sessionExpired || token == null) return;
      setNotifUnread(count);
    },
    interval: const Duration(seconds: 45),
    shouldSkip: () => sessionExpired || token == null,
    onError: handleError,
  );

  void setNotifUnread(int count) {
    final next = count < 0 ? 0 : count;
    if (next == notifUnread) return;
    notifUnread = next;
    notifyListeners();
  }

  Future<void> refreshNotifUnread() async {
    if (sessionExpired || token == null) return;
    try {
      setNotifUnread(await api.unreadNotifications());
    } catch (_) {}
  }

  String? get avatarUrl => profile?.avatarUrl;

  Future<void> loadProfile() async {
    try {
      profile = await api.profile();
      if (profile!.fullName.isNotEmpty) displayName = profile!.fullName;
      notifyListeners();
    } catch (e) {
      handleError(e);
    }
  }

  Future<void> refreshChatUnread() async {
    if (sessionExpired || token == null) return;
    try {
      _setChatUnread(await api.unreadMessages());
    } catch (_) {}
  }

  // ---------------- Recent searches ----------------

  List<String> recentSearches = [];

  Future<void> rememberSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    recentSearches = [q, ...recentSearches.where((s) => s.toLowerCase() != q.toLowerCase())].take(10).toList();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchKey, recentSearches);
  }

  Future<void> clearRecentSearches() async {
    recentSearches = [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchKey);
  }

  // ---------------- Cart ----------------

  List<CartItem> _cart = [];

  List<CartItem> get cart => List.unmodifiable(_cart);

  List<CartItem> _readCart(SharedPreferences prefs) {
    try {
      final raw = jsonDecode(prefs.getString(_cartKey) ?? '[]');
      if (raw is! List) return [];
      return raw.whereType<Map>().map((e) => CartItem.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Timer? _persistTimer;
  Timer? _pushTimer;
  bool _cartMerged = false; // this device's cart has been folded into the account's
  bool _cartPending = false; // local edits not yet saved to the account
  int _cartVersion = 0; // bumped on every local edit

  /// True while the cart is being synced with the account; [cartSyncError] is
  /// the reason the last sync failed (null when it worked).
  bool cartSyncing = false;
  String? cartSyncError;

  /// Called after every local edit: saves on-device (debounced so rapid
  /// +/- taps don't each hit disk) and queues a save to the account.
  void _cartChanged() {
    _cartVersion++;
    notifyListeners();
    _persistCartLocally();
    _scheduleCartPush();
  }

  void _persistCartLocally() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 300), () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cartKey, jsonEncode(_cart.map((e) => e.toJson()).toList()));
    });
  }

  /// A cart line as the server stores it. Inline (data:) or huge image URLs
  /// are left out; the line re-fetches its image when validated.
  Map<String, dynamic> _cartLineJson(CartItem item) {
    final json = item.toJson();
    final image = json['image'];
    if (image is String && (image.startsWith('data:') || image.length > 2000)) json['image'] = null;
    return json;
  }

  Future<void> _setCartPending(bool value) async {
    _cartPending = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cartPendingKey, value);
  }

  Future<void> _markCartMerged() async {
    _cartMerged = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cartMergedKey, true);
  }

  void _scheduleCartPush() {
    // Before the first merge the account's cart (e.g. from the website)
    // mustn't be overwritten by this device's.
    if (!_cartMerged || token == null || token!.isEmpty || sessionExpired) return;
    unawaited(_setCartPending(true));
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(milliseconds: 800), _pushCart);
  }

  Future<void> _pushCart() async {
    final version = _cartVersion;
    try {
      await api.saveCart(_cart.map(_cartLineJson).toList());
      if (version == _cartVersion) await _setCartPending(false);
    } catch (e) {
      handleError(e); // stays pending; retried on the next edit or launch
    }
  }

  /// Brings this device's cart in line with the account's: the first time
  /// the two are merged, afterwards the account's copy wins.
  Future<void> _pullCart() async {
    if (token == null || token!.isEmpty || sessionExpired) return;
    final version = _cartVersion;
    cartSyncError = null;
    try {
      final firstTime = !_cartMerged;
      final remote = firstTime ? await api.mergeCart(_cart.map(_cartLineJson).toList()) : await api.fetchCart();
      if (firstTime) await _markCartMerged();
      if (!firstTime && version != _cartVersion) {
        _scheduleCartPush(); // edited while loading: keep the local edits and save them
        return;
      }
      _applyRemoteCart(remote);
    } catch (e) {
      cartSyncError = handleError(e);
      debugPrint('Cart sync failed: $e');
    }
  }

  void _applyRemoteCart(List<Map<String, dynamic>> remote) {
    final known = {for (final i in _cart) '${i.productId}|${i.variantId ?? ''}': i.cartId};
    var n = 0;
    _cart = [
      for (final line in remote) CartItem.fromJson({...line, 'cartId': known['${line['productId']}|${line['variantId'] ?? ''}'] ?? '${DateTime.now().microsecondsSinceEpoch}${n++}'}),
    ];
    notifyListeners();
    _persistCartLocally();
  }

  /// Syncs with the account (saving unsynced edits first), then re-checks
  /// every line against the live catalog.
  Future<void> refreshCart() async {
    if (cartSyncing) return;
    cartSyncing = true;
    notifyListeners();
    try {
      if (_cartMerged && _cartPending) {
        await _pushCart();
      } else {
        await _pullCart();
      }
    } finally {
      cartSyncing = false;
      notifyListeners();
    }
    await validateCart();
  }

  int get cartCount => _cart.fold(0, (sum, i) => sum + i.quantity);

  /// Cart lines grouped by shop, in the order shops were first added.
  Map<String, List<CartItem>> get cartBySeller {
    final groups = <String, List<CartItem>>{};
    for (final item in _cart) {
      groups.putIfAbsent(item.seller, () => []).add(item);
    }
    return groups;
  }

  List<CartItem> get selectedItems => _cart.where((i) => i.selected).toList();
  List<CartItem> get selectedValidItems => _cart.where((i) => i.selected && !i.isBlocked).toList();
  bool get allSelected => _cart.isNotEmpty && _cart.every((i) => i.selected);
  bool get cartHasIssues => _cart.any((i) => i.status != 'ok');
  int get blockedCount => _cart.where((i) => i.isBlocked).length;

  int get selectedCount => selectedValidItems.fold(0, (sum, i) => sum + i.quantity);
  double get selectedSubtotal => selectedValidItems.fold(0.0, (sum, i) => sum + i.effectivePrice * i.quantity);

  /// '' when checkout is allowed; otherwise why the button is disabled.
  String get checkoutBlockReason {
    final selected = selectedItems;
    if (selected.isEmpty) return 'Select at least one item to check out.';
    final blocked = selected.where((i) => i.isBlocked).length;
    if (blocked == selected.length) return 'The selected items are unavailable.';
    if (blocked > 0) return '$blocked selected ${blocked == 1 ? 'item needs' : 'items need'} attention.';
    return '';
  }

  static int? _ceiling(Product product, ProductVariant? variant) => variant != null ? variant.stock : product.stock;

  /// Builds a cart line without adding it — also used by Buy Now.
  CartItem buildLine(Product product, ProductVariant? variant, int quantity) => CartItem(
        cartId: '${DateTime.now().microsecondsSinceEpoch}',
        productId: product.id,
        variantId: variant?.id,
        sku: variant?.sku ?? product.sku,
        name: product.name,
        price: variant?.price ?? product.price,
        category: product.category,
        variation: variant?.label,
        quantity: quantity,
        seller: product.seller,
        sellerId: product.sellerId,
        image: variant?.image ?? product.primaryImage,
        oldPrice: product.oldPrice,
        maxStock: _ceiling(product, variant),
      );

  CartAddResult addToCart(Product product, ProductVariant? variant, int quantity) {
    if (variant != null && !variant.isActive) return const CartAddResult(false, 'This variation is currently unavailable.');
    final ceiling = _ceiling(product, variant);
    if (ceiling == 0) return const CartAddResult(false, 'This item is out of stock.');

    final desired = quantity < 1 ? 1 : quantity;
    final index = _cart.indexWhere((i) => i.productId == product.id && i.variantId == variant?.id);

    if (index >= 0) {
      final existing = _cart[index];
      existing
        ..name = product.name
        ..price = variant?.price ?? product.price
        ..oldPrice = product.oldPrice
        ..maxStock = ceiling
        ..selected = true;
      final requested = existing.quantity + desired;
      if (ceiling != null && requested > ceiling) {
        if (existing.quantity >= ceiling) {
          return CartAddResult(false, 'You already have the maximum available ($ceiling) in your cart.');
        }
        existing.quantity = ceiling;
        if (existing.status == 'insufficient_stock') existing.status = 'ok';
        _cartChanged();
        return CartAddResult(true, 'Only $ceiling available — added the maximum to your cart.');
      }
      existing.quantity = requested;
      if (existing.status == 'insufficient_stock') existing.status = 'ok';
      _cartChanged();
      return const CartAddResult(true, 'Added to cart');
    }

    final qty = ceiling != null && desired > ceiling ? ceiling : desired;
    _cart.add(buildLine(product, variant, qty));
    _cartChanged();
    return CartAddResult(true, qty < desired ? 'Only $ceiling available — added the maximum to your cart.' : 'Added to cart');
  }

  /// Clamps to [1, maxStock]. Returns a warning when capped, else null.
  String? setQuantity(String cartId, int quantity) {
    final item = _cart.where((i) => i.cartId == cartId).firstOrNull;
    if (item == null) return null;
    var next = quantity < 1 ? 1 : quantity;
    String? warning;
    if (item.maxStock != null && next > item.maxStock!) {
      next = item.maxStock!;
      warning = 'Only ${item.maxStock} available.';
    }
    if (next == item.quantity && warning == null) return null;
    item.quantity = next;
    if (item.status == 'insufficient_stock' && item.maxStock != null && next <= item.maxStock!) item.status = 'ok';
    _cartChanged();
    return warning;
  }

  void toggleItem(String cartId) {
    final item = _cart.where((i) => i.cartId == cartId).firstOrNull;
    if (item == null) return;
    item.selected = !item.selected;
    _cartChanged();
  }

  void setSellerSelected(String seller, bool selected) {
    for (final i in _cart.where((i) => i.seller == seller)) {
      i.selected = selected;
    }
    _cartChanged();
  }

  void setAllSelected(bool selected) {
    for (final i in _cart) {
      i.selected = selected;
    }
    _cartChanged();
  }

  /// Returns the removed lines (with their positions) for undo.
  List<(int, CartItem)> removeItems(Iterable<String> cartIds) {
    final ids = cartIds.toSet();
    final removed = <(int, CartItem)>[];
    for (var i = 0; i < _cart.length; i++) {
      if (ids.contains(_cart[i].cartId)) removed.add((i, _cart[i]));
    }
    _cart.removeWhere((i) => ids.contains(i.cartId));
    _cartChanged();
    return removed;
  }

  void restoreItems(List<(int, CartItem)> removed) {
    for (final (index, item) in removed) {
      _cart.insert(index.clamp(0, _cart.length), item);
    }
    _cartChanged();
  }

  int removeUnavailable() {
    final ids = _cart.where((i) => i.isBlocked).map((i) => i.cartId).toList();
    removeItems(ids);
    return ids.length;
  }

  bool validatingCart = false;

  /// Re-checks every line against the live catalog and tags it with a
  /// status the cart shows inline — never removes anything by itself.
  ///
  /// [silent] (background poll): no "checking" state, and the cart is only
  /// touched/saved when a line actually changed. Returns how many lines
  /// changed status, stock or price.
  Future<int> validateCart({bool silent = false, bool Function()? isActive}) async {
    if (_cart.isEmpty || validatingCart) return 0;
    String fingerprint(CartItem i) => '${i.status}|${i.maxStock}|${i.serverPrice}';
    final before = {for (final i in _cart) i.cartId: fingerprint(i)};
    if (!silent) {
      validatingCart = true;
      notifyListeners();
    }
    var changed = 0;
    try {
      final ids = _cart.map((i) => i.productId).toSet().toList();
      final results = await Future.wait(ids.map((id) async {
        try {
          return MapEntry(id, await api.product(id));
        } catch (_) {
          return MapEntry<String, Product?>(id, _unknown);
        }
      }));
      final byId = Map.fromEntries(results);
      if (isActive != null && !isActive()) return 0;
      // Nothing could be checked (offline / server down): let the poller back off.
      if (silent && results.isNotEmpty && results.every((e) => identical(e.value, _unknown))) {
        throw ApiException(message: 'Cart check unavailable');
      }

      for (final item in _cart) {
        final product = byId[item.productId];
        if (identical(product, _unknown)) continue; // couldn't check — leave as is
        if (product == null || (product.status != null && product.status != 'active')) {
          item
            ..status = 'unavailable'
            ..maxStock = 0;
          continue;
        }
        item
          ..name = product.name
          ..seller = product.seller
          ..sellerId = product.sellerId ?? item.sellerId
          ..oldPrice = product.oldPrice;
        if (item.variantId != null) {
          final variant = product.variants.where((v) => v.id == item.variantId).firstOrNull;
          if (variant == null || !variant.isActive) {
            item
              ..status = 'variant_unavailable'
              ..maxStock = 0;
            continue;
          }
          item
            ..maxStock = variant.stock
            ..serverPrice = variant.price
            ..image ??= variant.image;
        } else {
          item
            ..maxStock = product.stock
            ..serverPrice = product.price
            ..image ??= product.primaryImage;
        }
        if (item.maxStock == 0) {
          item.status = 'out_of_stock';
        } else if (item.maxStock != null && item.quantity > item.maxStock!) {
          item.status = 'insufficient_stock';
        } else if (item.serverPrice != null && (item.serverPrice! - item.price).abs() > 0.009) {
          item.status = 'price_changed';
        } else {
          item.status = 'ok';
        }
      }
      changed = _cart.where((i) => before.containsKey(i.cartId) && before[i.cartId] != fingerprint(i)).length;
      return changed;
    } finally {
      if (!silent) validatingCart = false;
      if (!silent || changed > 0) _cartChanged();
    }
  }

  /// Background cart check (every 60s while the Cart tab is showing, never
  /// during checkout or for a signed-out session). Lines are flagged in place,
  /// never removed; [cartChangedNotice] lets the Cart screen say so once.
  bool _cartTabActive = false; // CartScreen validates itself when the tab opens
  set cartTabActive(bool value) => _cartTabActive = value;

  int _checkoutsOpen = 0;
  int _standaloneCarts = 0; // pushed CartScreen routes (the tab is covered then)
  String? cartChangedNotice;

  void standaloneCartOpened() => _standaloneCarts++;
  void standaloneCartClosed() => _standaloneCarts = _standaloneCarts > 0 ? _standaloneCarts - 1 : 0;

  void checkoutOpened() => _checkoutsOpen++;
  void checkoutClosed() => _checkoutsOpen = _checkoutsOpen > 0 ? _checkoutsOpen - 1 : 0;

  late final Poller cartPoller = Poller(
    (isActive) async {
      final changed = await validateCart(silent: true, isActive: isActive);
      if (changed > 0 && isActive()) {
        cartChangedNotice = changed == 1
            ? 'An item in your cart changed price or availability.'
            : '$changed items in your cart changed price or availability.';
        notifyListeners();
      }
    },
    interval: const Duration(seconds: 60),
    // Also held while a quantity edit/undo is still being saved or pushed.
    shouldSkip: () =>
        sessionExpired ||
        !(_cartTabActive || _standaloneCarts > 0) ||
        _checkoutsOpen > 0 ||
        cartSyncing ||
        validatingCart ||
        (_persistTimer?.isActive ?? false) ||
        (_pushTimer?.isActive ?? false),
    onError: handleError,
  );

  static const Product _unknown = Product(id: '', name: '', price: 0, seller: '');

  // ---------------- Wishlist ----------------

  Set<String> favorites = {};

  bool isFavorite(String productId) => favorites.contains(productId);

  Future<void> loadWishlist() async {
    try {
      favorites = (await api.wishlist()).toSet();
      notifyListeners();
    } catch (e) {
      handleError(e);
    }
  }

  /// Optimistic; rolls back and returns an error message on failure.
  Future<String?> toggleFavorite(String productId) async {
    final was = favorites.contains(productId);
    was ? favorites.remove(productId) : favorites.add(productId);
    notifyListeners();
    try {
      was ? await api.removeFromWishlist(productId) : await api.addToWishlist(productId);
      return null;
    } catch (e) {
      was ? favorites.add(productId) : favorites.remove(productId);
      notifyListeners();
      return handleError(e);
    }
  }

  // ---------------- Addresses ----------------

  List<Address> addresses = [];
  bool loadingAddresses = false;
  String? addressError;
  bool _addressesLoaded = false;

  Address? get defaultAddress => addresses.where((a) => a.isDefault).firstOrNull ?? addresses.firstOrNull;

  Future<void> loadAddresses({bool force = false}) async {
    if (loadingAddresses || (_addressesLoaded && !force)) return;
    loadingAddresses = true;
    addressError = null;
    notifyListeners();
    try {
      addresses = await api.addresses();
      _addressesLoaded = true;
    } catch (e) {
      addressError = handleError(e);
    } finally {
      loadingAddresses = false;
      notifyListeners();
    }
  }

  Future<Address> saveAddress(Map<String, dynamic> payload, {String? id}) async {
    final saved = await api.saveAddress(payload, id: id);
    // Default flag may have moved to this one — re-sync the list.
    await loadAddresses(force: true);
    return saved;
  }

  Future<void> deleteAddress(String id) async {
    final previous = addresses;
    addresses = addresses.where((a) => a.id != id).toList();
    notifyListeners();
    try {
      await api.deleteAddress(id);
      await loadAddresses(force: true);
    } catch (e) {
      addresses = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setDefaultAddress(String id) async {
    await api.setDefaultAddress(id);
    await loadAddresses(force: true);
  }

  // ---------------- Orders ----------------

  List<Order> orders = [];
  bool loadingOrders = false;
  String? ordersError;
  bool _ordersLoaded = false;
  bool get ordersLoaded => _ordersLoaded;

  Future<void> loadOrders() async {
    if (loadingOrders) return;
    loadingOrders = true;
    ordersError = null;
    notifyListeners();
    try {
      orders = await api.orders();
      _ordersLoaded = true;
    } catch (e) {
      ordersError = handleError(e);
    } finally {
      loadingOrders = false;
      notifyListeners();
    }
  }

  // Silent background refresh (30s while the Orders tab or an order's details
  // are showing): swaps in only the orders that changed, keeping the others'
  // identity, never touching loading/error state. Held while a cancel/receive
  // is in flight, and a response that started before one finished is dropped,
  // so it can't revert the optimistic update.
  bool _ordersTabActive = false;
  set ordersTabActive(bool value) {
    if (value == _ordersTabActive) return;
    _ordersTabActive = value;
    if (value) scheduleMicrotask(ordersPoller.refreshIfStale);
  }

  int _orderDetailsOpen = 0;
  int _orderMutations = 0;
  int _orderEpoch = 0;

  void orderDetailsOpened() => _orderDetailsOpen++;
  void orderDetailsClosed() => _orderDetailsOpen = _orderDetailsOpen > 0 ? _orderDetailsOpen - 1 : 0;

  /// Bumped whenever a cancel/receive starts or ends; a poll that began under
  /// an older epoch must not be applied.
  int get orderEpoch => _orderEpoch;
  bool get orderMutationActive => _orderMutations > 0;

  Future<T> guardOrderMutation<T>(Future<T> Function() action) async {
    _orderMutations++;
    _orderEpoch++;
    try {
      return await action();
    } finally {
      _orderMutations--;
      _orderEpoch++;
    }
  }

  /// No further change expected: cancelled, or received with no return open.
  static bool isFinalOrder(Order o) =>
      o.status == OrderStatus.cancelled || (o.status == OrderStatus.delivered && o.receivedAt != null && o.returnState == null);

  String _orderFingerprint(Order o) =>
      '${o.status}|${o.returnState}|${o.receivedAt}|${o.paymentStatus}|${o.trackingNumber}|${o.courierName}|${o.total}|${o.history.length}|${o.items.length}';

  int _finalOrderTicks = 0;

  late final Poller ordersPoller = Poller(
    (isActive) async {
      // Everything is final: only look for brand-new orders, every 4th tick.
      if (orders.isNotEmpty && orders.every(isFinalOrder) && ++_finalOrderTicks % 4 != 0) return;
      final epoch = _orderEpoch;
      final fetched = await api.orders();
      if (!isActive() || epoch != _orderEpoch || _orderMutations > 0 || loadingOrders) return;
      if (fetched.isEmpty && orders.isNotEmpty) return; // never wipe good data
      final existing = {for (final o in orders) o.orderId: o};
      final merged = [
        for (final order in fetched)
          if (existing[order.orderId] case final old? when _orderFingerprint(old) == _orderFingerprint(order)) old else order,
      ];
      final same = merged.length == orders.length && [for (var i = 0; i < merged.length; i++) identical(merged[i], orders[i])].every((e) => e);
      if (same) return;
      orders = merged;
      _ordersLoaded = true;
      notifyListeners();
    },
    interval: const Duration(seconds: 30),
    shouldSkip: () => sessionExpired || !(_ordersTabActive || _orderDetailsOpen > 0) || loadingOrders || _orderMutations > 0,
    onError: handleError,
  );

  void replaceOrder(Order updated) {
    final index = orders.indexWhere((o) => o.orderId == updated.orderId);
    if (index >= 0) {
      orders[index] = updated;
      notifyListeners();
    }
  }

  int countOrders(String status) => orders.where((o) => o.returnState == null && o.status == status).length;
}
