import 'package:flutter/material.dart';

import '../buyer_models.dart';
import '../buyer_shell.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../product/product_detail_screen.dart';
import '../widgets/buyer_widgets.dart';

/// The wishlist API stores product ids only, so products are fetched in
/// parallel; removed / unavailable ones are dropped from the grid.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final store = BuyerStore.instance;
  final Map<String, Product> products = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BColors.background,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        surfaceTintColor: BColors.surface,
        foregroundColor: BColors.ink,
        title: const Text('My Wishlist', style: BText.title),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = products.values.where((p) => store.isFavorite(p.id)).toList();
          if (loading && items.isEmpty) {
            return GridView.builder(
              padding: const EdgeInsets.all(kGridPadding),
              gridDelegate: productGridDelegate(context),
              itemCount: 4,
              itemBuilder: (_, __) => const ProductCardSkeleton(),
            );
          }
          if (error != null && items.isEmpty) return ErrorState(message: error!, onRetry: _load);
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border,
              title: 'Your wishlist is empty',
              message: 'Tap the heart on any product to save it here.',
              actionLabel: 'Discover products',
              onAction: () => BuyerShell.goTo(context, 0),
            );
          }
          return RefreshIndicator(
            color: BColors.brand,
            onRefresh: _load,
            child: GridView.builder(
              padding: const EdgeInsets.all(kGridPadding),
              gridDelegate: productGridDelegate(context),
              itemCount: items.length,
              // The card's own heart removes it from the wishlist.
              itemBuilder: (context, i) => ProductCard(product: items[i], onTap: () => openProduct(context, items[i])),
            ),
          );
        },
      ),
    );
  }
}
