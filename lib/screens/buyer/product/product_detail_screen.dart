import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../cart/cart_screen.dart';
import '../catalog/product_list_screen.dart';
import '../checkout/checkout_screen.dart';
import '../widgets/buyer_widgets.dart';
import '../chat/chat_thread_screen.dart';
import 'reviews_screen.dart';
import 'variant_sheet.dart';

void openProduct(BuildContext context, Product product) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id, initial: product)));
}

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId, this.initial});

  final String productId;
  final Product? initial;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final store = BuyerStore.instance;
  late Product? product = widget.initial;
  bool notFound = false;
  String? error;

  List<Coupon> coupons = [];
  ReviewSummary? summary;
  List<Review> topReviews = [];
  bool descriptionExpanded = false;
  int galleryIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Renders instantly from the list item, then refreshes stock/price and
  /// loads coupons + reviews in parallel.
  Future<void> _load() async {
    setState(() => error = null);
    await Future.wait([
      () async {
        try {
          final fresh = await store.api.product(widget.productId);
          if (!mounted) return;
          setState(() {
            if (fresh == null) {
              notFound = true;
            } else {
              product = fresh;
            }
          });
        } catch (e) {
          if (mounted && product == null) setState(() => error = store.handleError(e));
        }
      }(),
      () async {
        try {
          final list = await store.api.productCoupons(widget.productId);
          if (mounted) setState(() => coupons = list);
        } catch (_) {}
      }(),
      () async {
        try {
          final (items, s, _) = await store.api.productReviews(widget.productId, perPage: 3);
          if (mounted) {
            setState(() {
              topReviews = items;
              summary = s;
            });
          }
        } catch (_) {}
      }(),
    ]);
  }

  Future<void> _addToCart() async {
    final p = product!;
    ProductVariant? variant;
    var qty = 1;
    if (p.usesVariants) {
      final selection = await showVariantSheet(context, p, VariantSheetMode.addToCart);
      if (selection == null || !mounted) return;
      variant = selection.variant;
      qty = selection.quantity;
    }
    final result = store.addToCart(p, variant, qty);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    showToast(
      context,
      result.message,
      error: !result.ok,
      action: result.ok
          ? SnackBarAction(label: 'VIEW CART', textColor: const Color(0xFF5EEAD4), onPressed: _openCart)
          : null,
    );
  }

  Future<void> _buyNow() async {
    final p = product!;
    ProductVariant? variant;
    var qty = 1;
    if (p.usesVariants) {
      final selection = await showVariantSheet(context, p, VariantSheetMode.buyNow);
      if (selection == null || !mounted) return;
      variant = selection.variant;
      qty = selection.quantity;
    }
    final line = store.buildLine(p, variant, qty);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckoutScreen(items: [line], fromCart: false)));
  }

  void _openCart() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen(standalone: true)));

  Future<void> _toggleFavorite() async {
    final error = await store.toggleFavorite(widget.productId);
    if (error != null && mounted) showToast(context, error, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = product;
    if (p == null || notFound) {
      return Scaffold(
        appBar: AppBar(backgroundColor: BColors.surface, foregroundColor: BColors.ink, surfaceTintColor: BColors.surface),
        body: notFound
            ? EmptyState(
                icon: Icons.remove_shopping_cart_outlined,
                title: 'This product is no longer available',
                message: 'The seller may have removed it.',
                actionLabel: 'Go back',
                onAction: () => Navigator.pop(context),
              )
            : error != null
                ? ErrorState(message: error!, onRetry: _load)
                : const Center(child: CircularProgressIndicator(color: BColors.brand)),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final images = p.images.isNotEmpty ? p.images : [if (p.image != null) p.image!];
    final (low, high) = p.priceRange;
    final stock = p.availableStock;

    return Scaffold(
      backgroundColor: BColors.background,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: width.clamp(0, 520),
          backgroundColor: BColors.surface,
          surfaceTintColor: BColors.surface,
          foregroundColor: BColors.ink,
          leading: _CircleAction(icon: Icons.arrow_back, tooltip: 'Back', onTap: () => Navigator.pop(context)),
          actions: [
            ListenableBuilder(
              listenable: store,
              builder: (_, __) => _CircleAction(
                icon: Icons.shopping_cart_outlined,
                tooltip: 'Cart',
                badge: store.cartCount,
                onTap: _openCart,
              ),
            ),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              images.isEmpty
                  ? NetImage(null, fallbackIcon: categoryIcon(p.category))
                  : PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => galleryIndex = i),
                      itemBuilder: (_, i) => NetImage(images[i], fallbackIcon: categoryIcon(p.category)),
                    ),
              if (images.length > 1)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                    child: Text('${galleryIndex + 1}/${images.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
            ]),
          ),
        ),

        // ---- Price / title ----
        SliverToBoxAdapter(
          child: Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Flexible(child: PriceText(low, maxPrice: high > low ? high : null, oldPrice: p.oldPrice, size: 22)),
                if (p.discountPercent > 0) ...[const SizedBox(width: 8), DiscountBadge(p.discountPercent)],
              ]),
              const SizedBox(height: 10),
              Text(p.name, style: const TextStyle(fontSize: 16, height: 1.35, fontWeight: FontWeight.w500, color: BColors.ink)),
              const SizedBox(height: 10),
              Row(children: [
                if (p.rating != null && p.reviewCount > 0) ...[
                  StarRow(p.rating!, size: 14),
                  const SizedBox(width: 4),
                  Text(p.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 13, color: BColors.ink, fontWeight: FontWeight.w600)),
                  Container(width: 1, height: 12, margin: const EdgeInsets.symmetric(horizontal: 8), color: BColors.border),
                  Flexible(child: Text('${p.reviewCount} ${p.reviewCount == 1 ? 'review' : 'reviews'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.small)),
                ] else
                  const Flexible(child: Text('No ratings yet', style: BText.small)),
                const Spacer(),
                if (stock != null && stock > 0 && stock <= 10)
                  Text('Only $stock left', style: const TextStyle(fontSize: 12.5, color: BColors.cta, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
        ),

        // ---- Vouchers + variations ----
        if (coupons.isNotEmpty || p.usesVariants)
          SliverToBoxAdapter(
            child: Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                if (coupons.isNotEmpty)
                  _RowLink(
                    label: 'Vouchers',
                    onTap: () => _showCoupons(context),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: coupons.take(3).map((c) => _VoucherTag(c.label)).toList(),
                    ),
                  ),
                if (coupons.isNotEmpty && p.usesVariants) const Divider(height: 1, indent: 14, color: BColors.divider),
                if (p.usesVariants)
                  _RowLink(
                    label: 'Variations',
                    onTap: _addToCart,
                    child: Text(
                      'Select ${p.options.map((o) => o.name).join(', ')}'
                      ' · ${p.variants.where((v) => v.isActive).length} options',
                      style: BText.small,
                    ),
                  ),
              ]),
            ),
          ),

        // ---- Shop ----
        SliverToBoxAdapter(
          child: Panel(
            child: Row(children: [
              const CircleAvatar(radius: 22, backgroundColor: BColors.brandSurface, child: Icon(Icons.storefront, color: BColors.brand)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.seller, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  if (p.category != null) Text(p.category!, style: BText.tiny),
                ]),
              ),
              if (p.sellerId != null)
                OutlinedButton(
                  style: BButtons.outline(height: 34, color: BColors.cta),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProductListScreen(title: p.seller, sellerId: p.sellerId),
                  )),
                  child: const Text('View Shop'),
                ),
            ]),
          ),
        ),

        // ---- Details ----
        SliverToBoxAdapter(
          child: Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Product Details', style: BText.section),
              const SizedBox(height: 10),
              ...[
                if (p.category != null) MapEntry('Category', p.category!),
                if (p.brand != null) MapEntry('Brand', p.brand!),
                if (p.condition != null) MapEntry('Condition', p.condition!),
                if (stock != null) MapEntry('Stock', '$stock'),
                ...p.specifications,
              ].map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 110, child: Text(e.key, style: BText.small)),
                      Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13, color: BColors.ink))),
                    ]),
                  )),
              if (p.description != null) ...[
                const Divider(height: 24, color: BColors.divider),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: Text(
                    p.description!,
                    maxLines: descriptionExpanded ? null : 6,
                    overflow: descriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: BText.body,
                  ),
                ),
                if (p.description!.length > 240 || '\n'.allMatches(p.description!).length > 5)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => descriptionExpanded = !descriptionExpanded),
                      iconAlignment: IconAlignment.end,
                      icon: Icon(descriptionExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
                      label: Text(descriptionExpanded ? 'See less' : 'See more'),
                      style: TextButton.styleFrom(foregroundColor: BColors.brand),
                    ),
                  ),
              ],
            ]),
          ),
        ),

        // ---- Reviews ----
        SliverToBoxAdapter(
          child: Panel(
            padding: EdgeInsets.zero,
            child: Column(children: [
              InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ReviewsScreen(productId: p.id, initialSummary: summary),
                )),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Row(children: [
                    const Text('Product Ratings', style: BText.section),
                    const SizedBox(width: 8),
                    if (summary?.average != null) ...[
                      StarRow(summary!.average!, size: 13),
                      const SizedBox(width: 4),
                      Text('${summary!.average!.toStringAsFixed(1)}/5', style: const TextStyle(fontSize: 13, color: BColors.cta, fontWeight: FontWeight.w600)),
                    ],
                    const Spacer(),
                    Text('See all (${summary?.total ?? p.reviewCount})', style: const TextStyle(fontSize: 12.5, color: BColors.brand)),
                    const Icon(Icons.chevron_right, color: BColors.brand, size: 18),
                  ]),
                ),
              ),
              if (topReviews.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 16),
                  child: Align(alignment: Alignment.centerLeft, child: Text('No reviews yet. Be the first after your purchase.', style: BText.small)),
                )
              else
                ...topReviews.map((r) => Column(children: [const Divider(height: 1, color: BColors.divider), ReviewTile(review: r)])),
            ]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ]),
      bottomNavigationBar: _BottomBar(
        productId: p.id,
        soldOut: p.isSoldOut,
        onFavorite: _toggleFavorite,
        onChat: p.sellerId == null ? null : () => openSellerChat(context, sellerId: p.sellerId!, productId: p.id),
        onAddToCart: _addToCart,
        onBuyNow: _buyNow,
      ),
    );
  }

  void _showCoupons(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BRadius.md))),
      builder: (_) => _CouponSheet(coupons: coupons),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.tooltip, required this.onTap, this.badge = 0});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Colors.black.withValues(alpha: 0.32),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onTap,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
            icon: Badge(
              isLabelVisible: badge > 0,
              label: Text(badge > 99 ? '99+' : '$badge'),
              backgroundColor: BColors.cta,
              child: Icon(icon, color: Colors.white, size: 21),
            ),
          ),
        ),
      );
}

class _RowLink extends StatelessWidget {
  const _RowLink({required this.label, required this.child, required this.onTap});

  final String label;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(children: [
            SizedBox(width: 84, child: Text(label, style: BText.small)),
            Expanded(child: child),
            const Icon(Icons.chevron_right, color: BColors.faint),
          ]),
        ),
      );
}

class _VoucherTag extends StatelessWidget {
  const _VoucherTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: BColors.ctaSurface,
          border: Border.all(color: BColors.cta.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11.5, color: BColors.cta, fontWeight: FontWeight.w600)),
      );
}

/// Claimable product vouchers. Claimed ones go to the buyer's wallet and
/// are auto-applied at checkout (best one per item).
class _CouponSheet extends StatefulWidget {
  const _CouponSheet({required this.coupons});

  final List<Coupon> coupons;

  @override
  State<_CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends State<_CouponSheet> {
  final store = BuyerStore.instance;
  final Set<String> claimed = {};
  final Set<String> claiming = {};

  @override
  void initState() {
    super.initState();
    store.api.couponWallet().then((wallet) {
      if (mounted) setState(() => claimed.addAll(wallet.map((w) => w.couponId).whereType<String>()));
    }).catchError((_) {});
  }

  Future<void> _claim(Coupon c) async {
    setState(() => claiming.add(c.id));
    try {
      await store.api.claimCoupon(c.id);
      if (!mounted) return;
      setState(() => claimed.add(c.id));
      HapticFeedback.selectionClick();
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => claiming.remove(c.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Vouchers', style: BText.title),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Claimed vouchers are applied automatically at checkout.', style: BText.small, textAlign: TextAlign.center),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: widget.coupons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final c = widget.coupons[i];
                final isClaimed = claimed.contains(c.id);
                return Container(
                  decoration: BoxDecoration(border: Border.all(color: BColors.border), borderRadius: BorderRadius.circular(BRadius.sm)),
                  child: IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Container(
                        width: 6,
                        decoration: const BoxDecoration(
                          color: BColors.cta,
                          borderRadius: BorderRadius.horizontal(left: Radius.circular(BRadius.sm)),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BColors.cta)),
                            if (c.discount != null && c.discount! > 0) Text('Save ${peso(c.discount!)} on this item', style: BText.small),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (c.expiresAt != null) 'Valid till ${formatDate(c.expiresAt)}',
                                if (c.runningLow && c.remaining != null) 'Only ${c.remaining} left',
                              ].join(' · '),
                              style: TextStyle(fontSize: 11.5, color: c.runningLow ? BColors.cta : BColors.muted),
                            ),
                          ]),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Center(
                          child: isClaimed
                              ? const Text('Claimed', style: TextStyle(color: BColors.muted, fontWeight: FontWeight.w600))
                              : ElevatedButton(
                                  onPressed: claiming.contains(c.id) ? null : () => _claim(c),
                                  style: BButtons.cta(height: 34),
                                  child: claiming.contains(c.id)
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Claim'),
                                ),
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.productId, required this.soldOut, required this.onFavorite, this.onChat, required this.onAddToCart, required this.onBuyNow});

  final String productId;
  final bool soldOut;
  final VoidCallback onFavorite;
  final VoidCallback? onChat;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  @override
  Widget build(BuildContext context) {
    final store = BuyerStore.instance;
    return Container(
      decoration: const BoxDecoration(color: BColors.surface, border: Border(top: BorderSide(color: BColors.border))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(children: [
            if (onChat != null)
              Semantics(
                button: true,
                label: 'Chat with seller',
                child: InkWell(
                  onTap: onChat,
                  child: const SizedBox(
                    width: 60,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.chat_bubble_outline, color: BColors.brand, size: 21),
                      SizedBox(height: 2),
                      Text('Chat', style: TextStyle(fontSize: 11, color: BColors.muted)),
                    ]),
                  ),
                ),
              ),
            ListenableBuilder(
              listenable: store,
              builder: (_, __) {
                final fav = store.isFavorite(productId);
                return Semantics(
                  button: true,
                  label: fav ? 'Remove from wishlist' : 'Add to wishlist',
                  child: InkWell(
                    onTap: onFavorite,
                    child: SizedBox(
                      width: 60,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                          child: Icon(
                            fav ? Icons.favorite : Icons.favorite_border,
                            key: ValueKey(fav),
                            color: fav ? BColors.cta : BColors.muted,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text('Wishlist', style: TextStyle(fontSize: 11, color: BColors.muted)),
                      ]),
                    ),
                  ),
                );
              },
            ),
            if (soldOut)
              Expanded(
                child: Container(
                  color: BColors.border,
                  alignment: Alignment.center,
                  child: const Text('Sold Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BColors.muted)),
                ),
              )
            else ...[
              Expanded(
                child: Material(
                  color: BColors.brandSurface,
                  child: InkWell(
                    onTap: onAddToCart,
                    child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_shopping_cart, color: BColors.brand, size: 20),
                      Text('Add to Cart', style: TextStyle(fontSize: 12, color: BColors.brand, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  color: BColors.cta,
                  child: InkWell(
                    onTap: onBuyNow,
                    child: const Center(
                      child: Text('Buy Now', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
