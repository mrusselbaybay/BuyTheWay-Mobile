import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../catalog/product_list_screen.dart';
import '../chat/chat_thread_screen.dart';
import '../product/product_detail_screen.dart';
import '../widgets/buyer_widgets.dart';
import 'order_actions.dart';
import 'parcel_tracking.dart';
import 'return_request_screen.dart';

/// Order details, in three moods that follow the order:
/// in progress (stepper + tracking), delivered (refund / reorder) and
/// closed — cancelled or returned (outcome + reorder).
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order});

  final Order order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final store = BuyerStore.instance;
  late Order order = widget.order;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Shows the cached order immediately, then pulls the latest status.
  Future<void> _refresh() async {
    try {
      final fresh = await store.api.order(order.number);
      if (!mounted) return;
      setState(() => order = fresh);
      store.replaceOrder(fresh);
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    }
  }

  bool get _inProgress => order.returnState == null && const [OrderStatus.toShip, OrderStatus.processing, OrderStatus.inTransit].contains(order.status);
  bool get _delivered => order.status == OrderStatus.delivered && order.returnState == null;

  /// Only after the buyer confirmed receipt, one open request per item —
  /// same gate as the web OrderDetails page / ReturnController.
  bool _canReturn(OrderItem item) => order.status == OrderStatus.delivered && order.receivedAt != null && item.returnStatus == null;

  StatusEvent? get _latest => order.history.isEmpty ? null : order.history.reduce((a, b) => (b.at?.isAfter(a.at ?? DateTime(0)) ?? false) ? b : a);

  Color get _tone {
    if (order.status == OrderStatus.cancelled) return BColors.muted;
    if (order.returnState == 'to_return') return BColors.warning;
    if (order.status == OrderStatus.delivered) return BColors.success;
    return BColors.brand;
  }

  Future<void> _requestReturn(OrderItem item) async {
    final submitted = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ReturnRequestScreen(order: order, item: item)));
    if (submitted == true && mounted) _refresh();
  }

  Future<void> _reorder(List<OrderItem> items, {required bool goToCart}) async {
    if (_busy) return;
    setState(() => _busy = true);
    await reorderItems(context, items, goToCart: goToCart);
    if (mounted) setState(() => _busy = false);
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    showToast(context, '$label copied');
  }

  void _showTimeline() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: BColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _TimelineSheet(events: order.history),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = _BottomBar(
      order: order,
      busy: _busy,
      onBuyAgain: () => _reorder(order.items, goToCart: true),
      onUpdated: (o) {
        setState(() => order = o);
        store.replaceOrder(o);
      },
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: BColors.background,
        body: RefreshIndicator(
          color: BColors.brand,
          edgeOffset: MediaQuery.paddingOf(context).top,
          onRefresh: _refresh,
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            _Header(order: order, tone: _tone),
            Transform.translate(
              offset: const Offset(0, -22),
              child: Column(children: [
                _Section(
                  first: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (_inProgress) ...[
                      _Stepper(order: order),
                      const SizedBox(height: 18),
                      ParcelMapCard(key: ValueKey(order.number), orderNumber: order.number, history: order.history),
                    ],
                    _TrackingCard(order: order, latest: _latest, onTap: order.history.isEmpty ? null : _showTimeline),
                    const SizedBox(height: 16),
                    _AddressRow(order: order),
                  ]),
                ),
                const SizedBox(height: 8),
                _Section(child: _ShopAndItems(state: this)),
                const SizedBox(height: 8),
                _Section(child: _OrderInfo(order: order, onCopy: _copy)),
                const SizedBox(height: 8),
                _Section(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    if (order.sellerId != null)
                      _LinkTile(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Contact seller',
                        onTap: () => openSellerChat(context, sellerId: order.sellerId!, orderNumber: order.number),
                      ),
                    if (order.courierName != null && order.status == OrderStatus.inTransit)
                      _LinkTile(
                          icon: Icons.delivery_dining_outlined, label: 'Message ${order.courierName}', onTap: () => openCourierChat(context, order.number)),
                    if (order.history.isNotEmpty) _LinkTile(icon: Icons.history_rounded, label: 'Order timeline', onTap: _showTimeline),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        bottomNavigationBar: bottom.isEmpty ? null : bottom,
      ),
    );
  }
}

// ============================================================
// Header
// ============================================================

class _Header extends StatelessWidget {
  const _Header({required this.order, required this.tone});

  final Order order;
  final Color tone;

  static const _hi = TextStyle(color: BColors.brand, fontWeight: FontWeight.w700);

  (String, List<InlineSpan>) get _copy {
    final o = order;
    switch (o.displayStatus) {
      case OrderStatus.toShip:
        return ('Order placed', const [TextSpan(text: 'Waiting for the seller to prepare your order. You can still cancel it.')]);
      case OrderStatus.processing:
        return ('Preparing your order', const [TextSpan(text: 'The seller is packing your parcel for pickup.')]);
      case OrderStatus.inTransit:
        return (
          'On the way',
          [TextSpan(text: o.courierName != null ? '${o.courierName} is delivering your parcel.' : 'Your parcel is moving through our logistics network.')],
        );
      case OrderStatus.delivered:
        final delivered = o.history.where((h) => h.status == OrderStatus.delivered).map((h) => h.at).whereType<DateTime>().firstOrNull;
        if (o.receivedAt == null) {
          return (
            'Order delivered',
            [
              if (delivered != null) ...[const TextSpan(text: 'Delivered on '), TextSpan(text: formatDate(delivered), style: _hi), const TextSpan(text: '. ')],
              const TextSpan(text: 'Check your items, then confirm you\'ve received them.'),
            ]
          );
        }
        return (
          'Order completed',
          [
            const TextSpan(text: 'Received on '),
            TextSpan(text: formatDate(o.receivedAt), style: _hi),
            const TextSpan(text: '. You can still request a return or refund.'),
          ]
        );
      case OrderStatus.cancelled:
        final reason = o.history.where((h) => h.status == OrderStatus.cancelled).map((h) => h.note).whereType<String>().firstOrNull;
        return ('Order cancelled', [TextSpan(text: reason != null && reason.isNotEmpty ? 'Reason: $reason' : 'This order was cancelled.')]);
      case 'To Return':
        return ('Return in progress', const [TextSpan(text: 'Your return was approved. Hand the parcel back to the courier.')]);
      case 'Returned':
        return ('Refunded', [const TextSpan(text: 'Refund of '), TextSpan(text: peso(o.total), style: _hi), const TextSpan(text: ' completed.')]);
      default:
        return (o.displayStatus, const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, spans) = _copy;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(4, top + 4, 20, 44),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(tone.withValues(alpha: 0.16), BColors.background),
            Color.alphaBlend(BColors.brand.withValues(alpha: 0.05), BColors.background)
          ],
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: BColors.ink),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 24, height: 1.15, fontWeight: FontWeight.w800, color: BColors.ink, letterSpacing: -0.4)),
              if (spans.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text.rich(TextSpan(children: spans), style: const TextStyle(fontSize: 14, height: 1.4, color: BColors.muted)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

/// White block; the first one is rounded on top so it reads as a sheet
/// sliding over the tinted header.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.first = false, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final bool first;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: BColors.surface, borderRadius: first ? const BorderRadius.vertical(top: Radius.circular(24)) : null),
        child: child,
      );
}

// ============================================================
// Progress
// ============================================================

class _Stepper extends StatelessWidget {
  const _Stepper({required this.order});

  final Order order;

  static const _steps = [
    (Icons.receipt_long_rounded, 'Order placed'),
    (Icons.inventory_2_rounded, 'Packing'),
    (Icons.local_shipping_rounded, 'In transit'),
    (Icons.home_rounded, 'Delivered'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = switch (order.status) {
      OrderStatus.processing => 1,
      OrderStatus.inTransit => 2,
      OrderStatus.delivered => 3,
      _ => 0,
    };
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < _steps.length; i++)
        Expanded(
          child: Column(children: [
            SizedBox(
              height: 40,
              child: Row(children: [
                Expanded(child: i == 0 ? const SizedBox() : Container(height: 3, color: i <= current ? BColors.brand : BColors.divider)),
                if (i == current)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: BColors.brand,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: BColors.brand.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: Icon(_steps[i].$1, size: 20, color: Colors.white),
                  )
                else
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < current ? BColors.brand : BColors.surface,
                      border: Border.all(color: i < current ? BColors.brand : BColors.border, width: 2),
                    ),
                  ),
                Expanded(child: i == _steps.length - 1 ? const SizedBox() : Container(height: 3, color: i < current ? BColors.brand : BColors.divider)),
              ]),
            ),
            const SizedBox(height: 8),
            Text(
              _steps[i].$2,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: i == current ? FontWeight.w700 : FontWeight.w500, color: i <= current ? BColors.brand : BColors.faint),
            ),
          ]),
        ),
    ]);
  }
}

/// Latest event — "2:16 pm Delivered" — opens the full timeline.
class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.order, required this.latest, required this.onTap});

  final Order order;
  final StatusEvent? latest;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final status = latest?.status ?? o.status;
    final note = latest?.note;
    final sub = switch (o.status) {
      OrderStatus.delivered => 'Your package has been delivered.${o.recipientName != null ? '\nRecipient: ${o.recipientName}' : ''}',
      OrderStatus.cancelled => 'Your package delivery was cancelled.',
      _ => (note != null && note.isNotEmpty) ? note : 'We\'ll update you as your parcel moves.',
    };
    final at = latest?.at ?? o.createdAt;
    return Material(
      color: BColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(
                  TextSpan(children: [
                    if (at != null) TextSpan(text: '${formatDate(at, withTime: true).split(', ').last}  ', style: const TextStyle(color: BColors.brand)),
                    TextSpan(text: o.status == OrderStatus.cancelled ? 'Delivery cancelled' : status),
                  ]),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: BColors.ink),
                ),
                const SizedBox(height: 3),
                Text(sub, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.4, color: BColors.muted)),
              ]),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, color: BColors.faint),
          ]),
        ),
      ),
    );
  }
}

class _AddressRow extends StatefulWidget {
  const _AddressRow({required this.order});

  final Order order;

  @override
  State<_AddressRow> createState() => _AddressRowState();
}

class _AddressRowState extends State<_AddressRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: o.address == null ? null : () => setState(() => _open = !_open),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.location_on_rounded, size: 20, color: BColors.faint)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: o.recipientName ?? 'Recipient', style: const TextStyle(fontWeight: FontWeight.w800, color: BColors.ink)),
                if (o.contactNumber != null) TextSpan(text: '  ${o.contactNumber}', style: const TextStyle(color: BColors.muted)),
              ]),
              style: const TextStyle(fontSize: 14.5),
            ),
            if (o.address != null) ...[
              const SizedBox(height: 3),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: Text(o.address!,
                    maxLines: _open ? null : 2,
                    overflow: _open ? null : TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: BColors.muted)),
              ),
            ],
          ]),
        ),
        if (o.address != null)
          AnimatedRotation(
            turns: _open ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.keyboard_arrow_down_rounded, color: BColors.faint),
          ),
      ]),
    );
  }
}

// ============================================================
// Shop + items
// ============================================================

class _ShopAndItems extends StatelessWidget {
  const _ShopAndItems({required this.state});

  final _OrderDetailScreenState state;

  @override
  Widget build(BuildContext context) {
    final o = state.order;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: BColors.brandSurface, shape: BoxShape.circle, border: Border.all(color: BColors.border)),
          child: const Icon(Icons.storefront_rounded, size: 18, color: BColors.brand),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(o.seller,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: BColors.ink))),
        if (o.sellerId != null)
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductListScreen(title: o.seller, sellerId: o.sellerId))),
            style: TextButton.styleFrom(foregroundColor: BColors.muted, padding: const EdgeInsets.only(left: 8), minimumSize: const Size(44, 36)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Browse shop', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Icon(Icons.chevron_right_rounded, size: 18),
            ]),
          ),
      ]),
      const SizedBox(height: 14),
      for (var i = 0; i < o.items.length; i++) ...[
        if (i > 0) const Divider(height: 28, color: BColors.divider),
        _ItemBlock(state: state, item: o.items[i]),
      ],
    ]);
  }
}

class _ItemBlock extends StatelessWidget {
  const _ItemBlock({required this.state, required this.item});

  final _OrderDetailScreenState state;
  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final o = state.order;
    final tags = <(String, Color)>[
      if (item.couponCode != null && item.couponDiscount > 0) ('${item.couponCode} −${pesoCompact(item.couponDiscount)}', BColors.brand),
      if (item.returnStatus != null) ('Return ${item.returnStatus!.toLowerCase()}', BColors.warning),
      if (item.reviewRating != null) ('★ ${item.reviewRating} rated', BColors.star),
    ];
    final closed = o.status == OrderStatus.cancelled || o.returnState != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: item.productId == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: item.productId!))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: BColors.divider)),
            child: ClipRRect(borderRadius: BorderRadius.circular(13), child: NetImage(item.image, fallbackIcon: categoryIcon(item.category))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child:
                        Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.3, color: BColors.ink))),
                const SizedBox(width: 10),
                pesoText(item.unitPrice, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: BColors.ink)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                    child:
                        Text(item.variation ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: BColors.faint))),
                Text('×${item.quantity}', style: const TextStyle(fontSize: 13, color: BColors.muted)),
              ]),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final (label, c) in tags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(label,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color.alphaBlend(BColors.ink.withValues(alpha: 0.25), c))),
                    ),
                ]),
              ],
            ]),
          ),
        ]),
      ),
      if (o.returnState != null) ...[
        const SizedBox(height: 12),
        Row(children: [
          Icon(o.returnState == 'returned' ? Icons.check_circle_rounded : Icons.autorenew_rounded,
              size: 18, color: o.returnState == 'returned' ? BColors.success : BColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              o.returnState == 'returned' ? 'Refund completed' : 'Return in progress',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: BColors.ink),
            ),
          ),
          if (item.returnResolution != null) Flexible(child: Text(item.returnResolution!, maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.small)),
        ]),
      ],
      if (state._delivered || closed) ...[
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (state._delivered) ...[
            _ItemPill(label: 'Request refund', onTap: state._canReturn(item) ? () => state._requestReturn(item) : null),
            const SizedBox(width: 8),
          ],
          _ItemPill(
            icon: Icons.add_shopping_cart_rounded,
            label: 'Add to cart',
            onTap: state._busy ? null : () => state._reorder([item], goToCart: false),
          ),
        ]),
      ],
    ]);
  }
}

/// Item-level action; a null [onTap] renders it greyed out (e.g. refund
/// before receipt is confirmed) rather than hiding it.
class _ItemPill extends StatelessWidget {
  const _ItemPill({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = onTap == null ? BColors.faint : BColors.ink;
    return Material(
      color: onTap == null ? BColors.divider.withValues(alpha: 0.6) : BColors.background,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 17, color: fg), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg)),
          ]),
        ),
      ),
    );
  }
}

// ============================================================
// Order info
// ============================================================

class _OrderInfo extends StatefulWidget {
  const _OrderInfo({required this.order, required this.onCopy});

  final Order order;
  final void Function(String label, String value) onCopy;

  @override
  State<_OrderInfo> createState() => _OrderInfoState();
}

class _OrderInfoState extends State<_OrderInfo> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final cod = o.paymentMethod == 'cod';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Text('Order number', style: TextStyle(fontSize: 13.5, color: BColors.muted)),
        const Spacer(),
        Text(o.number, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: BColors.ink)),
        IconButton(
          tooltip: 'Copy order number',
          visualDensity: VisualDensity.compact,
          onPressed: () => widget.onCopy('Order number', o.number),
          icon: const Icon(Icons.copy_rounded, size: 17, color: BColors.ink),
        ),
      ]),
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: cod ? BColors.success : BColors.brand, borderRadius: BorderRadius.circular(6)),
              child: Text(cod ? 'COD' : (o.paymentMethod ?? 'PAY').toUpperCase(),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(paymentLabel(o.paymentMethod),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: BColors.ink))),
            const Text('Total  ', style: TextStyle(fontSize: 13.5, color: BColors.muted)),
            pesoText(o.total, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BColors.ink)),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(Icons.keyboard_arrow_down_rounded, color: BColors.faint),
            ),
          ]),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: !_open
            ? const SizedBox(width: double.infinity)
            : Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: BColors.background, borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  _kv('Merchandise subtotal', peso(o.subtotal)),
                  _kv('Shipping fee', peso(o.shippingFee)),
                  if (o.discount > 0) _kv('Voucher discount', '−${peso(o.discount)}', color: BColors.brand),
                  const Divider(height: 18, color: BColors.border),
                  _kv('Order time', formatDate(o.createdAt, withTime: true)),
                  if (o.receivedAt != null) _kv('Completed', formatDate(o.receivedAt, withTime: true)),
                  if (o.shippingCarrier != null) _kv('Carrier', o.shippingCarrier!),
                  if (o.trackingNumber != null)
                    InkWell(
                      onTap: () => widget.onCopy('Tracking number', o.trackingNumber!),
                      child: _kv('Tracking no.', o.trackingNumber!, trailing: const Icon(Icons.copy_rounded, size: 14, color: BColors.brand)),
                    ),
                ]),
              ),
      ),
    ]);
  }

  Widget _kv(String k, String v, {Color? color, Widget? trailing}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(k, style: const TextStyle(fontSize: 13, color: BColors.muted))),
          Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? BColors.ink)),
          if (trailing != null) ...[const SizedBox(width: 6), trailing],
        ]),
      );
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BColors.divider))),
          child: Row(children: [
            Icon(icon, size: 21, color: BColors.muted),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15, color: BColors.ink))),
            const Icon(Icons.chevron_right_rounded, color: BColors.faint),
          ]),
        ),
      );
}

// ============================================================
// Timeline sheet
// ============================================================

class _TimelineSheet extends StatelessWidget {
  const _TimelineSheet({required this.events});

  final List<StatusEvent> events;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: BColors.border, borderRadius: BorderRadius.circular(2))),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Align(
              alignment: Alignment.centerLeft, child: Text('Order timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BColors.ink))),
        ),
        Expanded(child: OrderTimelineList(events: events, controller: controller)),
      ]),
    );
  }
}

// ============================================================
// Bottom bar
// ============================================================

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.order, required this.busy, required this.onBuyAgain, required this.onUpdated});

  final Order order;
  final bool busy;
  final VoidCallback onBuyAgain;
  final ValueChanged<Order> onUpdated;

  List<Widget> _buttons(BuildContext context) {
    final o = order;
    Widget buyAgain({required bool primary}) => _BarButton(label: 'Buy again', primary: primary, busy: busy, onTap: onBuyAgain);
    if (o.awaitingReceipt) {
      return [buyAgain(primary: false), OrderActionButtons(order: o, expand: true, onUpdated: onUpdated)];
    }
    if (o.status == OrderStatus.delivered || o.status == OrderStatus.cancelled || o.returnState != null) {
      return [buyAgain(primary: true)];
    }
    final chatSeller =
        o.sellerId == null ? null : _BarButton(label: 'Contact seller', onTap: () => openSellerChat(context, sellerId: o.sellerId!, orderNumber: o.number));
    if (o.canCancel) return [if (chatSeller != null) chatSeller, OrderActionButtons(order: o, expand: true, onUpdated: onUpdated)];
    if (o.status == OrderStatus.inTransit && o.courierName != null) {
      return [if (chatSeller != null) chatSeller, _BarButton(label: 'Message courier', primary: true, onTap: () => openCourierChat(context, o.number))];
    }
    return [if (chatSeller != null) chatSeller];
  }

  bool get isEmpty => order.status == OrderStatus.processing && order.sellerId == null;

  @override
  Widget build(BuildContext context) {
    final buttons = _buttons(context);
    return Container(
      decoration: BoxDecoration(
        color: BColors.surface,
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SafeArea(
        top: false,
        child: Row(children: [
          for (var i = 0; i < buttons.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: buttons[i])],
        ]),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.label, required this.onTap, this.primary = false, this.busy = false});

  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) => Material(
        color: primary ? BColors.brand : BColors.background,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: busy ? null : onTap,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 48,
            child: Center(
              child: busy
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primary ? Colors.white : BColors.brand))
                  : Text(label, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: primary ? Colors.white : BColors.ink)),
            ),
          ),
        ),
      );
}
