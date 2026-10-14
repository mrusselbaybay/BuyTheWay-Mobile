import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../cart/cart_screen.dart';
import '../widgets/buyer_widgets.dart';

/// All reviews for a product: "Reviews (n)" header with the wishlist heart
/// and cart, filter chips (with photos / by star, each with its count), and
/// the newest-first review list.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen(
      {super.key,
      this.productId,
      this.storeId,
      this.initialSummary,
      this.initialRating,
      this.initialPhotos = false})
      : assert(productId != null || storeId != null);

  /// One of these: a product's reviews, or a shop's reviews across all its products.
  final String? productId;
  final String? storeId;
  final ReviewSummary? initialSummary;
  final int? initialRating;
  final bool initialPhotos;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final store = BuyerStore.instance;
  late ReviewSummary? summary = widget.initialSummary;
  final List<Review> reviews = [];
  int page = 0;
  int lastPage = 1;
  bool loading = false;
  String? error;
  late int? rating = widget.initialRating;
  late bool withImages = widget.initialPhotos;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (loading) return;
    if (reset) {
      reviews.clear();
      page = 0;
      lastPage = 1;
    }
    if (page >= lastPage) return;
    setState(() {
      loading = true;
      error = null;
    });
    final requestedFilter = (rating, withImages);
    try {
      final (items, s, last) = widget.storeId != null
          ? await store.api.storeReviews(widget.storeId!,
              page: page + 1, rating: rating, withImages: withImages)
          : await store.api.productReviews(widget.productId!,
              page: page + 1, rating: rating, withImages: withImages);
      if (!mounted || requestedFilter != (rating, withImages)) return;
      setState(() {
        reviews.addAll(items);
        summary = s;
        page++;
        lastPage = last;
      });
    } catch (e) {
      if (mounted) setState(() => error = store.handleError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _setFilter({int? stars, bool photos = false}) {
    if (rating == stars && withImages == photos) return;
    setState(() {
      rating = stars;
      withImages = photos;
      loading = false;
    });
    _load(reset: true);
  }

  Future<void> _toggleFavorite() async {
    final failure = await store.toggleFavorite(widget.productId!);
    if (failure != null && mounted) showToast(context, failure, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Scaffold(
      backgroundColor: BColors.surface,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        surfaceTintColor: BColors.surface,
        foregroundColor: BColors.ink,
        elevation: 0,
        centerTitle: true,
        title: Text(
            '${widget.storeId != null ? 'Store reviews' : 'Reviews'}${s != null ? ' (${s.total})' : ''}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          if (widget.productId != null)
            ListenableBuilder(
              listenable: store,
              builder: (_, __) {
                final fav = store.isFavorite(widget.productId!);
                return IconButton(
                  tooltip: fav ? 'Remove from wishlist' : 'Add to wishlist',
                  onPressed: _toggleFavorite,
                  icon: Icon(
                      fav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: fav ? const Color(0xFFE11D48) : BColors.ink),
                );
              },
            ),
          ListenableBuilder(
            listenable: store,
            builder: (_, __) => IconButton(
              tooltip: 'Cart',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CartScreen(standalone: true))),
              icon: Badge(
                isLabelVisible: store.cartCount > 0,
                label:
                    Text(store.cartCount > 99 ? '99+' : '${store.cartCount}'),
                backgroundColor: const Color(0xFFDC2626),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 400 && error == null) _load();
          return false;
        },
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                children: [
                  _chip(
                      label: 'All',
                      active: rating == null && !withImages,
                      onTap: () => _setFilter()),
                  if (s != null && s.withImages > 0)
                    _chip(
                        icon: Icons.photo_camera_rounded,
                        label: 'Includes visuals (${s.withImages})',
                        active: withImages,
                        onTap: () => _setFilter(photos: true)),
                  for (final star in [5, 4, 3, 2, 1])
                    if (s == null || (s.breakdown[star] ?? 0) > 0)
                      _chip(
                          icon: Icons.star_rounded,
                          iconColor: BColors.star,
                          label:
                              '$star${s != null ? ' (${s.breakdown[star] ?? 0})' : ''}',
                          active: rating == star,
                          onTap: () => _setFilter(stars: star)),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(children: [
                Flexible(
                    child: Text('See what other customers are saying',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BText.small)),
                SizedBox(width: 4),
                Tooltip(
                  message:
                      'Reviews are written by buyers after their order is delivered.',
                  triggerMode: TooltipTriggerMode.tap,
                  child: Icon(Icons.info_outline_rounded,
                      size: 15, color: BColors.muted),
                ),
                Spacer(),
                Text('Newest',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BColors.ink)),
                SizedBox(width: 4),
                Icon(Icons.schedule_rounded, size: 16, color: BColors.ink),
              ]),
            ),
          ),
          const SliverToBoxAdapter(
              child: Divider(height: 1, color: BColors.divider)),
          if (reviews.isEmpty && loading)
            const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: CircularProgressIndicator(color: BColors.brand)))
          else if (reviews.isEmpty && error != null)
            SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                    message: error!, onRetry: () => _load(reset: true)))
          else if (reviews.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                  icon: Icons.rate_review_outlined,
                  title: 'No reviews here yet',
                  message: 'Try another filter.'),
            )
          else ...[
            SliverList.separated(
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1, indent: 16, endIndent: 16, color: BColors.divider),
              itemBuilder: (_, i) => ReviewTile(
                  review: reviews[i], showProduct: widget.storeId != null),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 64,
                child: Center(
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: BColors.brand))
                      : error != null
                          ? TextButton(
                              onPressed: _load,
                              child: const Text('Couldn\'t load more — retry'))
                          : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _chip(
          {required String label,
          required bool active,
          required VoidCallback onTap,
          IconData? icon,
          Color? iconColor}) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: active ? BColors.brandSurface : const Color(0xFFF1F5F9),
          shape: StadiumBorder(
              side: BorderSide(
                  color: active ? BColors.brand : Colors.transparent,
                  width: 1.4)),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 17,
                      color:
                          iconColor ?? (active ? BColors.brand : BColors.ink)),
                  const SizedBox(width: 6)
                ],
                Text(label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        color: active ? BColors.brandDark : BColors.ink)),
              ]),
            ),
          ),
        ),
      );
}

/// One review: the reviewer's photo (or initial) and name, stars · item, text
/// (with "Show more"), photos, the seller's reply, the date and a like button.
class ReviewTile extends StatefulWidget {
  const ReviewTile({super.key, required this.review, this.showProduct = false});

  final Review review;

  /// Names the product the review is for (store-wide lists).
  final bool showProduct;

  @override
  State<ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends State<ReviewTile> {
  late int likes = widget.review.helpfulCount;
  late bool liked = widget.review.isHelpful;
  bool busy = false;

  Future<void> _toggleLike() async {
    if (busy) return;
    final store = BuyerStore.instance;
    final next = !liked;
    setState(() {
      busy = true;
      liked = next;
      likes += next ? 1 : -1;
    });
    HapticFeedback.selectionClick();
    try {
      final (count, isLiked) = await store.api.setReviewLike(widget.review.id, next);
      if (mounted) {
        setState(() {
          likes = count;
          liked = isLiked;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          liked = !next;
          likes += next ? -1 : 1;
        });
        showToast(context, store.handleError(e), error: true);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _avatar(Review r) {
    final initial = r.author.trim().isEmpty ? '?' : r.author.characters.first.toUpperCase();
    final fallback = Container(
      color: BColors.brandSurface,
      alignment: Alignment.center,
      child: r.anonymous ? const Icon(Icons.person_rounded, size: 22, color: BColors.brand) : Text(initial, style: const TextStyle(fontSize: 15, color: BColors.brandDark, fontWeight: FontWeight.w800)),
    );
    return ClipOval(
      child: SizedBox(width: 38, height: 38, child: r.avatarUrl != null && r.avatarUrl!.isNotEmpty ? NetImage(r.avatarUrl, fallbackIcon: Icons.person_rounded) : fallback),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    return Container(
      color: BColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _avatar(r),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: BColors.ink)),
              const SizedBox(height: 3),
              Row(children: [
                StarRow(r.rating.toDouble(), size: 15),
                if (r.variant != null && r.variant!.isNotEmpty) ...[
                  const Text('  ·  ', style: TextStyle(color: BColors.faint)),
                  Flexible(child: Text('Item: ${r.variant}', maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.small)),
                ],
              ]),
            ]),
          ),
          if (r.verifiedPurchase) const Tooltip(message: 'Verified purchase', child: Icon(Icons.verified_rounded, size: 18, color: BColors.brand)),
        ]),
        if (widget.showProduct && r.productName != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.inventory_2_outlined, size: 14, color: BColors.muted),
            const SizedBox(width: 5),
            Expanded(child: Text(r.productName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.small)),
          ]),
        ],
        if (r.comment != null && r.comment!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _ExpandableText(r.comment!.trim()),
        ],
        if (r.images.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: r.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog.fullscreen(
                    backgroundColor: Colors.black,
                    child: Stack(children: [
                      Positioned.fill(child: InteractiveViewer(child: NetImage(r.images[i], fit: BoxFit.contain))),
                      SafeArea(child: Align(alignment: Alignment.topRight, child: IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)))),
                    ]),
                  ),
                ),
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 92, height: 92, child: NetImage(r.images[i]))),
              ),
            ),
          ),
        ],
        if (r.sellerResponse != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(12)),
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Seller response: ', style: TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: r.sellerResponse),
              ]),
              style: const TextStyle(fontSize: 12.5, color: BColors.ink, height: 1.4),
            ),
          ),
        ],
        Row(children: [
          Expanded(child: Text(formatDate(r.createdAt), style: BText.small)),
          Semantics(
            button: true,
            label: liked ? 'Remove helpful mark' : 'Mark as helpful',
            child: InkWell(
              onTap: r.canLike ? _toggleLike : () => showToast(context, 'Sign in as a buyer to mark reviews helpful.'),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                    child: Icon(liked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, key: ValueKey(liked), size: 21, color: liked ? BColors.brand : BColors.muted),
                  ),
                  if (likes > 0) ...[const SizedBox(width: 6), Text('$likes', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: liked ? BColors.brand : BColors.muted))],
                ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Review text cut to three lines with a "Show more" / "Show less" toggle
/// (only when it actually overflows).
class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);
  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool expanded = false;
  static const _style =
      TextStyle(fontSize: 14.5, height: 1.45, color: BColors.ink);

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final painter = TextPainter(
            text: TextSpan(text: widget.text, style: _style),
            maxLines: 3,
            textDirection: TextDirection.ltr)
          ..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.text,
              maxLines: expanded ? null : 3,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: _style),
          if (overflows)
            GestureDetector(
              onTap: () => setState(() => expanded = !expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(expanded ? 'Show less' : 'Show more',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: BColors.brand)),
              ),
            ),
        ]);
      });
}
