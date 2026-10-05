import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buyer_models.dart';
import '../buyer_shell.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../chat/chat_thread_screen.dart';
import '../widgets/buyer_widgets.dart';
import 'order_actions.dart';
import 'order_detail_screen.dart';
import 'return_request_screen.dart';

/// (tab label, filter). Status tabs filter on the raw order status, the
/// return tab on returnState — same split as the web Orders page.
final List<(String, bool Function(Order))> orderTabs = [
  ('All', (_) => true),
  ('To Ship', (o) => o.status == OrderStatus.toShip),
  ('Processing', (o) => o.status == OrderStatus.processing),
  ('To Receive', (o) => o.status == OrderStatus.inTransit),
  ('Completed', (o) => o.status == OrderStatus.delivered && o.returnState == null),
  ('Returns', (o) => o.returnState == 'to_return' || o.returnState == 'returned'),
  ('Cancelled', (o) => o.status == OrderStatus.cancelled),
];

String orderStatusLabel(Order o) {
  final s = o.displayStatus;
  if (s == OrderStatus.toShip) return 'To Ship';
  if (s == OrderStatus.delivered) return o.receivedAt == null ? 'Delivered' : 'Completed';
  return s;
}

/// Header status line ("Order delivered", "Order cancelled", …).
String _headline(Order o) {
  switch (o.displayStatus) {
    case OrderStatus.toShip:
      return 'Waiting for seller';
    case OrderStatus.processing:
      return 'Preparing';
    case OrderStatus.inTransit:
      return 'On the way';
    case OrderStatus.delivered:
      return o.receivedAt == null ? 'Order delivered' : 'Order completed';
    case OrderStatus.cancelled:
      return 'Order cancelled';
    case 'To Return':
      return 'Return in progress';
    case 'Returned':
      return 'Refunded';
    default:
      return o.displayStatus;
  }
}

/// `8:37 am`, or `Oct 3` when not today.
String _when(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  final now = DateTime.now();
  if (l.year == now.year && l.month == now.month && l.day == now.day) {
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    return '$h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'am' : 'pm'}';
  }
  return formatDate(l).replaceFirst(RegExp(', ${now.year}\$'), '');
}

// ============================================================
// Screen
// ============================================================

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final store = BuyerStore.instance;
  final _query = ValueNotifier<String>('');
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    store.loadOrders();
  }

  @override
  void dispose() {
    _query.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(Order o, String q) {
    if (q.isEmpty) return true;
    return o.seller.toLowerCase().contains(q) || o.orderId.toLowerCase().contains(q) || o.items.any((i) => i.name.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    // Embedded as the Orders tab (no back arrow); pushed from Account's
    // status shortcuts otherwise.
    final pushed = Navigator.of(context).canPop() && !(ModalRoute.of(context)?.isFirst ?? true);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: DefaultTabController(
        length: orderTabs.length,
        initialIndex: widget.initialTab.clamp(0, orderTabs.length - 1),
        child: Scaffold(
          backgroundColor: BColors.background,
          body: Column(children: [
            ColoredBox(
              color: BColors.surface,
              child: SafeArea(
                bottom: false,
                child: Column(children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(pushed ? 4 : 16, 10, 16, 6),
                    child: Row(children: [
                      if (pushed)
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: BColors.ink),
                        ),
                      Expanded(child: _OrderSearchField(controller: _searchCtrl, onChanged: (v) => _query.value = v.trim().toLowerCase())),
                    ]),
                  ),
                  const _StatusTabBar(),
                ]),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([store, _query]),
                builder: (context, _) => TabBarView(
                  children: [
                    for (final (_, filter) in orderTabs) _OrderList(filter: (o) => filter(o) && _matches(o, _query.value), searching: _query.value.isNotEmpty),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _OrderSearchField extends StatelessWidget {
  const _OrderSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 14.5, color: BColors.ink),
          decoration: InputDecoration(
            hintText: 'Search your orders',
            hintStyle: const TextStyle(fontSize: 14.5, color: BColors.faint),
            prefixIcon: const Icon(Icons.search_rounded, color: BColors.brand, size: 20),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, v, __) => v.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded, size: 18, color: BColors.muted),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
            ),
            filled: true,
            fillColor: BColors.brandSurface,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          ),
        ),
      );
}

class _StatusTabBar extends StatelessWidget {
  const _StatusTabBar();

  @override
  Widget build(BuildContext context) => TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        labelColor: BColors.brand,
        unselectedLabelColor: BColors.muted,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: BColors.brand, width: 2),
          borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: BColors.divider,
        tabs: [for (final (label, _) in orderTabs) Tab(height: 46, text: label)],
      );
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.filter, required this.searching});

  final bool Function(Order) filter;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final store = BuyerStore.instance;
    final bottom = MediaQuery.paddingOf(context).bottom + 16;

    if (!store.ordersLoaded && store.loadingOrders) {
      return ListView.separated(
        padding: EdgeInsets.only(top: 12, bottom: bottom),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _OrderCardSkeleton(),
      );
    }

    final orders = store.orders.where(filter).toList();
    return RefreshIndicator(
      color: BColors.brand,
      onRefresh: store.loadOrders,
      child: orders.isEmpty
          ? ListView(children: [
              SizedBox(
                height: 420,
                child: store.ordersError != null && !store.ordersLoaded
                    ? ErrorState(message: store.ordersError!, onRetry: store.loadOrders)
                    : searching
                        ? const EmptyState(icon: Icons.search_off_rounded, title: 'No matching orders', message: 'Try a product or shop name.')
                        : EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Nothing here yet',
                            message: 'Orders you place will appear here.',
                            actionLabel: 'Start shopping',
                            onAction: () => BuyerShell.goTo(context, 0),
                          ),
              ),
            ])
          : ListView.separated(
              padding: EdgeInsets.only(top: 12, bottom: bottom),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => OrderCard(order: orders[i]),
            ),
    );
  }
}

// ============================================================
// Status tone
// ============================================================

/// One colour + icon per state, shared by the status pill, tracking
/// badge and refund strip so a card reads as a single colour story.
({Color color, IconData icon}) _tone(Order o) {
  switch (o.displayStatus) {
    case OrderStatus.toShip:
      return (color: BColors.brand, icon: Icons.inventory_2_rounded);
    case OrderStatus.processing:
      return (color: BColors.brand, icon: Icons.inventory_rounded);
    case OrderStatus.inTransit:
      return (color: BColors.brand, icon: Icons.local_shipping_rounded);
    case OrderStatus.delivered:
      return (color: BColors.success, icon: o.receivedAt == null ? Icons.markunread_mailbox_rounded : Icons.check_circle_rounded);
    case OrderStatus.cancelled:
      return (color: BColors.muted, icon: Icons.cancel_rounded);
    case 'To Return':
      return (color: BColors.warning, icon: Icons.assignment_return_rounded);
    case 'Returned':
      return (color: BColors.success, icon: Icons.assignment_turned_in_rounded);
    default:
      return (color: BColors.brand, icon: Icons.receipt_long_rounded);
  }
}

/// Fixed-height status chip so every state ("On the way", "Order
/// completed", …) sits on the same baseline as the shop name.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final c = _tone(order).color;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(13)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(_headline(order), style: TextStyle(fontSize: 12, height: 1, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }
}

// ============================================================
// Card
// ============================================================

/// One order: shop + status, a tracking strip, its items, the total and
/// the actions that fit its state.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});

  final Order order;

  void _open(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)));

  @override
  Widget build(BuildContext context) {
    final o = order;
    final returned = o.returnState != null;
    final count = o.itemCount;
    final extra = o.items.length - 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: softShadow(0.05)),
        child: Material(
          color: BColors.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.storefront_rounded, size: 16, color: BColors.brand),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(children: [
                      Flexible(
                        child: Text(o.seller,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: BColors.ink)),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: BColors.faint),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(order: o),
                ]),
                const SizedBox(height: 12),
                if (returned) _RefundStrip(order: o, onTap: () => _open(context)) else _TrackingStrip(order: o, onTap: () => _open(context)),
                const SizedBox(height: 14),
                for (final item in o.items.take(2)) _ItemRow(item: item),
                if (extra > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 76, bottom: 10),
                    child: Text('+$extra more ${extra == 1 ? 'item' : 'items'}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: BColors.brand)),
                  ),
                const Divider(height: 1, color: BColors.divider),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$count ${count == 1 ? 'item' : 'items'}', style: BText.small),
                  const Spacer(),
                  const Text('Total  ', style: TextStyle(fontSize: 13, color: BColors.muted)),
                  Text(peso(o.total),
                      style: const TextStyle(fontSize: 17, height: 1.1, fontWeight: FontWeight.w800, color: BColors.brand, letterSpacing: -0.2)),
                ]),
                const SizedBox(height: 14),
                _OrderActions(order: o),
                if (o.status == OrderStatus.delivered && !returned) ...[
                  const SizedBox(height: 12),
                  _QuickReview(item: o.items.first),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon badge + title/time + one line of copy, tinted with the status tone.
class _Strip extends StatelessWidget {
  const _Strip({required this.tone, required this.icon, required this.title, required this.onTap, this.trailing, this.subtitle});

  final Color tone;
  final IconData icon;
  final Widget title;
  final String? trailing;
  final Widget? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: tone.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: BColors.surface, shape: BoxShape.circle, boxShadow: softShadow(0.04)),
                child: Icon(icon, size: 18, color: tone),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                        child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: BColors.ink), child: title)),
                    if (trailing != null && trailing!.isNotEmpty)
                      Text(trailing!, style: const TextStyle(fontSize: 11.5, color: BColors.muted, fontWeight: FontWeight.w500)),
                  ]),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(style: const TextStyle(fontSize: 12.5, height: 1.3, color: BColors.muted), child: subtitle!),
                  ],
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: BColors.faint),
            ]),
          ),
        ),
      );
}

class _TrackingStrip extends StatelessWidget {
  const _TrackingStrip({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final last = o.history.isEmpty ? null : o.history.reduce((a, b) => (b.at?.isAfter(a.at ?? DateTime(0)) ?? false) ? b : a);
    final (title, sub) = switch (o.status) {
      OrderStatus.toShip => ('Order placed', 'Waiting for the seller to prepare it.'),
      OrderStatus.processing => ('Being packed', 'The seller is packing your parcel.'),
      OrderStatus.inTransit => ('In transit', o.courierName != null ? '${o.courierName} is delivering your parcel.' : 'Your parcel is on its way to you.'),
      OrderStatus.delivered => (
          'Delivered',
          o.receivedAt == null ? "Check your items, then confirm you've received them." : 'Your package has been delivered.'
        ),
      OrderStatus.cancelled => ('Delivery cancelled', 'This order was cancelled.'),
      _ => (o.status, last?.note ?? ''),
    };
    final tone = _tone(o);
    return _Strip(
      tone: tone.color,
      icon: tone.icon,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: _when(last?.at ?? o.createdAt),
      subtitle: sub.isEmpty ? null : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}

/// Return/refund outcome (third reference image).
class _RefundStrip extends StatelessWidget {
  const _RefundStrip({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = order.returnState == 'returned';
    final last = order.history.isEmpty ? null : order.history.last;
    final tone = _tone(order);
    return _Strip(
      tone: tone.color,
      icon: tone.icon,
      title: Text.rich(
        TextSpan(children: [
          TextSpan(text: done ? 'Refund completed  ' : 'Refund pending  '),
          TextSpan(text: peso(order.total), style: const TextStyle(color: BColors.brand, fontWeight: FontWeight.w800)),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: done && last?.at != null ? formatDate(last!.at) : null,
      subtitle: Text(done ? 'Returned to your original payment method.' : 'Refunded once the seller receives your return.',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final variation = item.variation ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: BColors.divider)),
          child: ClipRRect(borderRadius: BorderRadius.circular(13), child: NetImage(item.image, fallbackIcon: categoryIcon(item.category))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 64,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, height: 1.3, fontWeight: FontWeight.w500, color: BColors.ink)),
              const Spacer(),
              Row(children: [
                Expanded(
                  child: variation.isEmpty
                      ? const SizedBox.shrink()
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: BColors.divider, borderRadius: BorderRadius.circular(6)),
                            child: Text(variation, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: BColors.muted)),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Text('×${item.quantity}', style: const TextStyle(fontSize: 12.5, color: BColors.muted)),
                const SizedBox(width: 10),
                Text(peso(item.unitPrice), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: BColors.ink)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ============================================================
// Actions
// ============================================================

const double _kActionHeight = 40;

class _OrderActions extends StatefulWidget {
  const _OrderActions({required this.order});

  final Order order;

  @override
  State<_OrderActions> createState() => _OrderActionsState();
}

class _OrderActionsState extends State<_OrderActions> {
  final store = BuyerStore.instance;
  bool _busy = false;

  Order get o => widget.order;

  void _openDetail() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o)));

  Future<void> _reorder({required bool goToCart}) async {
    if (_busy) return;
    setState(() => _busy = true);
    await reorderItems(context, o.items, goToCart: goToCart);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _requestRefund() async {
    final eligible = o.items.where((i) => i.returnStatus == null).toList();
    if (eligible.isEmpty) {
      showToast(context, 'A return was already requested for this order.');
      return;
    }
    if (eligible.length > 1) {
      _openDetail();
      return;
    }
    final submitted = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ReturnRequestScreen(order: o, item: eligible.first)));
    if (submitted == true) store.loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final delivered = o.status == OrderStatus.delivered && o.returnState == null;
    final cart = _CartButton(busy: _busy, onTap: () => _reorder(goToCart: false));
    final buyAgain = _Pill(label: 'Buy again', primary: o.returnState == null, onTap: _busy ? null : () => _reorder(goToCart: true));

    final List<Widget> row;
    if (o.status == OrderStatus.toShip || o.status == OrderStatus.processing) {
      row = [
        if (o.canCancel) OrderActionButtons(order: o),
        _Pill(label: 'View details', onTap: _openDetail),
      ];
    } else if (o.status == OrderStatus.inTransit) {
      row = [
        if (o.courierName != null) _Pill(icon: Icons.chat_bubble_outline_rounded, label: 'Message', onTap: () => openCourierChat(context, o.number)),
        _Pill(icon: Icons.near_me_rounded, label: 'Track order', primary: true, onTap: _openDetail),
      ];
    } else if (delivered) {
      row = [_Pill(label: 'Request refund', onTap: _requestRefund), cart, buyAgain];
    } else {
      row = [cart, buyAgain];
    }

    final actions = Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      for (var i = 0; i < row.length; i++) ...[if (i > 0) const SizedBox(width: 8), row[i]],
    ]);
    if (!o.awaitingReceipt) return actions;
    // Confirming receipt is the one thing a delivered order needs next,
    // so it gets its own full-width row instead of crowding the three.
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      actions,
      const SizedBox(height: 10),
      OrderActionButtons(order: o, expand: true),
    ]);
  }
}

/// Action pill: outlined by default, solid teal when [primary].
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, this.primary = false, this.icon});

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : BColors.brand;
    return Material(
      color: primary ? BColors.brand : BColors.surface,
      shape: StadiumBorder(side: primary ? BorderSide.none : BorderSide(color: BColors.brand.withValues(alpha: 0.35))),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          height: _kActionHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg)),
          ]),
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Add to cart',
        child: Material(
          color: BColors.brandSurface,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: busy ? null : onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: _kActionHeight,
              height: _kActionHeight,
              child: Center(
                child: busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: BColors.brand))
                    : const Icon(Icons.add_shopping_cart_rounded, size: 19, color: BColors.brand),
              ),
            ),
          ),
        ),
      );
}

/// Quick star rating (UI only for now — not submitted).
class _QuickReview extends StatefulWidget {
  const _QuickReview({required this.item});

  final OrderItem item;

  @override
  State<_QuickReview> createState() => _QuickReviewState();
}

class _QuickReviewState extends State<_QuickReview> {
  late int _rating = widget.item.reviewRating ?? 0;

  static const _labels = ['Tap to rate', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Quick review', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: BColors.brandDark)),
              const SizedBox(height: 1),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Text(_labels[_rating], key: ValueKey(_rating), style: TextStyle(fontSize: 12, color: _rating > 0 ? BColors.warning : BColors.brand)),
              ),
            ]),
          ),
          for (var i = 1; i <= 5; i++)
            Semantics(
              button: true,
              label: '$i star${i == 1 ? '' : 's'}',
              selected: i <= _rating,
              excludeSemantics: true,
              child: InkResponse(
                radius: 20,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _rating = i);
                },
                child: SizedBox(
                  width: 36,
                  height: 40,
                  child: AnimatedScale(
                    scale: i <= _rating ? 1.08 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 27, color: i <= _rating ? BColors.star : BColors.faint),
                  ),
                ),
              ),
            ),
        ]),
      );
}

class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(20)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SkeletonBox(height: 28, width: 28, radius: 9),
              SizedBox(width: 8),
              SkeletonBox(height: 14, width: 120),
              Spacer(),
              SkeletonBox(height: 26, width: 92, radius: 13)
            ]),
            SizedBox(height: 12),
            SkeletonBox(height: 56, radius: 14),
            SizedBox(height: 14),
            Row(children: [SkeletonBox(height: 64, width: 64, radius: 14), SizedBox(width: 12), Expanded(child: SkeletonBox(height: 40))]),
            SizedBox(height: 14),
            Align(alignment: Alignment.centerRight, child: SkeletonBox(height: _kActionHeight, width: 210, radius: 20)),
          ]),
        ),
      );
}
