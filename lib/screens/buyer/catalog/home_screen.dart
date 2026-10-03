import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../buyer_models.dart';
import '../buyer_shell.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../orders/order_detail_screen.dart';
import '../product/product_detail_screen.dart';
import '../widgets/buyer_widgets.dart';
import '../widgets/product_pager.dart';
import 'categories_screen.dart';
import 'product_list_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final pager = ProductPager();
  final store = BuyerStore.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    pager.loadMore();
  }

  @override
  void dispose() {
    pager.dispose();
    super.dispose();
  }

  Future<void> _refresh() => Future.wait([pager.refresh(), store.loadOrders()]);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final media = MediaQuery.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: BColors.background,
        body: ListenableBuilder(
          listenable: pager,
          builder: (context, _) {
            final deals = pager.products.where((p) => p.discountPercent > 0 && !p.isSoldOut).take(12).toList();
            return RefreshIndicator(
              color: BColors.brand,
              edgeOffset: media.padding.top + _HomeHeader.collapsedHeight,
              onRefresh: _refresh,
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) => handleNearEnd(n, pager.loadMore),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPersistentHeader(pinned: true, delegate: _HomeHeader(topPadding: media.padding.top)),
                    const SliverToBoxAdapter(child: _ActiveOrderCard()),
                    const SliverToBoxAdapter(child: _HeroBanner()),
                    const SliverToBoxAdapter(child: _CategoryRail()),
                    if (deals.length >= 2) SliverToBoxAdapter(child: _DealsSection(deals: deals)),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: _SectionTitle(title: 'New Arrivals', subtitle: 'Fresh from local sellers'),
                      ),
                    ),
                    ...productGridSlivers(
                      context,
                      pager,
                      empty: const EmptyState(
                        icon: Icons.storefront_outlined,
                        title: 'No products yet',
                        message: 'Sellers are still stocking up. Pull down to check again.',
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: media.padding.bottom + 8)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// Header
// ============================================================

/// Pinned top bar: pill search + Cart and Messages shortcuts.
class _HomeHeader extends SliverPersistentHeaderDelegate {
  _HomeHeader({required this.topPadding});

  static const double collapsedHeight = 68;

  final double topPadding;

  @override
  double get maxExtent => topPadding + collapsedHeight;

  @override
  double get minExtent => maxExtent;

  @override
  bool shouldRebuild(covariant _HomeHeader oldDelegate) => oldDelegate.topPadding != topPadding;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final store = BuyerStore.instance;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BColors.background,
        boxShadow: overlapsContent || shrinkOffset > 0
            ? [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topPadding + 10, 12, 10),
        child: Row(children: [
          Expanded(
            child: SearchBox(
              elevated: true,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
            ),
          ),
          const SizedBox(width: 6),
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              _HeaderIconButton(
                icon: Icons.shopping_bag_outlined,
                tooltip: store.cartCount > 0 ? 'Cart, ${store.cartCount} items' : 'Cart',
                badge: store.cartCount,
                onTap: () => BuyerShell.tab.value = 2,
              ),
              _HeaderIconButton(
                icon: Icons.chat_bubble_outline_rounded,
                tooltip: store.chatUnread > 0 ? 'Messages, ${store.chatUnread} unread' : 'Messages',
                badge: store.chatUnread,
                onTap: () => BuyerShell.tab.value = 3,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.tooltip, required this.onTap, this.badge = 0});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(fixedSize: const Size(44, 44)),
        icon: Badge(
          isLabelVisible: badge > 0,
          label: Text(badge > 99 ? '99+' : '$badge'),
          backgroundColor: BColors.cta,
          child: Icon(icon, color: BColors.ink, size: 22),
        ),
      );
}

/// Tap-to-search field (opens [SearchScreen]) — the persistent search bar
/// shoppers expect at the top of every commerce home screen.
class SearchBox extends StatelessWidget {
  const SearchBox({super.key, required this.onTap, this.text, this.elevated = false});

  final VoidCallback onTap;
  final String? text;

  /// Taller, softly shadowed variant for light backgrounds.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(elevated ? 24 : 12);
    return Semantics(
      button: true,
      label: text == null ? 'Search products' : 'Search: $text',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        elevation: elevated ? 3 : 0,
        shadowColor: const Color(0x260F172A),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: elevated ? 48 : 44,
            child: Row(children: [
              SizedBox(width: elevated ? 16 : 12),
              const Icon(Icons.search_rounded, color: BColors.brand, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text ?? 'Search products, brands, shops',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 14, color: text == null ? BColors.faint : BColors.ink, fontWeight: text == null ? FontWeight.w400 : FontWeight.w600),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Active order
// ============================================================

/// The order that needs the buyer's attention right now (to confirm,
/// arriving, being packed) — so Home answers "where's my stuff?" first.
class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard();

  static int _rank(Order o) {
    if (o.awaitingReceipt) return 0;
    if (o.status == OrderStatus.inTransit) return 1;
    if (o.status == OrderStatus.processing) return 2;
    if (o.status == OrderStatus.toShip) return 3;
    return 9;
  }

  @override
  Widget build(BuildContext context) {
    final store = BuyerStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final active = store.orders.where((o) => o.returnState == null && _rank(o) < 9).toList()..sort((a, b) => _rank(a).compareTo(_rank(b)));
        if (active.isEmpty) return const SizedBox.shrink();
        final o = active.first;
        final (icon, title, accent) = switch (_rank(o)) {
          0 => (Icons.markunread_mailbox_rounded, 'Delivered — confirm receipt', BColors.cta),
          1 => (Icons.local_shipping_rounded, 'Your order is on the way', BColors.brand),
          2 => (Icons.inventory_rounded, 'Seller is packing your order', BColors.brand),
          _ => (Icons.receipt_long_rounded, 'Order placed', BColors.brand),
        };
        final live = _rank(o) == 1 && !MediaQuery.disableAnimationsOf(context);

        Widget dot = Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle));
        if (live) dot = dot.animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 1, end: 0.25, duration: 900.ms);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(BRadius.tile), boxShadow: softShadow(0.05)),
            child: Material(
              color: BColors.surface,
              borderRadius: BorderRadius.circular(BRadius.tile),
              child: InkWell(
                borderRadius: BorderRadius.circular(BRadius.tile),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o)));
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                      child: Icon(icon, color: accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          dot,
                          const SizedBox(width: 6),
                          Flexible(
                              child:
                                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
                        ]),
                        const SizedBox(height: 3),
                        Text(
                          '${o.seller} · ${o.itemCount} ${o.itemCount == 1 ? 'item' : 'items'} · ${peso(o.total)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BText.small,
                        ),
                        if (active.length > 1) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => BuyerShell.tab.value = 1,
                            child: Text('+${active.length - 1} more active ${active.length == 2 ? 'order' : 'orders'}',
                                style: const TextStyle(fontSize: 12, color: BColors.brand, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: BColors.faint),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// Hero
// ============================================================

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Material(
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]),
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
            child: SizedBox(
              height: 148,
              child: Stack(children: [
                // Soft decorative circles — depth without imagery.
                const Positioned(right: -38, top: -46, child: _Circle(size: 170, alpha: 0.10)),
                const Positioned(right: 40, bottom: -70, child: _Circle(size: 130, alpha: 0.08)),
                const Positioned(right: 18, bottom: 16, child: Icon(Icons.shopping_bag_rounded, size: 72, color: Color(0x33FFFFFF))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 110, 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                      child: const Text('SHOP LOCAL', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Discover finds from sellers near you',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 18, height: 1.25, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                    ),
                    const Spacer(),
                    const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Browse categories', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 17),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
      );
}

// ============================================================
// Categories
// ============================================================

/// One scrollable rail — lighter than a boxed grid and keeps the product
/// feed closer to the fold.
class _CategoryRail extends StatelessWidget {
  const _CategoryRail();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 10, 8),
        child: _SectionTitle(
          title: 'Categories',
          actionLabel: 'See all',
          onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
        ),
      ),
      SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: kCategories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 2),
          itemBuilder: (context, i) {
            final c = kCategories[i];
            final accent = categoryAccent(c);
            return Semantics(
              button: true,
              label: c,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductListScreen(title: c, category: c)));
                },
                child: SizedBox(
                  width: 76,
                  child: Column(children: [
                    const SizedBox(height: 2),
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(color: accent.withValues(alpha: 0.11), shape: BoxShape.circle),
                      child: Icon(categoryIcon(c), color: accent, size: 26),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      categoryShortLabel(c),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: BColors.ink),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ============================================================
// Deals
// ============================================================

/// Real markdowns only (compare_price > price) — no invented countdowns.
class _DealsSection extends StatelessWidget {
  const _DealsSection({required this.deals});

  final List<Product> deals;

  @override
  Widget build(BuildContext context) {
    final best = deals.map((d) => d.discountPercent).reduce((a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Row(children: [
          const Icon(Icons.local_fire_department_rounded, color: BColors.cta, size: 20),
          const SizedBox(width: 6),
          const Text('On Sale', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: BColors.ink, letterSpacing: -0.2)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: BColors.ctaSurface, borderRadius: BorderRadius.circular(20)),
            child: Text('Up to $best% off', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: BColors.cta)),
          ),
        ]),
      ),
      SizedBox(
        height: 186,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: deals.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => _DealTile(product: deals[i]),
        ),
      ),
    ]);
  }
}

class _DealTile extends StatelessWidget {
  const _DealTile({required this.product});

  static const double _size = 128;

  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Semantics(
      button: true,
      label: '${p.name}, ${pesoCompact(p.price)}, ${p.discountPercent}% off',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => openProduct(context, p),
        borderRadius: BorderRadius.circular(BRadius.tile),
        child: SizedBox(
          width: _size,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(BRadius.tile),
              child: SizedBox(
                width: _size,
                height: _size,
                child: Stack(fit: StackFit.expand, children: [
                  NetImage(p.primaryImage, fallbackIcon: categoryIcon(p.category)),
                  Positioned(top: 8, left: 8, child: DiscountRibbon(p.discountPercent)),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: BColors.ink)),
                const SizedBox(height: 3),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(pesoCompact(p.price), maxLines: 1, style: const TextStyle(fontSize: 15, height: 1.1, fontWeight: FontWeight.w800, color: BColors.cta)),
                  if (p.oldPrice != null) ...[
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        pesoCompact(p.oldPrice!),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: const TextStyle(fontSize: 11, color: BColors.faint, decoration: TextDecoration.lineThrough, decorationColor: BColors.faint),
                      ),
                    ),
                  ],
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ============================================================
// Shared
// ============================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle, this.actionLabel, this.onAction});

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: BColors.ink, letterSpacing: -0.2)),
            if (subtitle != null) ...[const SizedBox(height: 1), Text(subtitle!, style: BText.tiny)],
          ]),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: BColors.brand,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(44, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(actionLabel!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ]),
          ),
      ]);
}
