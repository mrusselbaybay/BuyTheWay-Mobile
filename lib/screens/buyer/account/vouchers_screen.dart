import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../driver/driver_theme.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../cart/cart_screen.dart';
import '../catalog/product_list_screen.dart';
import '../catalog/store_screen.dart';
import '../product/product_detail_screen.dart';
import '../widgets/buyer_widgets.dart';
import 'settings_kit.dart';

const _tint = DriverColors.primarySurface;

bool _isActive(Coupon c) => c.status != 'used' && c.status != 'expired';

/// How the wallet is grouped: shipping vouchers, store (seller) discounts,
/// and BuyTheWay (platform) discounts.
enum _Group {
  shipping('Shipping', Icons.local_shipping_rounded),
  store('Store', Icons.storefront_rounded),
  platform('BuyTheWay', Icons.verified_rounded);

  const _Group(this.label, this.icon);
  final String label;
  final IconData icon;

  static _Group of(Coupon c) => c.isShipping ? shipping : (c.isPlatform ? platform : store);
}

/// Claimed voucher wallet: active vouchers by group. Used / expired ones
/// live in the history screen.
class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> with SingleTickerProviderStateMixin {
  final store = BuyerStore.instance;
  late final TabController tabs = TabController(length: 1 + _Group.values.length, vsync: this);
  List<Coupon>? wallet;
  double saved = 0;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final (list, total) = await store.api.voucherWallet();
      if (mounted) {
        setState(() {
          wallet = list;
          saved = total;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = store.handleError(e));
    }
  }

  void _openHistory({int tab = 0}) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _VoucherHistoryScreen(initialTab: tab)));

  Widget _cartButton() => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final count = store.cartCount;
          return Semantics(
            button: true,
            label: count > 0 ? 'Cart, $count items' : 'Cart',
            excludeSemantics: true,
            child: InkResponse(
              radius: 26,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen(standalone: true))),
              child: SizedBox(
                width: 52,
                height: 48,
                child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                  const Icon(Icons.shopping_cart_outlined, size: 28, color: DriverColors.textPrimary),
                  if (count > 0)
                    Positioned(
                      top: 2,
                      right: 0,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(10), border: Border.all(color: _tint, width: 1.5)),
                        child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, height: 1)),
                      ),
                    ),
                ]),
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final all = wallet;
    final active = all?.where(_isActive).toList() ?? const <Coupon>[];
    List<Coupon> inGroup(_Group g) => active.where((c) => _Group.of(c) == g).toList();
    final usedCount = all?.where((c) => c.status == 'used').length ?? 0;

    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: settingsAppBar(
        'My Vouchers',
        centerTitle: true,
        backgroundColor: _tint,
        actions: [
          _cartButton(),
          IconButton(tooltip: 'Voucher history', onPressed: _openHistory, icon: const Icon(Icons.history_rounded, size: 26, color: DriverColors.textPrimary)),
          const SizedBox(width: 2),
        ],
      ),
      body: all == null
          ? (error != null ? ErrorState(message: error!, onRetry: _load) : const Padding(padding: EdgeInsets.all(16), child: RowsSkeleton(count: 3, tile: 56)))
          : Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_tint, DriverColors.background])),
                child: _SummaryCard(saved: saved, active: active.length, used: usedCount, onActive: () => tabs.animateTo(0), onUsed: () => _openHistory(tab: 0)),
              ),
              Material(
                color: Colors.white,
                child: TabBar(
                  controller: tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: DriverColors.primary,
                  unselectedLabelColor: DriverColors.textSecondary,
                  indicatorColor: DriverColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  tabs: [
                    Tab(text: 'All (${active.length})'),
                    for (final g in _Group.values) Tab(text: '${g.label} (${inGroup(g).length})'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(controller: tabs, children: [
                  _AllTab(active: active, onRefresh: _load),
                  for (final g in _Group.values) _TicketList(coupons: inGroup(g), state: 'Available', onRefresh: _load, emptyTitle: 'No ${g.label.toLowerCase()} vouchers', emptyMessage: _emptyMessage(g)),
                ]),
              ),
            ]),
    );
  }

  static String _emptyMessage(_Group g) => switch (g) {
        _Group.shipping => 'Claim free-shipping vouchers on product pages.',
        _Group.store => 'Claim shop and product vouchers from product pages.',
        _Group.platform => 'BuyTheWay vouchers you claim will show up here.',
      };
}

// ---------------------------------------------------------------
// Summary
// ---------------------------------------------------------------

/// "You saved ₱X | N Active | N Used" summary.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.saved, required this.active, required this.used, required this.onActive, required this.onUsed});

  final double saved;
  final int active;
  final int used;
  final VoidCallback onActive;
  final VoidCallback onUsed;

  static const _red = DriverColors.primaryDark;

  Widget _stat(String value, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _red, height: 1.1)),
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: DriverText.caption.copyWith(fontSize: 12.5)),
              const Icon(Icons.chevron_right_rounded, size: 15, color: DriverColors.textSecondary),
            ]),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: softShadow(0.08)),
        child: IntrinsicHeight(
          child: Row(children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('You saved', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DriverColors.textPrimary)),
                  const SizedBox(height: 3),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(peso(saved), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _red, height: 1.1))),
                ]),
              ),
            ),
            const VerticalDivider(width: 12, thickness: 1, color: DriverColors.border),
            Expanded(flex: 3, child: Center(child: _stat('$active', 'Active', onActive))),
            const VerticalDivider(width: 12, thickness: 1, color: DriverColors.border),
            Expanded(flex: 3, child: Center(child: _stat('$used', 'Used', onUsed))),
          ]),
        ),
      );
}

// ---------------------------------------------------------------
// Lists
// ---------------------------------------------------------------

class _TicketList extends StatelessWidget {
  const _TicketList({required this.coupons, required this.state, required this.onRefresh, required this.emptyTitle, this.emptyMessage});

  final List<Coupon> coupons;
  final String state; // Available | Used | Expired
  final Future<void> Function() onRefresh;
  final String emptyTitle;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final list = _sorted(coupons, state);
    return RefreshIndicator(
      color: DriverColors.primary,
      onRefresh: onRefresh,
      child: list.isEmpty
          ? ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
              EmptyCard(icon: Icons.confirmation_number_outlined, title: emptyTitle, message: emptyMessage),
            ])
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) => _VoucherTicket(coupon: list[i], tab: state),
            ),
    );
  }
}

List<Coupon> _sorted(List<Coupon> coupons, String state) {
  final list = [...coupons];
  final far = DateTime.fromMillisecondsSinceEpoch(8640000000000000, isUtc: true);
  if (state == 'Available') {
    list.sort((a, b) => (a.expiresAt ?? far).compareTo(b.expiresAt ?? far));
  } else {
    list.sort((a, b) => (b.expiresAt ?? far).compareTo(a.expiresAt ?? far));
  }
  return list;
}

/// "All" tab: each group shows two vouchers, with See n more / Show less.
class _AllTab extends StatefulWidget {
  const _AllTab({required this.active, required this.onRefresh});

  final List<Coupon> active;
  final Future<void> Function() onRefresh;

  @override
  State<_AllTab> createState() => _AllTabState();
}

class _AllTabState extends State<_AllTab> {
  static const _preview = 2;
  final expanded = <_Group>{};

  Widget _section(_Group group, List<Coupon> coupons) {
    final open = expanded.contains(group);
    final list = _sorted(coupons, 'Available');
    final shown = open ? list : list.take(_preview).toList();
    final hidden = list.length - _preview;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(children: [
            IconTile(group.icon, size: 28),
            const SizedBox(width: 10),
            Text('${group.label} (${list.length})', style: DriverText.sectionTitle),
          ]),
        ),
        for (final c in shown) Padding(padding: const EdgeInsets.only(bottom: 14), child: _VoucherTicket(coupon: c, tab: 'Available')),
        if (hidden > 0)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => open ? expanded.remove(group) : expanded.add(group)),
              icon: Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
              label: Text(open ? 'Show less' : 'See $hidden more', style: const TextStyle(fontWeight: FontWeight.w800)),
              style: TextButton.styleFrom(foregroundColor: DriverColors.primary, minimumSize: const Size(0, 40)),
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = [
      for (final g in _Group.values)
        if (widget.active.any((c) => _Group.of(c) == g)) _section(g, widget.active.where((c) => _Group.of(c) == g).toList()),
    ];
    return RefreshIndicator(
      color: DriverColors.primary,
      onRefresh: widget.onRefresh,
      child: sections.isEmpty
          ? ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: const [
              EmptyCard(icon: Icons.confirmation_number_outlined, title: 'No vouchers yet', message: 'Look for voucher cards on product pages and tap Claim — they apply automatically at checkout.'),
            ])
          : ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), children: sections),
    );
  }
}

// ---------------------------------------------------------------
// History (used + expired)
// ---------------------------------------------------------------

class _VoucherHistoryScreen extends StatefulWidget {
  const _VoucherHistoryScreen({this.initialTab = 0});
  final int initialTab;

  @override
  State<_VoucherHistoryScreen> createState() => _VoucherHistoryScreenState();
}

class _VoucherHistoryScreenState extends State<_VoucherHistoryScreen> {
  final store = BuyerStore.instance;
  List<Coupon>? wallet;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final (list, _) = await store.api.voucherWallet();
      if (mounted) setState(() => wallet = list);
    } catch (e) {
      if (mounted) setState(() => error = store.handleError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = wallet;
    List<Coupon> by(String status) => all?.where((c) => c.status == status).toList() ?? const [];
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: DriverColors.background,
        appBar: settingsAppBar(
          'Voucher history',
          centerTitle: true,
          bottom: TabBar(
            labelColor: DriverColors.primary,
            unselectedLabelColor: DriverColors.textSecondary,
            indicatorColor: DriverColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            tabs: [Tab(text: 'Used (${by('used').length})'), Tab(text: 'Expired (${by('expired').length})')],
          ),
        ),
        body: all == null
            ? (error != null ? ErrorState(message: error!, onRetry: _load) : const Padding(padding: EdgeInsets.all(16), child: RowsSkeleton(count: 3, tile: 56)))
            : TabBarView(children: [
                _TicketList(coupons: by('used'), state: 'Used', onRefresh: _load, emptyTitle: 'No used vouchers', emptyMessage: 'Vouchers you redeem at checkout will be listed here.'),
                _TicketList(coupons: by('expired'), state: 'Expired', onRefresh: _load, emptyTitle: 'No expired vouchers', emptyMessage: 'Vouchers that end before you use them will be listed here.'),
              ]),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Ticket: coloured stub | dashed seam with punched notches | details
// (same look as the web voucher cards — red for discounts, teal for
// shipping, grey once used / expired).
// ---------------------------------------------------------------

const double _stubWidth = 88;
const double _notchRadius = 8;

Path _ticketPath(Size size) {
  final body = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)));
  final notches = Path()
    ..addOval(Rect.fromCircle(center: const Offset(_stubWidth, 0), radius: _notchRadius))
    ..addOval(Rect.fromCircle(center: Offset(_stubWidth, size.height), radius: _notchRadius));
  return Path.combine(PathOperation.difference, body, notches);
}

class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper();
  @override
  Path getClip(Size size) => _ticketPath(size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _TicketPainter extends CustomPainter {
  const _TicketPainter({required this.stubColor, required this.borderColor});
  final Color stubColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _ticketPath(size);
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(Rect.fromLTWH(0, 0, _stubWidth, size.height), Paint()..color = stubColor);
    canvas.restore();
    // Dashed seam between the notches.
    final seam = Path()
      ..moveTo(_stubWidth, _notchRadius + 4)
      ..lineTo(_stubWidth, size.height - _notchRadius - 4);
    final dash = Paint()
      ..color = borderColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (final PathMetric metric in seam.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, (d + 4).clamp(0, metric.length)), dash);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(covariant _TicketPainter old) => old.stubColor != stubColor || old.borderColor != borderColor;
}

class _VoucherTicket extends StatelessWidget {
  const _VoucherTicket({required this.coupon, required this.tab});

  final Coupon coupon;
  final String tab; // Available | Used | Expired

  bool get _active => tab == 'Available';

  String get _headline {
    if (coupon.isShipping && coupon.discountType == 'percentage' && (coupon.discountValue ?? 0) >= 100) return 'Free';
    final v = coupon.discountValue ?? 0;
    final text = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return coupon.discountType == 'percentage' ? '$text%' : '₱$text';
  }

  String get _subhead => coupon.isShipping ? 'SHIPPING' : 'OFF';

  /// What it covers: a product (+N more), a category, the whole shop, or the whole platform.
  String get _coverage {
    if (coupon.scope == 'product') {
      final more = coupon.productsCount > 1 ? ' +${coupon.productsCount - 1} more' : '';
      return '${coupon.productName ?? 'Selected products'}$more';
    }
    if (coupon.scope == 'category') return coupon.categories.isEmpty ? 'Selected categories' : coupon.categories.join(', ');
    if (coupon.isPlatform) return 'All items on BuyTheWay';
    return 'All items in ${coupon.shopName ?? 'this shop'}';
  }

  String get _conditions {
    final parts = <String>[
      coupon.minSpend > 0 ? 'Min. spend ${pesoCompact(coupon.minSpend)}' : 'No minimum spend',
      if (coupon.discountType == 'percentage' && coupon.maxDiscount != null && !coupon.isShipping) 'Up to ${pesoCompact(coupon.maxDiscount!)} off',
      if (!coupon.stackable) 'Can\'t combine',
    ];
    return parts.join(' · ');
  }

  bool get _canUse => _active && !coupon.autoApplied && (coupon.sellerId != null || coupon.productId != null || coupon.isPlatform);

  void _use(BuildContext context) {
    final nav = Navigator.of(context);
    if (coupon.scope == 'product' && coupon.productId != null) {
      nav.push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: coupon.productId!)));
    } else if (coupon.isPlatform) {
      final category = coupon.categories.length == 1 ? coupon.categories.first : null;
      nav.push(MaterialPageRoute(builder: (_) => ProductListScreen(title: category ?? 'BuyTheWay deals', category: category)));
    } else if (coupon.sellerId != null) {
      nav.push(MaterialPageRoute(builder: (_) => StoreScreen(storeId: coupon.sellerId!, name: coupon.shopName)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = !_active;
    final accent = muted ? DriverColors.textSecondary : (coupon.isShipping ? const Color(0xFF0F766E) : const Color(0xFFDC2626));
    final soft = muted ? const Color(0xFFF1F5F9) : (coupon.isShipping ? const Color(0xFFF0FDFA) : const Color(0xFFFEF2F2));
    final line = muted ? DriverColors.border : (coupon.isShipping ? const Color(0xFF99F6E4) : const Color(0xFFFECACA));
    final lowNow = _active && coupon.runningLow;
    final expiry = coupon.expiresAt;

    return Opacity(
      opacity: muted ? 0.85 : 1,
      child: CustomPaint(
        painter: _TicketPainter(stubColor: soft, borderColor: line),
        child: ClipPath(
          clipper: const _TicketClipper(),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: _stubWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(coupon.isShipping ? Icons.local_shipping_rounded : Icons.sell_rounded, size: 18, color: accent),
                    const SizedBox(height: 6),
                    FittedBox(fit: BoxFit.scaleDown, child: Text(_headline, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1, letterSpacing: -0.5, color: accent))),
                    const SizedBox(height: 4),
                    Text(_subhead, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: accent)),
                  ]),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(coupon.isPlatform ? Icons.verified_rounded : Icons.storefront_rounded, size: 14, color: muted ? DriverColors.textSecondary : DriverColors.primary),
                      const SizedBox(width: 5),
                      Expanded(child: Text(coupon.shopName ?? 'Shop', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: DriverColors.textPrimary))),
                      if (lowNow) _Tag('${coupon.remaining ?? ''} left'.trim(), const Color(0xFFC2410C), const Color(0xFFFFF7ED)),
                      if (muted) _Tag(tab, DriverColors.textSecondary, const Color(0xFFE2E8F0)),
                    ]),
                    const SizedBox(height: 6),
                    Text(_coverage, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.25, color: muted ? DriverColors.textSecondary : DriverColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(_conditions, style: DriverText.caption.copyWith(fontSize: 12, height: 1.3)),
                    const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                        child: Row(children: [
                          Icon(Icons.schedule_rounded, size: 13, color: lowNow ? const Color(0xFFC2410C) : DriverColors.textSecondary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              expiry == null ? 'No expiry' : (_active ? 'Valid till ${formatDate(expiry)}' : 'Ended ${formatDate(expiry)}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: lowNow ? const Color(0xFFC2410C) : DriverColors.textSecondary),
                            ),
                          ),
                        ]),
                      ),
                      if (_active && coupon.autoApplied) ...[
                        const SizedBox(width: 8),
                        const _Tag('Auto-applied', Color(0xFF0F766E), Color(0xFFF0FDFA)),
                      ],
                      if (_canUse) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 36,
                          child: FilledButton(
                            onPressed: () => _use(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(72, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                            child: const Text('Use'),
                          ),
                        ),
                      ],
                    ]),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color, this.background);
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
      );
}
