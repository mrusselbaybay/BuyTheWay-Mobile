import 'package:flutter/material.dart';

import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';
import '../widgets/product_pager.dart';
import 'home_screen.dart';
import 'search_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final isSearch = widget.search != null;
    return Scaffold(
      backgroundColor: BColors.background,
      appBar: AppBar(
        backgroundColor: BColors.brand,
        foregroundColor: Colors.white,
        surfaceTintColor: BColors.brand,
        titleSpacing: 0,
        title: isSearch
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SearchBox(
                  text: widget.search,
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => SearchScreen(initial: widget.search)),
                  ),
                ),
              )
            : Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          if (!isSearch)
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
              slivers: productGridSlivers(
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
            ),
          ),
        ),
      ),
    );
  }
}
