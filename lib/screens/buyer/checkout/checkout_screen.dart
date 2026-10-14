import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/api_service.dart';
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
  int sellerCount = 1;
  String shippingMethod = 'standard';
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

  List<CartItem> get items => widget.items;

  @override
  void initState() {
    super.initState();
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
      final (options, count) = await store.api.shippingOptions(ids, addressId: addressId);
      if (!mounted) return;
      final before = shippingMethod;
      setState(() {
        shippingOptions = options;
        sellerCount = count;
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
      setState(() {
        voucherQuote = quote;
        for (final entry in quote.sellers.entries) {
          final offer = entry.value;
          final current = selectedVouchers[entry.key];
          if (!touchedSellers.contains(entry.key) || current == null || !_stillValid(offer.discount, current.discount) || !_stillValid(offer.shipping, current.shipping)) {
            selectedVouchers[entry.key] = (discount: offer.bestDiscountId, shipping: offer.bestShippingId);
          }
        }
        final platform = quote.platform;
        if (platform != null && (!platformTouched || !_stillValid(platform.discount, platformDiscount) || !_stillValid(platform.shipping, platformShipping))) {
          platformDiscount = platform.bestDiscountId;
          platformShipping = platform.bestShippingId;
          if (platform.exclusive) _clearShopVouchers();
        }
        quotingVouchers = false;
      });
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

  double get total => math.max(0, subtotal + shippingFee - shopSavings - platformSavings);

  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  String get blockReason {
    final a = address;
    if (a == null) return 'Add a delivery address to continue.';
    if (!a.isComplete) return 'Complete this address (province, city, barangay).';
    if (loadingShipping) return 'Loading shipping options…';
    if (shippingError != null || selectedShipping == null) return 'Shipping options unavailable — tap retry.';
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
    final a = address!;
    final confirmed = await confirmDialog(
      context,
      title: 'Place this order?',
      message: 'You\'re ordering $itemCount ${itemCount == 1 ? 'item' : 'items'} for ${peso(total)}, '
          'paying with Cash on Delivery. Delivering to ${a.fullName}.',
      confirmLabel: 'Place order',
      cancelLabel: 'Keep reviewing',
    );
    if (!confirmed || !mounted) return;

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
                'unit_price': i.price,
              })
          .toList(),
      'vouchers': [
        for (final id in voucherQuote.sellers.keys)
          if (selectedVouchers[id]?.discount != null || selectedVouchers[id]?.shipping != null)
            {'seller_id': id, 'discount_voucher_id': selectedVouchers[id]!.discount, 'shipping_voucher_id': selectedVouchers[id]!.shipping},
      ],
      'platform_vouchers': {'discount_voucher_id': platformDiscount, 'shipping_voucher_id': platformShipping},
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
      showToast(
        context,
        e is ApiException && e.statusCode == 422 ? message : 'We couldn\'t place your order. Nothing was charged. $message',
        error: true,
      );
      _loadVouchers(); // a voucher may have expired or run out meanwhile
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<CartItem>>{};
    for (final i in items) {
      groups.putIfAbsent(i.seller, () => []).add(i);
    }
    final reason = blockReason;
    final platformOffer = voucherQuote.platform;

    return Scaffold(
      backgroundColor: BColors.background,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        surfaceTintColor: BColors.surface,
        foregroundColor: BColors.ink,
        title: const Text('Checkout', style: BText.title),
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 16), children: [
        _AddressPanel(address: address, loading: address == null && store.loadingAddresses, onTap: _pickAddress),
        for (final entry in groups.entries) _shopPanel(entry.key, entry.value),
        if (platformOffer != null && platformOffer.count > 0) _platformPanel(platformOffer),
        _shippingPanel(),
        _paymentPanel(),
        Panel(
          child: Column(children: [
            _summaryRow('Merchandise subtotal', peso(subtotal)),
            _summaryRow(
              sellerCount > 1 ? 'Shipping (${selectedShipping?.name ?? '—'} × $sellerCount shops)' : 'Shipping (${selectedShipping?.name ?? '—'})',
              loadingShipping ? '…' : peso(shippingFee),
            ),
            if (shopSavings > 0) _summaryRow('Shop vouchers', '-${peso(shopSavings)}', valueColor: BColors.success),
            if (platformSavings > 0) _summaryRow('BuyTheWay vouchers', '-${peso(platformSavings)}', valueColor: BColors.success),
            const Divider(height: 20, color: BColors.divider),
            _summaryRow('Total payment', peso(total), bold: true, valueColor: BColors.cta),
            if (totalSavings > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Align(alignment: Alignment.centerRight, child: Text('You save ${peso(totalSavings)} with vouchers', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BColors.success))),
              ),
          ]),
        ),
        if (sellerCount > 1)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('Items from different shops ship separately, so you\'ll get one order per shop.', style: BText.tiny),
          ),
      ]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: BColors.surface, border: Border(top: BorderSide(color: BColors.border))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text.rich(TextSpan(children: [
                      const TextSpan(text: 'Total ', style: TextStyle(fontSize: 13)),
                      TextSpan(text: peso(total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: BColors.cta)),
                    ])),
                    if (reason.isNotEmpty)
                      Text(reason, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: BColors.error))
                    else if (totalSavings > 0)
                      Text('Saved ${peso(totalSavings)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: BColors.success)),
                  ]),
                ),
              ),
              SizedBox(
                width: 140,
                height: 60,
                child: ElevatedButton(
                  onPressed: reason.isEmpty && !placing ? _placeOrder : null,
                  style: BButtons.cta(height: 60).copyWith(shape: const WidgetStatePropertyAll(RoundedRectangleBorder())),
                  child: placing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Place Order'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// One shop's items, then its voucher row (discount + shipping vouchers).
  Widget _shopPanel(String shop, List<CartItem> shopItems) {
    final sellerId = shopItems.map((i) => i.sellerId).whereType<String>().firstOrNull;
    final offer = sellerId == null ? null : voucherQuote.sellers[sellerId];
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            const Icon(Icons.storefront, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(shop, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          ]),
        ),
        for (final item in shopItems)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CategoryThumb(category: item.category, image: item.image, size: 64),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, height: 1.3)),
                  if (item.variation != null) Text(item.variation!, style: BText.tiny),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(peso(item.effectivePrice), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('x${item.quantity}', style: BText.small),
                  ]),
                ]),
              ),
            ]),
          ),
        if (offer != null && offer.count > 0) _voucherRow(offer: offer, pick: selectedVouchers[sellerId] ?? (discount: null, shipping: null), auto: !touchedSellers.contains(sellerId), onTap: () => _openShopVouchers(sellerId!, shop)),
      ]),
    );
  }

  Widget _platformPanel(VoucherOffer offer) => Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Icon(Icons.verified_rounded, size: 18, color: BColors.brand),
              SizedBox(width: 6),
              Expanded(child: Text('BuyTheWay vouchers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
            ]),
          ),
          _voucherRow(offer: offer, pick: (discount: platformDiscount, shipping: platformShipping), auto: !platformTouched, onTap: _openPlatformVouchers),
        ]),
      );

  /// "Vouchers · applied tags · −₱X ›" (or "N available") — tap to change.
  Widget _voucherRow({required VoucherOffer offer, required VoucherPick pick, required bool auto, required VoidCallback onTap}) {
    final discount = offer.find('discount', pick.discount);
    final shipping = offer.find('shipping', pick.shipping);
    final saved = (discount?.amount ?? 0) + (shipping?.amount ?? 0);
    final applied = [discount, shipping].whereType<VoucherOption>().toList();
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: BColors.divider))),
        child: Row(children: [
          const Icon(Icons.confirmation_number_outlined, size: 18, color: BColors.cta),
          const SizedBox(width: 8),
          Expanded(
            child: applied.isEmpty
                ? Text('${offer.count} voucher${offer.count == 1 ? '' : 's'} available', style: const TextStyle(fontSize: 13, color: BColors.muted, fontWeight: FontWeight.w600))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(auto ? 'Best vouchers auto-applied' : 'Vouchers applied', style: const TextStyle(fontSize: 12, color: BColors.muted)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final o in applied)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: o.isShipping ? BColors.brandSurface : BColors.ctaSurface, borderRadius: BorderRadius.circular(6)),
                          child: Text(o.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: o.isShipping ? BColors.brandDark : BColors.cta)),
                        ),
                    ]),
                  ]),
          ),
          if (saved > 0) Text('-${peso(saved)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: BColors.success)),
          const Icon(Icons.chevron_right, color: BColors.faint, size: 20),
        ]),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: bold ? 14.5 : 13, color: bold ? BColors.ink : BColors.muted, fontWeight: bold ? FontWeight.w600 : FontWeight.w400))),
          Text(value, style: TextStyle(fontSize: bold ? 17 : 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: valueColor ?? BColors.ink)),
        ]),
      );

  Widget _shippingPanel() {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.local_shipping_outlined, size: 18, color: BColors.brand),
          SizedBox(width: 8),
          Text('Shipping Option', style: BText.section),
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
                  Expanded(child: Text(o.name, style: TextStyle(fontSize: 14, color: o.available ? BColors.ink : BColors.faint))),
                  Text(peso(o.fee * sellerCount), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: o.available ? BColors.ink : BColors.faint)),
                ]),
                subtitle: Text(o.available ? (o.description ?? '') : (o.unavailableReason ?? 'Not available for this order'), style: BText.tiny),
              )).toList()),
          ),
      ]),
    );
  }

  /// Cash on delivery is the only payment method (no payment provider is active).
  Widget _paymentPanel() => Panel(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.account_balance_wallet_outlined, size: 18, color: BColors.brand),
            SizedBox(width: 8),
            Text('Payment Method', style: BText.section),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: BColors.brand, width: 1.4)),
            child: const Row(children: [
              Icon(Icons.payments_outlined, color: BColors.brand),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Cash on Delivery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Pay the courier when your parcel arrives.', style: BText.tiny),
                ]),
              ),
              Icon(Icons.check_circle_rounded, color: BColors.brand),
            ]),
          ),
        ]),
      );
}

/// Delivery address card with the "envelope" stripe shoppers recognise
/// from other PH marketplaces.
class _AddressPanel extends StatelessWidget {
  const _AddressPanel({required this.address, required this.loading, required this.onTap});

  final Address? address;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = address;
    return Container(
      color: BColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.location_on_outlined, color: BColors.cta, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: loading
                    ? const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SkeletonBox(height: 13, width: 160),
                        SizedBox(height: 8),
                        SkeletonBox(height: 12),
                      ])
                    : a == null
                        ? const Text('Add a delivery address', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: BColors.cta))
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Delivery Address', style: BText.small),
                            const SizedBox(height: 4),
                            Text('${a.fullName} | ${a.phone}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(a.formatted, style: const TextStyle(fontSize: 13, color: BColors.ink, height: 1.35)),
                            if (!a.isComplete) ...[
                              const SizedBox(height: 6),
                              const Text('Incomplete — tap to add the province, city and barangay.', style: TextStyle(fontSize: 12, color: BColors.error)),
                            ],
                          ]),
              ),
              const Icon(Icons.chevron_right, color: BColors.faint),
            ]),
          ),
        ),
        const SizedBox(height: 3, width: double.infinity, child: CustomPaint(painter: _StripePainter())),
      ]),
    );
  }
}

class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const stripe = 18.0;
    final teal = Paint()..color = BColors.brand.withValues(alpha: 0.7);
    final orange = Paint()..color = BColors.cta.withValues(alpha: 0.7);
    var x = -size.height;
    var i = 0;
    while (x < size.width) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + stripe, 0)
        ..lineTo(x + stripe, size.height)
        ..close();
      canvas.drawPath(path, i.isEven ? teal : orange);
      x += stripe + 6;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
