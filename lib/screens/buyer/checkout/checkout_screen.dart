import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/api_service.dart';
import '../../../services/poller.dart';
import '../account/addresses_screen.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';
import 'order_placed_screen.dart';
import 'voucher_quote.dart';
import 'voucher_sheet.dart';

/// Checkout for either the selected cart lines or a single Buy Now line.
/// Mirrors the web Checkout.vue contract: the server re-validates every
/// price, stock level and voucher and splits the cart into one order per
/// seller. Payment is cash on delivery only, as on the web.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.items, required this.fromCart});

  final List<CartItem> items;
  final bool fromCart;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final store = BuyerStore.instance;

  Address? address;

  List<ShippingOption> shippingOptions = [];
  CheckoutPaymentMethod? codMethod;
  int sellerCount = 1;
  String shippingMethod = 'standard';
  final Set<String> _collapsed = {};
  bool loadingShipping = true;
  String? shippingError;

  // ---- Vouchers (same model as the web checkout) ----
  VoucherQuote voucherQuote = VoucherQuote.empty;
  bool quotingVouchers = false;
  int _quoteSeq = 0;
  final Map<String, VoucherPick> selectedVouchers = {}; // seller id → picks
  final Set<String> touchedSellers = {}; // sellers whose picks the buyer chose
  String? platformDiscount;
  String? platformShipping;
  bool platformTouched = false;

  static const String paymentMethod = 'cod';

  bool placing = false;
  String messageToSeller = ''; // one note, sent with every shop's order

  List<CartItem> get items => widget.items;

  // ---- Background price/stock check ----
  // Every 60s (and on app resume) the lines are compared with the live catalog.
  // Totals never change by themselves: a difference raises a banner the buyer
  // must acknowledge ("Review updated total") and Place order stays blocked
  // until then. Voucher validity is re-quoted on acknowledgement and checked
  // by the server at placement. Paused while placing the order.
  List<String> staleChanges = [];
  final Map<String, ({double? price, int? stock, bool unavailable})> _pendingLines = {};

  late final Poller _probe = Poller(
    (isActive) async {
      if (staleChanges.isNotEmpty) return;
      final ids = items.map((i) => i.productId).toSet().toList();
      final products = await Future.wait(ids.map((id) async {
        try {
          return MapEntry<String, Product?>(id, await store.api.product(id));
        } on ApiException catch (e) {
          if (e.statusCode == 404) return MapEntry<String, Product?>(id, null);
          rethrow;
        }
      }));
      // Dropped while the buyer is in a sheet/picker or placing; the next tick re-checks.
      if (!isActive() || !mounted || placing || _route?.isCurrent == false) return;
      final byId = Map.fromEntries(products);
      final list = <String>[];
      final pending = <String, ({double? price, int? stock, bool unavailable})>{};
      for (final item in items) {
        final product = byId[item.productId];
        if (product == null || (product.status != null && product.status != 'active')) {
          if (item.status != 'unavailable') {
            list.add('${item.name}: no longer available');
            pending[item.cartId] = (price: null, stock: 0, unavailable: true);
          }
          continue;
        }
        final variant = item.variantId == null ? null : product.variants.where((v) => v.id == item.variantId).firstOrNull;
        if (item.variantId != null && (variant == null || !variant.isActive)) {
          list.add('${item.name}: this option is no longer available');
          pending[item.cartId] = (price: null, stock: 0, unavailable: true);
          continue;
        }
        final price = variant?.price ?? product.price;
        final stock = variant?.stock ?? product.stock;
        // Compared with what the buyer was last shown, so an acknowledged
        // change doesn't raise the banner again.
        final blocked = stock != null && item.quantity > stock;
        final wasBlocked = item.status == 'out_of_stock' || item.status == 'insufficient_stock';
        final knownPrice = item.serverPrice ?? item.price;
        if (blocked && (!wasBlocked || item.maxStock != stock)) {
          list.add(stock == 0 ? '${item.name}: out of stock' : '${item.name}: only $stock left in stock');
          pending[item.cartId] = (price: price, stock: stock, unavailable: false);
        } else if (!blocked && wasBlocked) {
          list.add('${item.name}: back in stock');
          pending[item.cartId] = (price: price, stock: stock, unavailable: false);
        } else if ((price - knownPrice).abs() > 0.009) {
          list.add('${item.name}: ${pesoLabel(knownPrice)} → ${pesoLabel(price)} each');
          pending[item.cartId] = (price: price, stock: stock, unavailable: false);
        }
      }
      if (list.isEmpty) return;
      setState(() {
        staleChanges = list;
        _pendingLines
          ..clear()
          ..addAll(pending);
      });
    },
    interval: const Duration(seconds: 60),
    shouldSkip: () => placing || staleChanges.isNotEmpty || _route?.isCurrent == false,
    onError: store.handleError,
  );

  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  String pesoLabel(double v) => '₱${v.toStringAsFixed(2)}';

  void _reviewChanges() {
    for (final item in items) {
      final line = _pendingLines[item.cartId];
      if (line == null) continue;
      if (line.unavailable) {
        item
          ..status = 'unavailable'
          ..maxStock = 0;
        continue;
      }
      item
        ..serverPrice = line.price
        ..maxStock = line.stock;
      if (line.stock == 0) {
        item.status = 'out_of_stock';
      } else if (line.stock != null && item.quantity > line.stock!) {
        item.status = 'insufficient_stock';
      } else if (line.price != null && (line.price! - item.price).abs() > 0.009) {
        item.status = 'price_changed';
      } else {
        item.status = 'ok';
      }
    }
    setState(() {
      staleChanges = [];
      _pendingLines.clear();
    });
    _loadVouchers();
  }

  @override
  void dispose() {
    _probe.stop();
    store.checkoutClosed();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    store.checkoutOpened();
    _probe.start();
    address = store.defaultAddress;
    store.loadAddresses().then((_) {
      if (!mounted) return;
      if (address == null || !store.addresses.any((a) => a.id == address!.id)) {
        setState(() => address = store.defaultAddress);
      }
      _loadShipping();
      _loadVouchers();
    });
    if (address != null) _loadShipping();
    _loadVouchers();
  }

  // ---------------- Data ----------------

  String? _shippingFor; // address id the current options were quoted for

  Future<void> _loadShipping({bool force = false}) async {
    final addressId = address?.isComplete == true ? address!.id : null;
    if (!force && _shippingFor == (addressId ?? '')) return;
    _shippingFor = addressId ?? '';
    setState(() {
      loadingShipping = true;
      shippingError = null;
    });
    try {
      final ids = items.map((i) => i.productId).toSet().toList();
      final (options, count, paymentMethods) = await store.api.shippingOptions(ids, addressId: addressId);
      if (!mounted) return;
      final before = shippingMethod;
      setState(() {
        shippingOptions = options.where((o) => o.id != 'same_day').toList();
        sellerCount = count;
        codMethod = paymentMethods.where((method) => method.id == paymentMethod).firstOrNull;
        if (!options.any((o) => o.id == shippingMethod && o.available)) shippingMethod = 'standard';
      });
      if (before != shippingMethod) _loadVouchers();
    } catch (e) {
      _shippingFor = null;
      if (mounted) setState(() => shippingError = store.handleError(e));
    } finally {
      if (mounted) setState(() => loadingShipping = false);
    }
  }

  String _lineKey(CartItem i) => '${i.productId}:${i.variantId ?? ''}';

  bool _stillValid(List<VoucherOption> options, String? id) => id == null || options.any((o) => o.id == id && o.applicable);

  /// Asks the server what each shop's vouchers (and the BuyTheWay ones) are
  /// worth for this cart, then keeps the buyer's own picks while they still
  /// apply and auto-applies the server's best everywhere else.
  Future<void> _loadVouchers() async {
    final seq = ++_quoteSeq;
    setState(() => quotingVouchers = true);
    final lines = [
      for (final i in items) {'key': _lineKey(i), 'product_id': i.productId, 'variant_id': i.variantId, 'quantity': i.quantity},
    ];
    final manual = {
      for (final id in touchedSellers) id: {'discount': selectedVouchers[id]?.discount, 'shipping': selectedVouchers[id]?.shipping},
    };
    try {
      final quote = await store.api.quoteVouchers(
        lines,
        shippingMethod: shippingMethod,
        addressId: address?.isComplete == true ? address!.id : null,
        selected: manual.isEmpty ? null : manual,
      );
      if (!mounted || seq != _quoteSeq) return;
      var dropped = false;
      setState(() {
        voucherQuote = quote;
        for (final entry in quote.sellers.entries) {
          final offer = entry.value;
          final current = selectedVouchers[entry.key];
          final stillOk = _stillValid(offer.discount, current?.discount) && _stillValid(offer.shipping, current?.shipping);
          if (touchedSellers.contains(entry.key) && current != null && !stillOk) dropped = true;
          if (!touchedSellers.contains(entry.key) || current == null || !stillOk) {
            selectedVouchers[entry.key] = (discount: offer.bestDiscountId, shipping: offer.bestShippingId);
          }
        }
        final platform = quote.platform;
        final platformOk = platform == null || (_stillValid(platform.discount, platformDiscount) && _stillValid(platform.shipping, platformShipping));
        if (platformTouched && !platformOk && (platformDiscount != null || platformShipping != null)) dropped = true;
        if (platform != null && (!platformTouched || !platformOk)) {
          platformDiscount = platform.bestDiscountId;
          platformShipping = platform.bestShippingId;
          if (platform.exclusive) _clearShopVouchers();
        }
        quotingVouchers = false;
      });
      if (dropped) showToast(context, 'A voucher you picked is no longer valid and was removed. Totals updated.');
    } catch (_) {
      if (mounted && seq == _quoteSeq) {
        setState(() {
          voucherQuote = VoucherQuote.empty;
          quotingVouchers = false;
        });
      }
    }
  }

  void _clearShopVouchers() {
    for (final id in voucherQuote.sellers.keys) {
      touchedSellers.add(id);
      selectedVouchers[id] = (discount: null, shipping: null);
    }
  }

  // ---------------- Totals ----------------

  double get subtotal => items.fold(0.0, (s, i) => s + i.effectivePrice * i.quantity);

  ShippingOption? get selectedShipping => shippingOptions.where((o) => o.id == shippingMethod).firstOrNull;

  double get shippingFee => (selectedShipping?.fee ?? 0) * sellerCount;

  double _savingsOf(VoucherOffer offer, VoucherPick? pick) => (offer.find('discount', pick?.discount)?.amount ?? 0) + (offer.find('shipping', pick?.shipping)?.amount ?? 0);

  double get shopSavings => voucherQuote.sellers.entries.fold(0.0, (s, e) => s + _savingsOf(e.value, selectedVouchers[e.key]));

  double get platformSavings {
    final platform = voucherQuote.platform;
    return platform == null ? 0 : _savingsOf(platform, (discount: platformDiscount, shipping: platformShipping));
  }

  double get totalSavings => shopSavings + platformSavings;

  /// The slots split out for the order summary.
  double _slot(String slot) {
    var sum = 0.0;
    for (final e in voucherQuote.sellers.entries) {
      sum += e.value.find(slot, slot == 'discount' ? selectedVouchers[e.key]?.discount : selectedVouchers[e.key]?.shipping)?.amount ?? 0;
    }
    final platform = voucherQuote.platform;
    if (platform != null) sum += platform.find(slot, slot == 'discount' ? platformDiscount : platformShipping)?.amount ?? 0;
    return sum;
  }

  double get shopDiscountSavings => voucherQuote.sellers.entries.fold(0.0, (s, e) => s + (e.value.find('discount', selectedVouchers[e.key]?.discount)?.amount ?? 0));
  double get platformDiscountSavings => voucherQuote.platform?.find('discount', platformDiscount)?.amount ?? 0;
  double get voucherDiscount => _slot('discount');
  double get shippingDiscount => _slot('shipping');

  /// What the items would cost at their original (pre-sale) prices.
  double get originalSubtotal => items.fold(0.0, (s, i) => s + ((i.oldPrice ?? 0) > i.effectivePrice ? i.oldPrice! : i.effectivePrice) * i.quantity);
  double get saleSavings => originalSubtotal - subtotal;

  double get total => math.max(0, subtotal + shippingFee - shopSavings - platformSavings);

  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  String get blockReason {
    final a = address;
    if (a == null) return 'Add a delivery address to continue.';
    if (!a.isComplete) return 'Complete this address (province, city, barangay).';
    final flagged = items.where((i) => const ['unavailable', 'variant_unavailable', 'out_of_stock', 'insufficient_stock'].contains(i.status)).firstOrNull;
    if (flagged != null) return '${flagged.name}: ${flagged.statusMessage ?? 'no longer available.'} Update it in your basket.';
    if (staleChanges.isNotEmpty) return 'Prices or availability changed — review the update first.';
    if (loadingShipping) return 'Loading shipping options…';
    if (shippingError != null || selectedShipping == null) return 'Shipping options unavailable — tap retry.';
    if (codMethod?.available == false) return codMethod?.unavailableReason ?? 'COD is currently unavailable. Please choose another payment method.';
    return '';
  }

  // ---------------- Actions ----------------

  Future<void> _pickAddress() async {
    final picked = await Navigator.of(context).push<Address>(
      MaterialPageRoute(builder: (_) => AddressesScreen(pickMode: true, selectedId: address?.id)),
    );
    if (picked != null && mounted) {
      setState(() => address = picked);
      _loadShipping();
      _loadVouchers(); // region-based BuyTheWay vouchers depend on the address
    } else if (mounted && address != null && !store.addresses.any((a) => a.id == address!.id)) {
      // The chosen address was deleted while picking.
      setState(() => address = store.defaultAddress);
      _loadShipping();
      _loadVouchers();
    }
  }

  Future<void> _openShopVouchers(String sellerId, String shopName) async {
    final offer = voucherQuote.sellers[sellerId];
    if (offer == null) return;
    final pick = await showVoucherSheet(context, title: shopName, offer: offer, selected: selectedVouchers[sellerId] ?? (discount: null, shipping: null));
    if (pick == null || !mounted) return;
    setState(() {
      touchedSellers.add(sellerId);
      selectedVouchers[sellerId] = pick;
      // A non-stackable BuyTheWay voucher can't be combined with shop vouchers.
      final platform = voucherQuote.platform;
      final platformPicks = [platform?.find('discount', platformDiscount), platform?.find('shipping', platformShipping)].whereType<VoucherOption>();
      if ((pick.discount != null || pick.shipping != null) && platformPicks.any((o) => !o.stackable)) {
        platformTouched = true;
        platformDiscount = null;
        platformShipping = null;
      }
    });
    _loadVouchers();
  }

  Future<void> _openPlatformVouchers() async {
    final offer = voucherQuote.platform;
    if (offer == null) return;
    final pick = await showVoucherSheet(context, title: 'BuyTheWay vouchers', offer: offer, selected: (discount: platformDiscount, shipping: platformShipping), platform: true);
    if (pick == null || !mounted) return;
    setState(() {
      platformTouched = true;
      platformDiscount = pick.discount;
      platformShipping = pick.shipping;
      // A non-stackable BuyTheWay voucher replaces the shop vouchers.
      final picked = [offer.find('discount', pick.discount), offer.find('shipping', pick.shipping)].whereType<VoucherOption>();
      if (picked.any((o) => !o.stackable)) _clearShopVouchers();
    });
    _loadVouchers();
  }

  Future<void> _placeOrder() async {
    if (placing) return;
    final a = address!;
    setState(() => placing = true);
    final payload = {
      'items': items
          .map((i) => {
                'product_id': i.productId,
                'variant_id': i.variantId,
                'name': i.name,
                'category': i.category,
                'seller': i.seller,
                'variation': i.variation,
                'quantity': i.quantity,
                'unit_price': i.effectivePrice,
              })
          .toList(),
      'vouchers': [
        for (final id in voucherQuote.sellers.keys)
          if (selectedVouchers[id]?.discount != null || selectedVouchers[id]?.shipping != null)
            {'seller_id': id, 'discount_voucher_id': selectedVouchers[id]!.discount, 'shipping_voucher_id': selectedVouchers[id]!.shipping},
      ],
      'platform_vouchers': {'discount_voucher_id': platformDiscount, 'shipping_voucher_id': platformShipping},
      if (messageToSeller.trim().isNotEmpty) 'message_to_seller': messageToSeller.trim(),
      'delivery_address': {
        'address_id': a.id,
        'recipient_name': a.fullName,
        'contact_number': a.phone,
        'address': a.formatted,
      },
      'shipping_method': shippingMethod,
      'payment_method': paymentMethod,
      'subtotal': subtotal,
      'shipping_fee': shippingFee,
      'discount': totalSavings,
      'total': total,
    };

    try {
      final refs = await store.api.checkout(payload);
      if (widget.fromCart) store.removeItems(items.map((i) => i.cartId));
      store.loadOrders();
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => OrderPlacedScreen(references: refs, total: total, paymentMethod: paymentMethod),
      ));
    } catch (e) {
      final message = store.handleError(e);
      if (!mounted) return;
      setState(() => placing = false);
      final changed = e is ApiException && (e.statusCode == 409 || e.statusCode == 422);
      showToast(
        context,
        changed ? message : 'We couldn\'t place your order. Nothing was charged. $message',
        error: true,
      );
      // Prices/stock moved under us: list what changed (banner), keep the form as is.
      if (changed) _probe.refreshNow();
      _loadVouchers(); // a voucher may have expired or run out meanwhile
    }
  }

  // ---------------- UI ----------------

  Widget _staleBanner() => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: BColors.warningSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: BColors.warning.withValues(alpha: 0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.info_outline_rounded, size: 18, color: BColors.warning),
            SizedBox(width: 8),
            Expanded(child: Text('Something changed while you were checking out', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: BColors.warning))),
          ]),
          const SizedBox(height: 8),
          for (final change in staleChanges) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('• $change', style: BText.small)),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _reviewChanges, child: const Text('Review updated total'))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<CartItem>>{};
    for (final i in items) {
      groups.putIfAbsent(i.seller, () => []).add(i);
    }
    final reason = blockReason;
    final platformOffer = voucherQuote.platform;
    final freeShipping = shippingFee > 0 && shippingDiscount >= shippingFee;
    final saved = saleSavings + totalSavings;

    return Scaffold(
      backgroundColor: BColors.background,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        surfaceTintColor: BColors.surface,
        foregroundColor: BColors.ink,
        elevation: 0,
        centerTitle: true,
        title: const Text('Checkout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.only(top: 12, bottom: 16), children: [
        if (staleChanges.isNotEmpty) _staleBanner(),
        _AddressPanel(address: address, loading: address == null && store.loadingAddresses, onTap: _pickAddress),
        for (final entry in groups.entries) _shopPanel(entry.key, entry.value, groups.length),
        if (platformOffer != null) _platformPanel(platformOffer),
        _notePanel(groups.length),
        _shippingPanel(),
        _paymentPanel(),
        _summaryPanel(),
        if (saved > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF99F6E4))),
            child: Row(children: [
              const Icon(Icons.celebration_rounded, size: 20, color: BColors.brand),
              const SizedBox(width: 10),
              Expanded(child: Text('Congrats! You\'re saving ${peso(saved)} on this order.', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: BColors.brandDark))),
            ]),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text('By placing an order, you agree to BuyTheWay\'s Terms of Use and Sale and acknowledge that you have read the Privacy Policy.', style: TextStyle(fontSize: 11.5, height: 1.45, color: BColors.muted)),
        ),
        if (groups.length > 1)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Items from different shops ship separately, so you\'ll get one order per shop.', style: BText.tiny),
          ),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: BColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(22)), boxShadow: softShadow(0.12)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (reason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, size: 15, color: BColors.error),
                    const SizedBox(width: 6),
                    Expanded(child: Text(reason, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BColors.error))),
                  ]),
                ),
              Row(children: [
                Text('Total ($itemCount ${itemCount == 1 ? 'item' : 'items'})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: BColors.ink)),
                const Spacer(),
                pesoText(total, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: BColors.brandDark, letterSpacing: -0.4)),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: reason.isEmpty && !placing ? _placeOrder : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BColors.brand,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF99F6E4),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: placing
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('Place order', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, height: 1.1)),
                          if (freeShipping) Text('Free shipping', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
                        ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets padding = EdgeInsets.zero}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: BColors.border), boxShadow: softShadow(0.03)),
        child: child,
      );

  /// One shop's items, its delivery line, then its voucher row.
  Widget _shopPanel(String shop, List<CartItem> shopItems, int shopCount) {
    final sellerId = shopItems.map((i) => i.sellerId).whereType<String>().firstOrNull;
    final offer = sellerId == null ? null : voucherQuote.sellers[sellerId];
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Row(children: [
            const Icon(Icons.storefront_rounded, size: 20, color: BColors.ink),
            const SizedBox(width: 8),
            Expanded(child: Text(shop, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ]),
        ),
        for (final item in shopItems)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: CategoryThumb(category: item.category, image: item.image, size: 78)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.3, fontWeight: FontWeight.w700)),
                  if (item.variation != null) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(7)),
                      child: Text(item.variation!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: BColors.brandDark)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: PriceText(item.effectivePrice, oldPrice: item.oldPrice, size: 16)),
                    Text('x${item.quantity}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: BColors.muted)),
                  ]),
                ]),
              ),
            ]),
          ),
        // Delivery summary for this shop.
        if (selectedShipping != null)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.local_shipping_outlined, size: 18, color: BColors.brand),
              const SizedBox(width: 10),
              Expanded(child: Text([selectedShipping!.name, if (selectedShipping!.description != null) selectedShipping!.description!].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: BColors.brandDark))),
              const SizedBox(width: 8),
              if (shippingDiscount >= shippingFee && shippingFee > 0) ...[
                Text(peso(selectedShipping!.fee), style: const TextStyle(fontSize: 12, color: BColors.faint, decoration: TextDecoration.lineThrough)),
                const SizedBox(width: 6),
                const Text('Free', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: BColors.brandDark)),
              ] else
                pesoText(selectedShipping!.fee, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: BColors.brandDark)),
            ]),
          ),
        if (offer != null && offer.count > 0) _voucherRow(offer: offer, pick: selectedVouchers[sellerId] ?? (discount: null, shipping: null), auto: !touchedSellers.contains(sellerId), title: 'Seller discount', onTap: () => _openShopVouchers(sellerId!, shop)),
      ]),
    );
  }

  Widget _platformPanel(VoucherOffer offer) => _card(
        child: _voucherRow(offer: offer, pick: (discount: platformDiscount, shipping: platformShipping), auto: !platformTouched, title: 'BuyTheWay discount', icon: Icons.confirmation_number_outlined, topBorder: false, onTap: _openPlatformVouchers),
      );

  /// "Seller discount · tags · −₱X ›" (or "N available") — tap to change.
  Widget _voucherRow({required VoucherOffer offer, required VoucherPick pick, required bool auto, required String title, required VoidCallback onTap, IconData icon = Icons.sell_outlined, bool topBorder = true}) {
    final empty = offer.count == 0;
    final discount = offer.find('discount', pick.discount);
    final shipping = offer.find('shipping', pick.shipping);
    final saved = (discount?.amount ?? 0) + (shipping?.amount ?? 0);
    final applied = [discount, shipping].whereType<VoucherOption>().toList();
    return InkWell(
      onTap: empty ? null : onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(border: topBorder ? const Border(top: BorderSide(color: BColors.divider)) : null),
        child: Row(children: [
          Icon(icon, size: 20, color: BColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              if (empty)
                const Text('No vouchers available for this order right now', style: BText.small)
              else if (applied.isEmpty)
                Text('${offer.count} voucher${offer.count == 1 ? '' : 's'} available', style: BText.small)
              else ...[
                Text(auto ? 'Best vouchers auto-applied' : 'Vouchers applied', style: BText.tiny),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final o in applied)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(6)),
                      child: Text(o.label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: BColors.brandDark)),
                    ),
                ]),
              ],
            ]),
          ),
          if (saved > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(8)),
              child: Text('-${peso(saved)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: BColors.brandDark)),
            ),
          if (!empty) const Icon(Icons.chevron_right, color: BColors.faint, size: 22),
        ]),
      ),
    );
  }

  // ---- Message to seller ----

  Future<void> _editNote(int shopCount) async {
    final controller = TextEditingController(text: messageToSeller);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Message to seller', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(shopCount > 1 ? 'This note is sent to every shop in your order.' : 'Anything the seller should know about your order — optional.', textAlign: TextAlign.center, style: BText.small),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 4,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'e.g. Please pack it carefully, or leave it with the guard.',
              filled: true,
              fillColor: BColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BColors.brand, width: 1.5)),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            if (messageToSeller.isNotEmpty)
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, ''), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), shape: const StadiumBorder()), child: const Text('Remove note'))),
            if (messageToSeller.isNotEmpty) const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), style: FilledButton.styleFrom(backgroundColor: BColors.brand, minimumSize: const Size(0, 48), shape: const StadiumBorder()), child: const Text('Save note', style: TextStyle(fontWeight: FontWeight.w800))),
            ),
          ]),
        ]),
      ),
    );
    controller.dispose();
    if (result != null && mounted) setState(() => messageToSeller = result);
  }

  Widget _notePanel(int shopCount) => _card(
        child: InkWell(
          onTap: () => _editNote(shopCount),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(children: [
              const Icon(Icons.edit_note_rounded, size: 22, color: BColors.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(shopCount > 1 ? 'Message to sellers' : 'Message to seller', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  if (messageToSeller.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(messageToSeller, maxLines: 2, overflow: TextOverflow.ellipsis, style: BText.small)),
                ]),
              ),
              Text(messageToSeller.isEmpty ? 'Add note' : 'Edit', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BColors.muted)),
              const Icon(Icons.chevron_right, color: BColors.faint, size: 22),
            ]),
          ),
        ),
      );

  // ---- Shipping / payment / summary ----

  Widget _shippingPanel() {
    return _card(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.local_shipping_outlined, size: 20, color: BColors.brand),
          SizedBox(width: 8),
          Text('Shipping option', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        if (loadingShipping && shippingOptions.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: SkeletonBox(height: 44))
        else if (shippingError != null)
          Row(children: [
            Expanded(child: Text(shippingError!, style: const TextStyle(fontSize: 12.5, color: BColors.error))),
            TextButton(onPressed: () => _loadShipping(force: true), child: const Text('Retry')),
          ])
        else
          RadioGroup<String>(
            groupValue: shippingMethod,
            onChanged: (v) {
              setState(() => shippingMethod = v!);
              _loadVouchers(); // shipping vouchers are worth the chosen fee
            },
            child: Column(children: shippingOptions.map((o) => RadioListTile<String>(
                value: o.id,
                enabled: o.available,
                activeColor: BColors.brand,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Row(children: [
                  Expanded(child: Text(o.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: o.available ? BColors.ink : BColors.faint))),
                  Text(peso(o.fee * sellerCount), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: o.available ? BColors.ink : BColors.faint)),
                ]),
                subtitle: Text(o.available ? (o.description ?? '') : (o.unavailableReason ?? 'Not available for this order'), style: BText.tiny),
              )).toList()),
          ),
      ]),
    );
  }

  /// Cash on delivery remains visible, but the server can disable it for an
  /// overdue seller remittance.
  Widget _paymentPanel() => _card(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.account_balance_wallet_outlined, size: 20, color: BColors.brand),
            SizedBox(width: 8),
            Text('Payment method', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: codMethod?.available == false ? BColors.background : BColors.brandSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: codMethod?.available == false ? BColors.faint : BColors.brand, width: 1.4)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: codMethod?.available == false ? BColors.faint : BColors.brand, borderRadius: BorderRadius.circular(6)),
                child: const Text('COD', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Cash on delivery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: codMethod?.available == false ? BColors.faint : BColors.ink)),
                  const SizedBox(height: 2),
                  const Text('Pay the courier when your parcel arrives.', style: BText.tiny),
                  if (codMethod?.available == false) ...[
                    const SizedBox(height: 4),
                    Text(codMethod?.unavailableReason ?? 'COD is currently unavailable.', style: const TextStyle(fontSize: 11.5, color: BColors.error, fontWeight: FontWeight.w700)),
                  ],
                ]),
              ),
              Icon(Icons.check_circle_rounded, color: codMethod?.available == false ? BColors.faint : BColors.brand),
            ]),
          ),
        ]),
      );

  Widget _summaryPanel() {
    Widget row(String label, String? value, {bool sub = false, bool discount = false, String? group, bool negative = false, num amount = 0, String? hint}) {
      final style = TextStyle(fontSize: sub ? 13 : 14.5, fontWeight: sub ? FontWeight.w500 : FontWeight.w800, color: discount ? BColors.brandDark : BColors.ink);
      final open = group == null || !_collapsed.contains(group);
      final content = Padding(
        // Collapsible rows get ~44px of height so they're comfortable to tap.
        padding: EdgeInsets.fromLTRB(sub ? 14 : 0, group == null ? 4 : 12, 0, group == null ? 4 : 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: sub ? 13 : 14.5, fontWeight: sub ? FontWeight.w400 : FontWeight.w700, color: sub ? BColors.muted : BColors.ink)),
              if (!open && hint != null) Text(hint, style: BText.tiny),
            ]),
          ),
          if (value != null) Text(value, style: style) else pesoText(amount, style: style),
          // Fixed-width slot keeps amounts aligned whether or not a row can collapse.
          SizedBox(
            width: 26,
            child: group == null
                ? null
                : AnimatedRotation(
                    turns: open ? 0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_up_rounded, size: 24, color: BColors.brand),
                  ),
          ),
        ]),
      );
      if (group == null) return content;
      return InkWell(onTap: () => setState(() => open ? _collapsed.add(group) : _collapsed.remove(group)), child: content);
    }

    bool open(String g) => !_collapsed.contains(g);
    final shippingAfter = math.max(0.0, shippingFee - shippingDiscount);
    return _card(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(children: [
        const Align(alignment: Alignment.centerLeft, child: Text('Order summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        const SizedBox(height: 8),
        if (saleSavings > 0) ...[
          row('Product subtotal', null, amount: subtotal, group: 'product', hint: 'Sale price · you save ${peso(saleSavings)}'),
          if (open('product')) ...[
            row('Original price', null, amount: originalSubtotal, sub: true),
            row('Sale discount', null, amount: saleSavings, negative: true, sub: true, discount: true),
          ],
        ] else
          row('Product subtotal', null, amount: subtotal),
        if (loadingShipping) row('Shipping subtotal', '…') else row('Shipping subtotal', null, amount: shippingAfter, group: 'shipping', hint: shippingDiscount > 0 ? '${peso(shippingFee)} fee − ${peso(shippingDiscount)} discount' : null),
        if (open('shipping')) ...[
          if (loadingShipping) row(sellerCount > 1 ? 'Shipping fee (× $sellerCount shops)' : 'Shipping fee', '…', sub: true) else row(sellerCount > 1 ? 'Shipping fee (× $sellerCount shops)' : 'Shipping fee', null, amount: shippingFee, sub: true),
          if (shippingDiscount > 0) row('Shipping discount', null, amount: shippingDiscount, negative: true, sub: true, discount: true),
        ],
        if (voucherDiscount > 0) ...[
          row('Voucher discounts', null, amount: voucherDiscount, negative: true, discount: true, group: 'voucher', hint: [if (shopDiscountSavings > 0) 'Shop', if (platformDiscountSavings > 0) 'BuyTheWay'].join(' + ')),
          if (open('voucher')) ...[
            if (shopDiscountSavings > 0) row('Shop vouchers', null, amount: shopDiscountSavings, negative: true, sub: true, discount: true),
            if (platformDiscountSavings > 0) row('BuyTheWay vouchers', null, amount: platformDiscountSavings, negative: true, sub: true, discount: true),
          ],
        ],
        const Divider(height: 22, color: BColors.divider),
        Row(children: [
          const Expanded(child: Text('Total', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
          pesoText(total, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: BColors.brandDark)),
          const SizedBox(width: 26),
        ]),
      ]),
    );
  }
}

/// Delivery address card at the top of checkout.
class _AddressPanel extends StatelessWidget {
  const _AddressPanel({required this.address, required this.loading, required this.onTap});

  final Address? address;
  final bool loading;
  final VoidCallback onTap;

  /// `(+63)91******67` — enough to recognise the number without showing it.
  static String _masked(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63')) digits = '0${digits.substring(2)}';
    if (digits.length < 6) return raw;
    return '(+63)${digits.substring(1, 3)}${'*' * (digits.length - 5)}${digits.substring(digits.length - 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final a = address;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: BColors.border), boxShadow: softShadow(0.03)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.location_on_rounded, color: BColors.brand, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: loading
                  ? const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SkeletonBox(height: 13, width: 160), SizedBox(height: 8), SkeletonBox(height: 12)])
                  : a == null
                      ? const Padding(padding: EdgeInsets.symmetric(vertical: 9), child: Text('Add a delivery address', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: BColors.brand)))
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: a.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                              TextSpan(text: '  ${_masked(a.phone)}', style: const TextStyle(color: BColors.muted, fontSize: 13)),
                            ]),
                            style: const TextStyle(fontSize: 15),
                          ),
                          const SizedBox(height: 3),
                          Text(a.formatted, style: const TextStyle(fontSize: 13.5, color: BColors.ink, height: 1.4)),
                          if (!a.isComplete) ...[
                            const SizedBox(height: 6),
                            const Text('Incomplete — tap to add the province, city and barangay.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BColors.error)),
                          ],
                        ]),
            ),
            const Padding(padding: EdgeInsets.only(top: 8), child: Icon(Icons.chevron_right, color: BColors.faint)),
          ]),
        ),
      ),
    );
  }
}
