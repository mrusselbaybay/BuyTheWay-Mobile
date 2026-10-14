import 'package:flutter/material.dart';

import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';
import '../widgets/product_pager.dart';
import 'home_screen.dart';
import 'search_filter_sheet.dart';
import 'search_screen.dart';
import 'store_screen.dart';

/// Search results, a category, or one shop's products — same grid, same
/// pager; only the query differs.
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key, required this.title, this.search, this.category, this.sellerId});

  final String title;
  final String? search;
  final String? category;
  final String? sellerId;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late final pager = ProductPager(search: widget.search, category: widget.category, sellerId: widget.sellerId);

  List<Map<String, dynamic>> _stores = const [];

  @override
  void initState() {
    super.initState();
    pager.loadMore();
    if (widget.search != null && widget.sellerId == null) _loadStores(widget.search!);
  }

  /// Shops matching the query are listed above the products; none, no section.
  Future<void> _loadStores(String search) async {
    try {
      final result = await BuyerStore.instance.api.searchSuggestions(search);
      if (mounted && result.stores.isNotEmpty) setState(() => _stores = result.stores);
    } catch (_) {}
  }

  Widget _storesRail() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGridPadding, 10, kGridPadding, 0),
      child: Column(children: [for (final s in _stores) Padding(padding: const EdgeInsets.only(bottom: 8), child: _storeCard(s))]),
    );
  }

  /// A matching shop: logo, name, and (when it has them) rating, units sold,
  /// delivery estimate; chevron at the right.
  Widget _storeCard(Map<String, dynamic> s) {
    final rating = s['rating'] is num ? (s['rating'] as num).toDouble() : null;
    final sold = s['soldCount'] is num ? (s['soldCount'] as num).toInt() : 0;
    final location = s['location'] as String?;
    final stats = <Widget>[
      if (rating != null) ...[
        const Icon(Icons.star_rounded, size: 14, color: BColors.star),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BColors.ink)),
      ],
      if (sold > 0) ...[
        if (rating != null) _statDivider,
        Text('${compactCount(sold)} Sold', style: BText.tiny),
      ],
      if (rating != null || sold > 0) ...[
        _statDivider,
        const Icon(Icons.local_shipping_outlined, size: 14, color: BColors.success),
        const SizedBox(width: 3),
        const Text('2-3 Days', style: TextStyle(fontSize: 12, color: BColors.success)),
      ],
    ];
    return Material(
      color: BColors.surface,
      borderRadius: BorderRadius.circular(BRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(BRadius.md),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StoreScreen(storeId: '${s['id']}', name: s['name'] as String?, logo: s['logo'] as String?),
        )),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(children: [
            ClipOval(child: SizedBox(width: 48, height: 48, child: NetImage(s['logo'] as String?, fallbackIcon: Icons.storefront_outlined))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BColors.ink)),
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: stats),
                ] else if (location != null) ...[
                  const SizedBox(height: 2),
                  Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.tiny),
                ],
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: BColors.faint),
          ]),
        ),
      ),
    );
  }

  static const _statDivider =
      Padding(padding: EdgeInsets.symmetric(horizontal: 7), child: SizedBox(height: 12, child: VerticalDivider(width: 1, color: BColors.border)));

  @override
  void dispose() {
    pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSearch = widget.search != null;
    return Scaffold(
      backgroundColor: BColors.background,
      appBar: AppBar(
        backgroundColor: isSearch ? BColors.surface : BColors.brand,
        foregroundColor: isSearch ? BColors.ink : Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: isSearch ? 0 : null,
        shape: isSearch ? const Border(bottom: BorderSide(color: BColors.border)) : null,
        titleSpacing: 0,
        title: isSearch
            ? SearchBox(
                text: widget.search,
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => SearchScreen(initial: widget.search)),
                ),
              )
            : Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          if (isSearch)
            ListenableBuilder(
              listenable: pager,
              builder: (context, _) {
                final count = pager.activeFilters;
                return IconButton(
                  tooltip: 'Filter',
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    backgroundColor: BColors.brand,
                    child: const Icon(Icons.tune_rounded),
                  ),
                  onPressed: () => showSearchFilters(context, pager, widget.search!),
                );
              },
            )
          else
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: pager,
        builder: (context, _) => RefreshIndicator(
          color: BColors.brand,
          onRefresh: pager.refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) => handleNearEnd(n, pager.loadMore),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (_stores.isNotEmpty) SliverToBoxAdapter(child: _storesRail()),
                ...productGridSlivers(
                context,
                pager,
                empty: EmptyState(
                  icon: isSearch ? Icons.search_off_rounded : Icons.inventory_2_outlined,
                  title: isSearch ? 'No results for "${widget.search}"' : 'Nothing here yet',
                  message: isSearch ? 'Try a shorter keyword or check the spelling.' : 'No products are listed in this section yet.',
                  actionLabel: isSearch ? 'Search again' : null,
                  onAction: isSearch
                      ? () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SearchScreen(initial: widget.search)))
                      : null,
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
