import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/api_service.dart';
import '../account/addresses_screen.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../payments_util.dart';
import '../widgets/buyer_widgets.dart';
import 'order_placed_screen.dart';

/// Checkout for either the selected cart lines or a single Buy Now line.
/// Mirrors the web Checkout.vue contract: the server re-validates every
/// price/stock/coupon and splits into one order per seller; card and
/// wallet details are validated on-device and never sent.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.items, required this.fromCart});

  final List<CartItem> items;
  final bool fromCart;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

const _paymentOptions = [
  ('cod', 'Cash on Delivery', 'Pay when your package arrives', Icons.payments_outlined),
  ('gcash', 'GCash', 'Pay with your GCash wallet', Icons.account_balance_wallet_outlined),
  ('maya', 'Maya', 'Pay with your Maya wallet', Icons.account_balance_wallet_outlined),
  ('card', 'Credit / Debit Card', 'Visa, Mastercard, AMEX, JCB', Icons.credit_card),
];

class _CheckoutScreenState extends State<CheckoutScreen> {
  final store = BuyerStore.instance;

  Address? address;

  List<ShippingOption> shippingOptions = [];
  int sellerCount = 1;
  String shippingMethod = 'standard';
  bool loadingShipping = true;
  String? shippingError;

  Map<String, CouponQuote> couponQuote = {};
  final Map<String, String?> selectedCoupons = {};
  final Set<String> touchedCoupons = {};

  String paymentMethod = 'cod';
  List<PaymentMethod> savedMethods = [];
  String? savedMethodId;
  final cardHolder = TextEditingController();
  final cardNumber = TextEditingController();
  final cardExpiry = TextEditingController();
  final cardCvc = TextEditingController();
  final walletPhone = TextEditingController();

  bool placing = false;
  bool saveDetails = false;

  List<CartItem> get items => widget.items;
  String _key(CartItem i) => '${i.productId}:${i.variantId ?? ''}';

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
    });
    if (address != null) _loadShipping();
    _loadCoupons();
    store.api.paymentMethods().then((list) {
      if (mounted) setState(() => savedMethods = list);
    }).catchError((_) {});
    for (final c in [cardHolder, cardNumber, cardExpiry, cardCvc, walletPhone]) {
      c.addListener(_rebuild);
    }
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    for (final c in [cardHolder, cardNumber, cardExpiry, cardCvc, walletPhone]) {
      c.dispose();
    }
    super.dispose();
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
      setState(() {
        shippingOptions = options;
        sellerCount = count;
        if (!options.any((o) => o.id == shippingMethod && o.available)) shippingMethod = 'standard';
      });
    } catch (e) {
      _shippingFor = null;
      if (mounted) setState(() => shippingError = store.handleError(e));
    } finally {
      if (mounted) setState(() => loadingShipping = false);
    }
  }

  Future<void> _loadCoupons() async {
    final lines = {for (final i in items) _key(i): {'key': _key(i), 'product_id': i.productId, 'variant_id': i.variantId}}.values.toList();
    try {
      final quote = await store.api.quoteCoupons(lines);
      if (!mounted) return;
      setState(() {
        couponQuote = quote;
        for (final line in lines) {
          final key = line['key'] as String;
          final options = quote[key]?.options ?? const [];
          // Keep a still-valid manual pick; otherwise auto-apply the best.
          if (!touchedCoupons.contains(key) || !options.any((o) => o.id == selectedCoupons[key])) {
            selectedCoupons[key] = quote[key]?.best;
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => couponQuote = {});
    }
  }

  // ---------------- Totals ----------------

  double get subtotal => items.fold(0.0, (s, i) => s + i.effectivePrice * i.quantity);

  ShippingOption? get selectedShipping => shippingOptions.where((o) => o.id == shippingMethod).firstOrNull;

  double get shippingFee => (selectedShipping?.fee ?? 0) * sellerCount;

  Coupon? _applied(CartItem i) {
    final id = selectedCoupons[_key(i)];
    if (id == null) return null;
    return couponQuote[_key(i)]?.options.where((o) => o.id == id).firstOrNull;
  }

  double get discount => items.fold(0.0, (s, i) => s + (_applied(i)?.discount ?? 0));

  double get total => (subtotal + shippingFee - discount).clamp(0, double.infinity).toDouble();

  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  // ---------------- Payment validation ----------------

  String? get paymentProblem {
    if (paymentMethod == 'cod') return null;
    if (savedMethodId != null) return null;
    if (paymentMethod == 'card') {
      if (cardHolder.text.trim().isEmpty) return 'Enter the cardholder name.';
      if (!luhnValid(cardNumber.text)) return 'Enter a valid card number.';
      final expiry = parseExpiry(cardExpiry.text);
      if (expiry == null) return 'Enter the card expiry as MM/YY.';
      if (expiryPassed(expiry)) return 'This card has expired.';
      if (!RegExp(r'^\d{3,4}$').hasMatch(cardCvc.text.trim())) return 'Enter the 3–4 digit CVC.';
      return null;
    }
    if (!validPhPhone(walletPhone.text)) return 'Enter your ${paymentLabel(paymentMethod)} number (09XX XXX XXXX).';
    return null;
  }

  String get blockReason {
    final a = address;
    if (a == null) return 'Add a delivery address to continue.';
    if (!a.isComplete) return 'Complete this address (province, city, barangay).';
    if (loadingShipping) return 'Loading shipping options…';
    if (shippingError != null || selectedShipping == null) return 'Shipping options unavailable — tap retry.';
    return paymentProblem ?? '';
  }

  // ---------------- Actions ----------------

  Future<void> _pickAddress() async {
    final picked = await Navigator.of(context).push<Address>(
      MaterialPageRoute(builder: (_) => AddressesScreen(pickMode: true, selectedId: address?.id)),
    );
    if (picked != null && mounted) {
      setState(() => address = picked);
      _loadShipping();
    } else if (mounted && address != null && !store.addresses.any((a) => a.id == address!.id)) {
      // The chosen address was deleted while picking.
      setState(() => address = store.defaultAddress);
      _loadShipping();
    }
  }

  Future<void> _pickCoupon(CartItem item) async {
    final key = _key(item);
    final options = couponQuote[key]?.options ?? const <Coupon>[];
    final takenElsewhere = selectedCoupons.entries.where((e) => e.key != key && e.value != null).map((e) => e.value).toSet();
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: BColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BRadius.md))),
      builder: (context) => SafeArea(
        child: RadioGroup<String>(
          groupValue: selectedCoupons[key] ?? '',
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('Select a voucher', style: BText.title)),
          ...options.map((o) {
            final taken = takenElsewhere.contains(o.id);
            return RadioListTile<String>(
              value: o.id,
              enabled: !taken,
              activeColor: BColors.cta,
              title: Text(o.label, style: const TextStyle(fontWeight: FontWeight.w700, color: BColors.cta)),
              subtitle: Text(
                taken
                    ? 'Already used on another item'
                    : [
                        if ((o.discount ?? 0) > 0) 'Save ${peso(o.discount!)}',
                        if (o.expiresAt != null) 'Valid till ${formatDate(o.expiresAt)}',
                        if (o.id == couponQuote[key]?.best) 'Best value',
                      ].join(' · '),
                style: BText.small,
              ),
            );
          }),
          const RadioListTile<String>(
            value: '',
            activeColor: BColors.cta,
            title: Text('Don\'t use a voucher'),
          ),
          const SizedBox(height: 8),
        ]),
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      touchedCoupons.add(key);
      selectedCoupons[key] = result.isEmpty ? null : result;
    });
  }

  Future<void> _placeOrder() async {
    final a = address!;
    final confirmed = await confirmDialog(
      context,
      title: 'Place this order?',
      message: 'You\'re ordering $itemCount ${itemCount == 1 ? 'item' : 'items'} for ${peso(total)}, '
          'paying with ${paymentLabel(paymentMethod)}. Delivering to ${a.fullName}.',
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
                'coupon_id': selectedCoupons[_key(i)],
                'quantity': i.quantity,
                'unit_price': i.price,
              })
          .toList(),
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
      'discount': discount,
      'total': total,
    };

    try {
      final refs = await store.api.checkout(payload);
      if (widget.fromCart) store.removeItems(items.map((i) => i.cartId));
      _persistPaymentDetails();
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
      _loadCoupons(); // a voucher may have expired or run out meanwhile
    }
  }

  /// Best-effort "save for next time" — only display-safe fields are sent,
  /// and it never blocks the order confirmation.
  void _persistPaymentDetails() {
    if (!saveDetails || paymentMethod == 'cod' || savedMethodId != null) return;
    final Map<String, dynamic> payload;
    if (paymentMethod == 'card') {
      final (month, year) = parseExpiry(cardExpiry.text)!;
      final digits = digitsOnly(cardNumber.text);
      payload = {
        'type': 'card',
        'brand': detectCardBrand(digits),
        'last4': digits.substring(digits.length - 4),
        'holder': cardHolder.text.trim(),
        'exp_month': month.toString().padLeft(2, '0'),
        'exp_year': year,
        'is_primary': savedMethods.isEmpty,
      };
    } else {
      payload = {
        'type': 'wallet',
        'provider': paymentMethod == 'maya' ? 'Maya' : 'GCash',
        'phone_masked': maskPhone(walletPhone.text),
        'is_primary': savedMethods.isEmpty,
      };
    }
    store.api.addPaymentMethod(payload).catchError((_) {});
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<CartItem>>{};
    for (final i in items) {
      groups.putIfAbsent(i.seller, () => []).add(i);
    }
    final reason = blockReason;

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
        for (final entry in groups.entries)
          Panel(
            padding: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(children: [
                  const Icon(Icons.storefront, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                ]),
              ),
              for (final item in entry.value) ...[
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
                if ((couponQuote[_key(item)]?.options ?? const []).isNotEmpty)
                  InkWell(
                    onTap: () => _pickCoupon(item),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: BColors.divider))),
                      child: Row(children: [
                        const Icon(Icons.confirmation_number_outlined, size: 18, color: BColors.cta),
                        const SizedBox(width: 8),
                        const Text('Voucher', style: TextStyle(fontSize: 13)),
                        const Spacer(),
                        Text(
                          _applied(item) != null
                              ? '-${peso(_applied(item)!.discount ?? 0)}'
                              : '${couponQuote[_key(item)]!.options.length} available',
                          style: TextStyle(fontSize: 13, color: _applied(item) != null ? BColors.cta : BColors.muted, fontWeight: FontWeight.w600),
                        ),
                        const Icon(Icons.chevron_right, color: BColors.faint, size: 20),
                      ]),
                    ),
                  ),
              ],
            ]),
          ),
        _shippingPanel(),
        _paymentPanel(),
        Panel(
          child: Column(children: [
            _summaryRow('Merchandise subtotal', peso(subtotal)),
            _summaryRow(
              sellerCount > 1 ? 'Shipping (${selectedShipping?.name ?? '—'} × $sellerCount shops)' : 'Shipping (${selectedShipping?.name ?? '—'})',
              loadingShipping ? '…' : peso(shippingFee),
            ),
            if (discount > 0) _summaryRow('Voucher discount', '-${peso(discount)}', valueColor: BColors.cta),
            const Divider(height: 20, color: BColors.divider),
            _summaryRow('Total payment', peso(total), bold: true, valueColor: BColors.cta),
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
                      Text(reason, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: BColors.error)),
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
            onChanged: (v) => setState(() => shippingMethod = v!),
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

  Widget _paymentPanel() {
    final saved = savedMethods.where((m) => m.checkoutCode == paymentMethod).toList();
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.account_balance_wallet_outlined, size: 18, color: BColors.brand),
          SizedBox(width: 8),
          Text('Payment Method', style: BText.section),
        ]),
        const SizedBox(height: 4),
        RadioGroup<String>(
          groupValue: paymentMethod,
          onChanged: (v) => setState(() {
            paymentMethod = v!;
            final matching = savedMethods.where((m) => m.checkoutCode == v);
            savedMethodId = (matching.where((m) => m.isPrimary).firstOrNull ?? matching.firstOrNull)?.id;
          }),
          child: Column(
            children: _paymentOptions.map((o) {
              final (id, name, desc, icon) = o;
              final active = paymentMethod == id;
              return Column(children: [
                RadioListTile<String>(
                  value: id,
                  activeColor: BColors.brand,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  secondary: Icon(icon, color: active ? BColors.brand : BColors.muted),
                  title: Text(name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(desc, style: BText.tiny),
                ),
                if (active && id != 'cod')
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Column(children: [
                      // '' stands for "enter new details" — RadioGroup values must be non-null.
                      if (saved.isNotEmpty)
                        RadioGroup<String>(
                          groupValue: savedMethodId ?? '',
                          onChanged: (v) => setState(() => savedMethodId = (v == null || v.isEmpty) ? null : v),
                          child: Column(children: [
                            ...saved.map((m) => RadioListTile<String>(
                                  value: m.id,
                                  dense: true,
                                  activeColor: BColors.brand,
                                  title: Text(m.display, style: const TextStyle(fontSize: 13.5)),
                                  subtitle: m.isPrimary ? const Text('Primary', style: BText.tiny) : null,
                                )),
                            RadioListTile<String>(
                              value: '',
                              dense: true,
                              activeColor: BColors.brand,
                              title: Text(id == 'card' ? 'Use a new card' : 'Use a new number', style: const TextStyle(fontSize: 13.5)),
                            ),
                          ]),
                        ),
                      if (savedMethodId == null) ...[
                        id == 'card' ? _cardForm() : _walletForm(id),
                        CheckboxListTile(
                          value: saveDetails,
                          onChanged: (v) => setState(() => saveDetails = v ?? false),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: BColors.brand,
                          title: Text('Save this ${id == 'card' ? 'card' : 'number'} for next time', style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ]),
                  ),
              ]);
            }).toList(),
          ),
        ),
      ]),
    );
  }

  InputDecoration _input(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BRadius.sm), borderSide: const BorderSide(color: BColors.brand, width: 1.5)),
      );

  Widget _walletForm(String id) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: TextField(
          controller: walletPhone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')), LengthLimitingTextInputFormatter(16)],
          decoration: _input('${paymentLabel(id)} mobile number', hint: '09XX XXX XXXX'),
        ),
      );

  Widget _cardForm() => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(children: [
          TextField(controller: cardHolder, textCapitalization: TextCapitalization.words, decoration: _input('Cardholder name')),
          const SizedBox(height: 10),
          TextField(
            controller: cardNumber,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(23)],
            decoration: _input('Card number'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: cardExpiry,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')), LengthLimitingTextInputFormatter(5)],
                decoration: _input('Expiry', hint: 'MM/YY'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: cardCvc,
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: _input('CVC'),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          const Row(children: [
            Icon(Icons.lock_outline, size: 13, color: BColors.muted),
            SizedBox(width: 4),
            Expanded(child: Text('Card details are checked on this device and never sent with your order.', style: BText.tiny)),
          ]),
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
