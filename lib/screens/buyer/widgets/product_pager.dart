import 'package:flutter/material.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../product/product_detail_screen.dart';
import 'buyer_widgets.dart';

/// Page-by-page loader for `GET /api/products` (newest first). One
/// instance per feed; screens call [loadMore] when the user nears the end.
class ProductPager extends ChangeNotifier {
  ProductPager({this.search, this.category, this.sellerId, this.perPage = 20});

  final String? search;
  String? category;
  final String? sellerId;
  final int perPage;

  // Search filters (set through [applyFilters]).
  num? priceMin;
  num? priceMax;
  num? minRating;
  bool inStock = false;
  bool onSale = false;

  /// Number of filters currently narrowing the results.
  int get activeFilters =>
      (category != null ? 1 : 0) +
      (priceMin != null || priceMax != null ? 1 : 0) +
      (minRating != null ? 1 : 0) +
      (inStock ? 1 : 0) +
      (onSale ? 1 : 0);

  Future<void> applyFilters({String? category, num? priceMin, num? priceMax, num? minRating, bool inStock = false, bool onSale = false}) {
    this.onSale = onSale;
    this.category = category;
    this.priceMin = priceMin;
    this.priceMax = priceMax;
    this.minRating = minRating;
    this.inStock = inStock;
    return refresh();
  }

  final List<Product> products = [];
  final Set<String> _ids = {};
  int _page = 0;
  int _lastPage = 1;
  bool loading = false;
  String? error;
  bool _disposed = false;
  int _gen = 0;

  bool get hasMore => _page < _lastPage;
  bool get initialLoading => products.isEmpty && (loading || (_page == 0 && error == null));

  Future<void> refresh() {
    NetImage.retryFailed();
    _gen++;
    loading = false;
    products.clear();
    _ids.clear();
    _page = 0;
    _lastPage = 1;
    error = null;
    return loadMore();
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    loading = true;
    error = null;
    final gen = _gen;
    _notify();
    try {
      final (items, lastPage) = await BuyerStore.instance.api.products(
        search: search,
        category: category,
        sellerId: sellerId,
        priceMin: priceMin,
        priceMax: priceMax,
        minRating: minRating,
        inStock: inStock,
        onSale: onSale,
        page: _page + 1,
        perPage: perPage,
      );
      if (gen != _gen) return; // filters changed mid-flight; a newer load owns the state
      for (final p in items) {
        if (_ids.add(p.id)) products.add(p);
      }
      _page++;
      _lastPage = lastPage;
    } catch (e) {
      if (gen != _gen) return;
      error = BuyerStore.instance.handleError(e);
    } finally {
      if (gen == _gen) {
        loading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Calls [onNearEnd] when the scroll position is within ~1.5 screens of
/// the bottom, so the next page is already loading before the user gets there.
bool handleNearEnd(ScrollNotification n, VoidCallback onNearEnd) {
  if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < n.metrics.viewportDimension * 1.5) onNearEnd();
  return false;
}

/// The grid + footer slivers for a [ProductPager]: skeletons on first load,
/// empty / error states, then a spinner / retry / end-of-list footer.
List<Widget> productGridSlivers(BuildContext context, ProductPager pager, {required Widget empty, double? width}) {
  if (pager.initialLoading) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(kGridPadding, 10, kGridPadding, 0),
        sliver: SliverGrid(
          gridDelegate: productGridDelegate(context, width: width),
          delegate: SliverChildBuilderDelegate((_, __) => const ProductCardSkeleton(), childCount: 6),
        ),
      ),
    ];
  }

  if (pager.products.isEmpty) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: pager.error != null ? ErrorState(message: pager.error!, onRetry: pager.refresh) : empty,
      ),
    ];
  }

  return [
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(kGridPadding, 10, kGridPadding, 0),
      sliver: SliverGrid(
        gridDelegate: productGridDelegate(context, width: width),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final product = pager.products[i];
            return ProductCard(product: product, onTap: () => openProduct(context, product));
          },
          childCount: pager.products.length,
        ),
      ),
    ),
    SliverToBoxAdapter(
      child: SizedBox(
        height: 72,
        child: Center(
          child: pager.loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: BColors.brand))
              : pager.error != null
                  ? TextButton.icon(
                      onPressed: pager.loadMore,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Couldn\'t load more — tap to retry'),
                    )
                  : !pager.hasMore
                      ? const Text('You\'ve reached the end', style: BText.tiny)
                      : const SizedBox.shrink(),
        ),
      ),
    ),
  ];
}
