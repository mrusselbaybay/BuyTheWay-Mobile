import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../cart/cart_screen.dart';
import '../catalog/store_screen.dart';
import '../catalog/search_screen.dart';
import '../checkout/checkout_screen.dart';
import '../widgets/buyer_widgets.dart';
import '../chat/chat_thread_screen.dart';
import '../widgets/deal_ticket.dart';
import 'reviews_screen.dart';
import 'variant_sheet.dart';

void openProduct(BuildContext context, Product product) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id, initial: product)));
}

const _tabs = ['Overview', 'Reviews', 'Description', 'Related'];

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
  final Set<String> claimedCoupons = {};
  final Set<String> claimingCoupons = {};
  ReviewSummary? summary;
  ReviewSummary? storeSummary; // reviews across the whole shop
  List<Review> topReviews = [];
  Map<String, dynamic>? storeInfo;
  List<Product> shopProducts = [];
  List<Product> related = [];
  List<ShippingOption>? deliveryOptions;
  bool descriptionExpanded = false;
  bool specsExpanded = false;
  int galleryIndex = 0;
  String? followStatusFor;
  bool? isFollowing;
  bool followBusy = false;
  String? _extrasFor;

  // Tabs jump to / follow these sections of the one scrolling page.
  final _scroll = ScrollController();
  final _viewportKey = GlobalKey();
  final _sectionKeys = List.generate(_tabs.length, (_) => GlobalKey());
  int tab = 0;
  bool _jumping = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
    if (product?.sellerId != null) _loadFollow(product!.sellerId!);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ---------------- Tabs ----------------

  void _onScroll() {
    if (_jumping) return;
    final viewport = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.attached) return;
    final threshold = viewport.localToGlobal(Offset.zero).dy + 24;
    var active = 0;
    for (var i = 0; i < _sectionKeys.length; i++) {
      final box = _sectionKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.attached && box.localToGlobal(Offset.zero).dy <= threshold) active = i;
    }
    // At the very bottom the last tab wins even if its section is short.
    if (_scroll.hasClients && _scroll.position.pixels >= _scroll.position.maxScrollExtent - 4) active = _tabs.length - 1;
    if (active != tab) setState(() => tab = active);
  }

  Future<void> _goTo(int index) async {
    final viewport = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final box = _sectionKeys[index].currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || box == null || !_scroll.hasClients) return;
    final dy = box.localToGlobal(Offset.zero).dy - viewport.localToGlobal(Offset.zero).dy;
    final target = (_scroll.offset + dy).clamp(0.0, _scroll.position.maxScrollExtent);
    setState(() {
      tab = index;
      _jumping = true;
    });
    await _scroll.animateTo(target, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    _jumping = false;
  }

  // ---------------- Data ----------------

  Future<void> _loadFollow(String sellerId) async {
    if (followStatusFor == sellerId) return;
    followStatusFor = sellerId;
    try {
      final following = await store.api.followsStore(sellerId);
      if (mounted && product?.sellerId == sellerId) setState(() => isFollowing = following);
    } catch (_) {
      followStatusFor = null;
    }
  }

  Future<void> _toggleFollow(String sellerId) async {
    if (followBusy || isFollowing == null) return;
    setState(() => followBusy = true);
    try {
      if (isFollowing!) {
        await store.api.unfollowStore(sellerId);
        if (mounted) setState(() => isFollowing = false);
      } else {
        final following = await store.api.followStore(sellerId);
        if (mounted) setState(() => isFollowing = following);
      }
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => followBusy = false);
    }
  }

  /// Renders instantly from the list item, then refreshes stock/price and
  /// loads vouchers + reviews in parallel; shop, related and delivery info
  /// follow once the product is known.
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
              if (fresh.sellerId != null) _loadFollow(fresh.sellerId!);
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
          final wallet = await store.api.couponWallet();
          if (mounted) setState(() => claimedCoupons.addAll(wallet.map((w) => w.couponId).whereType<String>()));
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
    final p = product;
    if (p != null && mounted) _loadExtras(p);
  }

  void _loadExtras(Product p) {
    if (_extrasFor == p.id) return;
    _extrasFor = p.id;
    final sellerId = p.sellerId;
    if (sellerId != null) {
      store.api.storeInfo(sellerId).then((info) {
        if (mounted) setState(() => storeInfo = info);
      }).catchError((_) {});
      store.api.storeReviews(sellerId, perPage: 1).then((r) {
        if (mounted) setState(() => storeSummary = r.$2);
      }).catchError((_) {});
      store.api.products(sellerId: sellerId, perPage: 9).then((r) {
        if (mounted) setState(() => shopProducts = r.$1.where((x) => x.id != p.id).take(8).toList());
      }).catchError((_) {});
    }
    if (p.category != null) {
      // Same category, from any shop (this product itself excluded).
      store.api.products(category: p.category, perPage: 13).then((r) {
        if (mounted) setState(() => related = r.$1.where((x) => x.id != p.id).take(12).toList());
      }).catchError((_) {});
    }
    final address = store.defaultAddress;
    store.api.shippingOptions([p.id], addressId: address?.isComplete == true ? address!.id : null).then((r) {
      if (mounted) setState(() => deliveryOptions = r.$1);
    }).catchError((_) {});
  }

  Future<void> _claim(Coupon c) async {
    setState(() => claimingCoupons.add(c.id));
    try {
      await store.api.claimCoupon(c.id);
      if (!mounted) return;
      setState(() => claimedCoupons.add(c.id));
      HapticFeedback.selectionClick();
      showToast(context, 'Voucher claimed — applied automatically at checkout');
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => claimingCoupons.remove(c.id));
    }
  }

  // ---------------- Actions ----------------

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
      action: result.ok ? SnackBarAction(label: 'VIEW CART', textColor: const Color(0xFF5EEAD4), onPressed: _openCart) : null,
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

  void _openShop(Product p) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoreScreen(storeId: p.sellerId!, name: p.seller)));

  Future<void> _toggleFavorite() async {
    final error = await store.toggleFavorite(widget.productId);
    if (error != null && mounted) showToast(context, error, error: true);
  }

  void _showDelivery() {
    final options = deliveryOptions ?? const <ShippingOption>[];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: BColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 4), child: Text('Delivery options', style: BText.title)),
          const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('Fees are per shop and depend on where you\'re delivering to.', style: BText.small, textAlign: TextAlign.center)),
          for (final o in options)
            ListTile(
              leading: Icon(Icons.local_shipping_outlined, color: o.available ? BColors.brand : BColors.faint),
              title: Text(o.name, style: TextStyle(fontWeight: FontWeight.w700, color: o.available ? BColors.ink : BColors.faint)),
              subtitle: Text(o.available ? (o.description ?? '') : (o.unavailableReason ?? 'Not available'), style: BText.small),
              trailing: Text(peso(o.fee), style: TextStyle(fontWeight: FontWeight.w800, color: o.available ? BColors.ink : BColors.faint)),
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  // ---------------- Build ----------------

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

    return Scaffold(
      backgroundColor: BColors.background,
      body: Column(children: [
        _TopBar(product: p, onBack: () => Navigator.pop(context), onSearch: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())), onFavorite: _toggleFavorite, onCart: _openCart),
        _TabStrip(index: tab, onTap: _goTo),
        Expanded(
          child: SingleChildScrollView(
            key: _viewportKey,
            controller: _scroll,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              KeyedSubtree(key: _sectionKeys[0], child: _overview(p)),
              KeyedSubtree(key: _sectionKeys[1], child: _reviewsSection(p)),
              _storeReviewsCard(p),
              _shopCard(p),
              KeyedSubtree(key: _sectionKeys[2], child: _descriptionSection(p)),
              KeyedSubtree(key: _sectionKeys[3], child: _relatedSection()),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: _BottomBar(
        price: p.priceRange.$1,
        soldOut: p.isSoldOut,
        onShop: p.sellerId == null ? null : () => _openShop(p),
        onChat: p.sellerId == null ? null : () => openSellerChat(context, sellerId: p.sellerId!, productId: p.id),
        onAddToCart: _addToCart,
        onBuyNow: _buyNow,
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(14), EdgeInsets margin = const EdgeInsets.fromLTRB(12, 0, 12, 10)}) => Container(
        width: double.infinity,
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: BColors.border), boxShadow: softShadow(0.03)),
        child: child,
      );

  // ---- Overview: gallery, price + title, delivery / options, deals ----

  Widget _overview(Product p) {
    final width = MediaQuery.sizeOf(context).width;
    final images = p.images.isNotEmpty ? p.images : [if (p.image != null) p.image!];
    final (low, high) = p.priceRange;
    final stock = p.availableStock;
    final activeVariants = p.variants.where((v) => v.isActive && v.image != null).toList();
    final cheapest = (deliveryOptions ?? const <ShippingOption>[]).where((o) => o.available).fold<ShippingOption?>(null, (best, o) => best == null || o.fee < best.fee ? o : best);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        height: (width * 0.72).clamp(220.0, 340.0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: BColors.border)),
        child: Stack(fit: StackFit.expand, children: [
          images.isEmpty
              ? NetImage(null, fallbackIcon: categoryIcon(p.category))
              : PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => galleryIndex = i),
                  itemBuilder: (_, i) => Padding(padding: const EdgeInsets.all(6), child: NetImage(images[i], fit: BoxFit.contain, fallbackIcon: categoryIcon(p.category))),
                ),
          if (images.length > 1)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12)),
                child: Text('${galleryIndex + 1}/${images.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      ),
      _card(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Flexible(child: PriceText(low, maxPrice: high > low ? high : null, oldPrice: p.oldPrice, size: 24)),
            if (p.discountPercent > 0) ...[const SizedBox(width: 8), DiscountBadge(p.discountPercent)],
          ]),
          const SizedBox(height: 10),
          Text(p.name, style: const TextStyle(fontSize: 16.5, height: 1.35, fontWeight: FontWeight.w700, color: BColors.ink)),
          const SizedBox(height: 10),
          Row(children: [
            if (p.rating != null && p.reviewCount > 0) ...[
              const Icon(Icons.star_rounded, size: 18, color: BColors.star),
              const SizedBox(width: 3),
              Text(p.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 13.5, color: BColors.ink, fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              Text('(${p.reviewCount})', style: const TextStyle(fontSize: 13, color: BColors.brand, fontWeight: FontWeight.w600)),
            ] else
              const Text('No ratings yet', style: BText.small),
            if (p.soldCount > 0) ...[
              Container(width: 1, height: 12, margin: const EdgeInsets.symmetric(horizontal: 9), color: BColors.border),
              Text(_soldLabel(p.soldCount), style: const TextStyle(fontSize: 13, color: BColors.ink, fontWeight: FontWeight.w600)),
            ],
            const Spacer(),
            if (stock != null && stock > 0 && stock <= 10)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(999)),
                child: Text('Only $stock left', style: const TextStyle(fontSize: 11.5, color: BColors.brandDark, fontWeight: FontWeight.w800)),
              ),
          ]),
        ]),
      ),
      _card(
        padding: EdgeInsets.zero,
        child: Column(children: [
          _InfoRow(
            icon: Icons.local_shipping_outlined,
            onTap: deliveryOptions == null || deliveryOptions!.isEmpty ? null : _showDelivery,
            child: deliveryOptions == null
                ? const SkeletonBox(height: 14, width: 180)
                : cheapest == null
                    ? const Text('Delivery unavailable for your address', style: BText.small)
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${cheapest.name} · from ${peso(cheapest.fee)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        if (cheapest.description != null) Text(cheapest.description!, style: BText.tiny),
                      ]),
          ),
          if (p.usesVariants) ...[
            const Divider(height: 1, indent: 14, color: BColors.divider),
            _InfoRow(
              icon: Icons.grid_view_rounded,
              onTap: _addToCart,
              child: Row(children: [
                for (final v in activeVariants.take(5)) ...[
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 38, height: 38, child: NetImage(v.image, fallbackIcon: categoryIcon(p.category)))),
                  const SizedBox(width: 6),
                ],
                Expanded(child: Text('Select ${p.options.map((o) => o.name).join(', ')} · ${p.variants.where((v) => v.isActive).length} options', maxLines: 2, overflow: TextOverflow.ellipsis, style: BText.small)),
              ]),
            ),
          ],
          const Divider(height: 1, indent: 14, color: BColors.divider),
          const _InfoRow(
            icon: Icons.payments_outlined,
            child: Text('Cash on delivery — pay when your parcel arrives', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
      if (coupons.isNotEmpty) ...[
        const Padding(padding: EdgeInsets.fromLTRB(16, 6, 16, 8), child: Text('Deals', style: BText.title)),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: coupons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => DealTicket(coupon: coupons[i], claimed: claimedCoupons.contains(coupons[i].id), claiming: claimingCoupons.contains(coupons[i].id), onClaim: () => _claim(coupons[i])),
          ),
        ),
        const SizedBox(height: 14),
      ],
    ]);
  }

  /// 316 sold · 1.2k sold
  String _soldLabel(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}k sold' : '$n sold';

  // ---- Reviews ----

  Widget _reviewsSection(Product p) {
    final total = summary?.total ?? p.reviewCount;
    final average = summary?.average ?? p.rating;
    return _card(
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewsScreen(productId: p.id, initialSummary: summary))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Customer reviews ($total)', style: BText.title),
                const Spacer(),
                const Text('See more', style: TextStyle(fontSize: 13, color: BColors.brand, fontWeight: FontWeight.w700)),
                const Icon(Icons.chevron_right_rounded, color: BColors.brand, size: 20),
              ]),
              if (average != null) ...[
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(average.toStringAsFixed(1), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1, color: BColors.ink)),
                  const Padding(padding: EdgeInsets.only(left: 3, bottom: 3), child: Text('/5', style: BText.small)),
                  const SizedBox(width: 10),
                  StarRow(average, size: 18),
                ]),
              ],
            ]),
          ),
        ),
        if (topReviews.isEmpty)
          const Padding(padding: EdgeInsets.fromLTRB(14, 0, 14, 16), child: Align(alignment: Alignment.centerLeft, child: Text('No reviews yet. Be the first after your purchase.', style: BText.small)))
        else
          for (final r in topReviews) Column(children: [const Divider(height: 1, color: BColors.divider), ReviewTile(review: r)]),
      ]),
    );
  }

  // ---- Reviews for the whole shop ----

  void _openStoreReviews(Product p, {int? stars, bool photos = false}) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReviewsScreen(storeId: p.sellerId, initialSummary: storeSummary, initialRating: stars, initialPhotos: photos)),
      );

  Widget _storeReviewsCard(Product p) {
    final s = storeSummary;
    if (p.sellerId == null || s == null || s.total == 0) return const SizedBox.shrink();
    Widget chip(String label, {IconData? icon, Color? iconColor, required VoidCallback onTap}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(icon, size: 17, color: iconColor ?? BColors.ink), const SizedBox(width: 6)],
                  Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: BColors.ink)),
                ]),
              ),
            ),
          ),
        );
    return _card(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          onTap: () => _openStoreReviews(p),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
            child: Row(children: [
              Expanded(child: Text('Customer reviews for store (${s.total})', style: BText.title)),
              const Icon(Icons.chevron_right_rounded, color: BColors.muted),
            ]),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 0, 6, 8),
            children: [
              if (s.withImages > 0) chip('Includes visuals (${s.withImages})', icon: Icons.photo_camera_rounded, onTap: () => _openStoreReviews(p, photos: true)),
              for (final star in [5, 4, 3, 2, 1])
                if ((s.breakdown[star] ?? 0) > 0) chip('$star (${s.breakdown[star]})', icon: Icons.star_rounded, iconColor: BColors.star, onTap: () => _openStoreReviews(p, stars: star)),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ]),
    );
  }

  // ---- Shop ----

  Widget _shopCard(Product p) {
    final info = storeInfo;
    final logo = info?['logo'] as String?;
    final rating = info?['rating'] is num ? (info!['rating'] as num).toDouble() : null;
    final products = info?['productCount'];
    final followers = info?['followerCount'];
    final verified = info?['isVerified'] == true;
    final stats = [
      if (rating != null) '★ ${rating.toStringAsFixed(1)}',
      if (products is num) '${products.toInt()} products',
      if (followers is num) '${followers.toInt()} followers',
    ].join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            StoreAvatarThumb(logo: logo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(p.seller, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800))),
                  if (verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, size: 16, color: BColors.brand)),
                ]),
                const SizedBox(height: 2),
                Text(stats.isEmpty ? (p.category ?? '') : stats, maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.small),
              ]),
            ),
          ]),
          if (p.sellerId != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _openShop(p),
                  style: FilledButton.styleFrom(backgroundColor: BColors.brand, minimumSize: const Size(0, 44), shape: const StadiumBorder()),
                  child: const Text('Visit shop', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isFollowing == null || followBusy ? null : () => _toggleFollow(p.sellerId!),
                  icon: Icon(isFollowing == true ? Icons.check_rounded : Icons.add_rounded, size: 18),
                  label: Text(isFollowing == true ? 'Following' : 'Follow', style: const TextStyle(fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(foregroundColor: BColors.brand, side: const BorderSide(color: BColors.brand), minimumSize: const Size(0, 44), shape: const StadiumBorder()),
                ),
              ),
            ]),
          ],
          if (shopProducts.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('More from this shop', style: BText.section),
            const SizedBox(height: 10),
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: shopProducts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _MiniProduct(product: shopProducts[i], onTap: () => openProduct(context, shopProducts[i])),
              ),
            ),
          ],
        ]),
      ),
    ]);
  }

  // ---- Description ----

  Widget _descriptionSection(Product p) {
    final specs = [
      if (p.category != null) MapEntry('Category', p.category!),
      if (p.brand != null) MapEntry('Brand', p.brand!),
      if (p.condition != null) MapEntry('Condition', p.condition!),
      if (p.availableStock != null) MapEntry('Stock', '${p.availableStock}'),
      ...p.specifications,
    ];
    final shown = specsExpanded ? specs : specs.take(5).toList();
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('About this product', style: BText.title),
        const SizedBox(height: 12),
        const Text('Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final e in shown)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 118, child: Text(e.key, style: BText.small)),
              Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13.5, color: BColors.ink))),
            ]),
          ),
        if (specs.length > 5)
          TextButton(
            onPressed: () => setState(() => specsExpanded = !specsExpanded),
            style: TextButton.styleFrom(foregroundColor: BColors.brand, padding: EdgeInsets.zero, minimumSize: const Size(0, 36), alignment: Alignment.centerLeft),
            child: Text(specsExpanded ? 'See less' : 'See more', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        if (p.description != null && p.description!.trim().isNotEmpty) ...[
          const Divider(height: 24, color: BColors.divider),
          const Text('Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: Text(p.description!, maxLines: descriptionExpanded ? null : 6, overflow: descriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis, style: BText.body),
          ),
          if (p.description!.length > 240 || '\n'.allMatches(p.description!).length > 5)
            TextButton.icon(
              onPressed: () => setState(() => descriptionExpanded = !descriptionExpanded),
              iconAlignment: IconAlignment.end,
              icon: Icon(descriptionExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
              label: Text(descriptionExpanded ? 'See less' : 'See more', style: const TextStyle(fontWeight: FontWeight.w800)),
              style: TextButton.styleFrom(foregroundColor: BColors.brand, padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
            ),
        ],
      ]),
    );
  }

  // ---- Related ----

  Widget _relatedSection() {
    if (related.isEmpty) {
      return const SizedBox(height: 4);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 6, 16, 10), child: Text('You may also like', style: BText.title)),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: kGridPadding),
        gridDelegate: productGridDelegate(context),
        itemCount: related.length,
        itemBuilder: (_, i) => ProductCard(product: related[i], onTap: () => openProduct(context, related[i])),
      ),
    ]);
  }
}

// ============================================================
// Pieces
// ============================================================

class _TopBar extends StatelessWidget {
  const _TopBar({required this.product, required this.onBack, required this.onSearch, required this.onFavorite, required this.onCart});

  final Product product;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onFavorite;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context) {
    final store = BuyerStore.instance;
    return Container(
      color: BColors.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(children: [
            IconButton(tooltip: 'Back', onPressed: onBack, icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: BColors.ink)),
            Expanded(
              child: InkWell(
                onTap: onSearch,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(22)),
                  child: Row(children: [
                    const Icon(Icons.search_rounded, size: 20, color: BColors.brand),
                    const SizedBox(width: 8),
                    Expanded(child: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: BColors.muted))),
                  ]),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: store,
              builder: (_, __) {
                final fav = store.isFavorite(product.id);
                return IconButton(
                  tooltip: fav ? 'Remove from wishlist' : 'Add to wishlist',
                  onPressed: onFavorite,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                    child: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, key: ValueKey(fav), color: fav ? const Color(0xFFE11D48) : BColors.ink),
                  ),
                );
              },
            ),
            ListenableBuilder(
              listenable: store,
              builder: (_, __) => IconButton(
                tooltip: 'Cart',
                onPressed: onCart,
                icon: Badge(
                  isLabelVisible: store.cartCount > 0,
                  label: Text(store.cartCount > 99 ? '99+' : '${store.cartCount}'),
                  backgroundColor: const Color(0xFFDC2626),
                  child: const Icon(Icons.shopping_cart_outlined, color: BColors.ink),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ]),
        ),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
        height: 46,
        decoration: const BoxDecoration(color: BColors.surface, border: Border(bottom: BorderSide(color: BColors.border))),
        child: Row(children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Expanded(
                    child: Center(
                      child: Text(_tabs[i], style: TextStyle(fontSize: 14.5, fontWeight: i == index ? FontWeight.w800 : FontWeight.w600, color: i == index ? BColors.brand : BColors.muted)),
                    ),
                  ),
                  AnimatedContainer(duration: const Duration(milliseconds: 200), height: 3, width: i == index ? 36 : 0, decoration: BoxDecoration(color: BColors.brand, borderRadius: BorderRadius.circular(3))),
                ]),
              ),
            ),
        ]),
      );
}

/// Icon + content row inside the info card.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.child, this.onTap});

  final IconData icon;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(children: [
            Icon(icon, size: 20, color: BColors.brand),
            const SizedBox(width: 12),
            Expanded(child: child),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, color: BColors.faint),
          ]),
        ),
      );
}

/// Shop logo (fetched) with a storefront fallback.
class StoreAvatarThumb extends StatelessWidget {
  const StoreAvatarThumb({super.key, this.logo});
  final String? logo;

  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: BColors.brandSurface, shape: BoxShape.circle, border: Border.all(color: BColors.border)),
        child: NetImage(logo, fallbackIcon: Icons.storefront_rounded),
      );
}

class _MiniProduct extends StatelessWidget {
  const _MiniProduct({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (low, _) = product.priceRange;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 120,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 120, height: 120, child: NetImage(product.primaryImage, fallbackIcon: categoryIcon(product.category)))),
          const SizedBox(height: 6),
          Text(peso(low), maxLines: 1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: BColors.brand)),
          Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.tiny),
        ]),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.price, required this.soldOut, required this.onShop, required this.onChat, required this.onAddToCart, required this.onBuyNow});

  final double price;
  final bool soldOut;
  final VoidCallback? onShop;
  final VoidCallback? onChat;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  Widget _icon(IconData icon, String label, VoidCallback? onTap) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: BColors.ink, size: 23),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11, color: BColors.muted)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: BColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), boxShadow: softShadow(0.12)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: SizedBox(
              height: 52,
              child: Row(children: [
                _icon(Icons.storefront_outlined, 'Shop', onShop),
                _icon(Icons.chat_bubble_outline_rounded, 'Chat', onChat),
                const SizedBox(width: 6),
                if (!soldOut)
                  Tooltip(
                    message: 'Add to cart',
                    child: Material(
                      color: BColors.brandSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26), side: const BorderSide(color: BColors.brand, width: 1.4)),
                      child: InkWell(
                        onTap: onAddToCart,
                        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        child: const SizedBox(width: 64, height: 52, child: Icon(Icons.add_shopping_cart_rounded, color: BColors.brand, size: 24)),
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: soldOut
                      ? Container(decoration: BoxDecoration(color: BColors.border, borderRadius: BorderRadius.circular(26)), alignment: Alignment.center, child: const Text('Sold Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: BColors.muted)))
                      : Material(
                          color: BColors.brand,
                          borderRadius: BorderRadius.circular(26),
                          child: InkWell(
                            onTap: onBuyNow,
                            borderRadius: BorderRadius.circular(26),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Text('Buy now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                              Text(peso(price), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
                            ]),
                          ),
                        ),
                ),
              ]),
            ),
          ),
        ),
      );
}
