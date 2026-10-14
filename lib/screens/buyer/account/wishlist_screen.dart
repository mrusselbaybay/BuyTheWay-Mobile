import 'package:flutter/material.dart';

import '../../driver/driver_theme.dart';
import '../buyer_models.dart';
import '../buyer_shell.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../product/product_detail_screen.dart';
import '../widgets/buyer_widgets.dart';
import 'settings_kit.dart';

const _tint = DriverColors.primarySurface;
const _heartBg = Color(0xFFFFF1F2);
const _heart = Color(0xFFE11D48);

enum _Sort {
  recent('Recently added', Icons.schedule_rounded),
  priceLow('Price: low to high', Icons.trending_up_rounded),
  priceHigh('Price: high to low', Icons.trending_down_rounded);

  const _Sort(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// The wishlist API stores product ids only, so products are fetched in
/// parallel; removed / unavailable ones are dropped. Items are grouped by
/// category (no tabs), as a grid or a list, with an always-visible search
/// bar and sorting pinned above them.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final store = BuyerStore.instance;
  final searchController = TextEditingController();
  final Map<String, Product> products = {};
  bool loading = true;
  String? error;
  bool gridView = true;
  _Sort sort = _Sort.recent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await store.loadWishlist();
      final results = await Future.wait(store.favorites.map((id) => store.api.product(id).catchError((_) => null)));
      if (!mounted) return;
      setState(() {
        products
          ..clear()
          ..addEntries(results.whereType<Product>().map((p) => MapEntry(p.id, p)));
      });
    } catch (e) {
      if (mounted) setState(() => error = store.handleError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// Saved products, filtered by the search box and sorted. "Recently added"
  /// follows the order items were saved in (newest last in the set).
  List<Product> _visible() {
    final query = searchController.text.trim().toLowerCase();
    final order = store.favorites.toList();
    final list = products.values.where((p) {
      if (!store.isFavorite(p.id)) return false;
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) || (p.category ?? '').toLowerCase().contains(query) || p.seller.toLowerCase().contains(query) || (p.brand ?? '').toLowerCase().contains(query);
    }).toList();
    switch (sort) {
      case _Sort.recent:
        list.sort((a, b) => order.indexOf(b.id).compareTo(order.indexOf(a.id)));
      case _Sort.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
      case _Sort.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
    }
    return list;
  }

  /// Same canonical category order as the rest of the app, extras after.
  List<(String, List<Product>)> _grouped(List<Product> list) {
    final groups = <String, List<Product>>{};
    for (final p in list) {
      groups.putIfAbsent(p.category ?? 'Other', () => []).add(p);
    }
    final names = [...kCategories.where(groups.containsKey), ...(groups.keys.where((k) => !kCategories.contains(k)).toList()..sort())];
    return [for (final n in names) (n, groups[n]!)];
  }

  void _addToCart(Product p) {
    if (p.hasVariants) {
      openProduct(context, p);
      return;
    }
    final result = store.addToCart(p, null, 1);
    showToast(context, result.ok ? 'Added to cart' : result.message, error: !result.ok);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: settingsAppBar('Wishlist', centerTitle: true, backgroundColor: _tint),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final saved = products.values.where((p) => store.isFavorite(p.id)).length;
          if (loading && saved == 0) {
            return GridView.builder(
              padding: const EdgeInsets.all(kGridPadding),
              gridDelegate: productGridDelegate(context),
              itemCount: 4,
              itemBuilder: (_, __) => const ProductCardSkeleton(),
            );
          }
          if (error != null && saved == 0) return ErrorState(message: error!, onRetry: _load);
          if (saved == 0) {
            return EmptyState(
              icon: Icons.favorite_border,
              title: 'Your wishlist is empty',
              message: 'Tap the heart on any product to save it here.',
              actionLabel: 'Discover products',
              onAction: () => BuyerShell.goTo(context, 0),
            );
          }
          final visible = _visible();
          final groups = _grouped(visible);
          return RefreshIndicator(
            color: DriverColors.primary,
            edgeOffset: 128,
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPersistentHeader(pinned: true, delegate: _PinnedHeader(extent: 128, child: _controls(saved, visible.length))),
                if (visible.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(padding: EdgeInsets.all(16), child: EmptyCard(icon: Icons.search_off_rounded, title: 'No matching items', message: 'Try a different search.')),
                  ),
                for (final (category, items) in groups) ...[
                  SliverToBoxAdapter(child: _categoryHeader(category, items.length)),
                  if (gridView)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(kGridPadding, 0, kGridPadding, 8),
                      sliver: SliverGrid.builder(
                        gridDelegate: productGridDelegate(context),
                        itemCount: items.length,
                        // The card's own heart removes it from the wishlist.
                        itemBuilder: (context, i) => ProductCard(product: items[i], onTap: () => openProduct(context, items[i])),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _WishlistRow(
                          product: items[i],
                          onOpen: () => openProduct(context, items[i]),
                          onAdd: () => _addToCart(items[i]),
                          onRemove: () async {
                            final failure = await store.toggleFavorite(items[i].id);
                            if (failure != null && context.mounted) showToast(context, failure, error: true);
                          },
                        ),
                      ),
                    ),
                ],
                SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Pinned header: search bar on top, then count · sort · grid/list toggle.
  Widget _controls(int saved, int shown) {
    final searchingNow = searchController.text.trim().isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_tint, Colors.white]),
        border: Border(bottom: BorderSide(color: DriverColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: softShadow(0.07)),
          child: TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            style: DriverText.body.copyWith(fontSize: 14.5),
            decoration: InputDecoration(
              hintText: 'Search your wishlist',
              hintStyle: DriverText.body.copyWith(fontSize: 14.5, color: DriverColors.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, size: 22, color: DriverColors.primary),
              suffixIcon: searchingNow ? IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close_rounded, size: 19), onPressed: () => setState(searchController.clear)) : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: DriverColors.primary, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(color: _tint, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.favorite_rounded, size: 16, color: _heart),
              const SizedBox(width: 6),
              Text(searchingNow && shown != saved ? '$shown of $saved' : '$saved ${saved == 1 ? 'item' : 'items'}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: DriverColors.primaryDark)),
            ]),
          ),
          const Spacer(),
          PopupMenuButton<_Sort>(
            tooltip: 'Sort wishlist',
            initialValue: sort,
            onSelected: (v) => setState(() => sort = v),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (_) => [
              for (final option in _Sort.values)
                PopupMenuItem(
                  value: option,
                  child: Row(children: [
                    Icon(option.icon, size: 18, color: option == sort ? DriverColors.primary : DriverColors.textSecondary),
                    const SizedBox(width: 10),
                    Text(option.label, style: TextStyle(fontWeight: option == sort ? FontWeight.w800 : FontWeight.w500)),
                  ]),
                ),
            ],
            child: Container(
              height: 36,
              padding: const EdgeInsets.fromLTRB(11, 0, 8, 0),
              decoration: BoxDecoration(color: DriverColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: DriverColors.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(sort.icon, size: 16, color: DriverColors.primary),
                const SizedBox(width: 6),
                Text(sort.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: DriverColors.textPrimary)),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: DriverColors.textSecondary),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 36,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: DriverColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: DriverColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _ViewToggle(icon: Icons.grid_view_rounded, tooltip: 'Grid view', selected: gridView, onTap: () => setState(() => gridView = true)),
              _ViewToggle(icon: Icons.view_list_rounded, tooltip: 'List view', selected: !gridView, onTap: () => setState(() => gridView = false)),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _categoryHeader(String category, int count) {
    final accent = categoryAccent(category);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(categoryIcon(category), size: 17, color: accent),
            const SizedBox(width: 7),
            Text(category, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: accent)),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
              child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(height: 1, color: DriverColors.border)),
      ]),
    );
  }
}

/// Fixed-height pinned header for the search + controls block.
class _PinnedHeader extends SliverPersistentHeaderDelegate {
  const _PinnedHeader({required this.extent, required this.child});
  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _PinnedHeader old) => true;
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.icon, required this.tooltip, required this.selected, required this.onTap});
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 34,
            decoration: BoxDecoration(color: selected ? DriverColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 19, color: selected ? Colors.white : DriverColors.textSecondary),
          ),
        ),
      );
}

/// List-view row: image with discount badge, name, seller, price and stock,
/// with add-to-cart and remove actions.
class _WishlistRow extends StatelessWidget {
  const _WishlistRow({required this.product, required this.onOpen, required this.onAdd, required this.onRemove});

  final Product product;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final out = p.stock != null && p.stock! <= 0;
    final percent = p.discountPercent;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: DriverColors.border), boxShadow: softShadow(0.04)),
          child: Row(children: [
            Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 96, height: 96, child: NetImage(p.image, fallbackIcon: categoryIcon(p.category)))),
              if (percent > 0) Positioned(left: 0, top: 0, child: DiscountBadge(percent)),
              if (out)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ColoredBox(color: Colors.black45, child: Center(child: Text('Sold out', style: DriverText.label.copyWith(color: Colors.white, fontSize: 11)))),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.25, color: DriverColors.textPrimary)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.storefront_outlined, size: 13, color: DriverColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(child: Text(p.seller, maxLines: 1, overflow: TextOverflow.ellipsis, style: DriverText.caption)),
                ]),
                const SizedBox(height: 8),
                PriceText(p.price, oldPrice: p.oldPrice, size: 16),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: FilledButton.icon(
                        onPressed: out ? null : onAdd,
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 17),
                        label: Text(p.hasVariants ? 'Choose options' : 'Add to cart', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                        style: FilledButton.styleFrom(backgroundColor: DriverColors.primary, padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Remove from wishlist',
                    child: InkWell(
                      onTap: onRemove,
                      borderRadius: BorderRadius.circular(11),
                      child: Container(
                        width: 40,
                        height: 36,
                        decoration: BoxDecoration(color: _heartBg, borderRadius: BorderRadius.circular(11)),
                        child: const Icon(Icons.favorite_rounded, size: 19, color: _heart),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
