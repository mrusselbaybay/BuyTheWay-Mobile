import 'package:flutter/material.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';

/// All reviews for a product with the familiar star / with-photos filters.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, required this.productId, this.initialSummary});

  final String productId;
  final ReviewSummary? initialSummary;

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
  int? rating;
  bool withImages = false;

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
      final (items, s, last) = await store.api.productReviews(widget.productId, page: page + 1, rating: rating, withImages: withImages);
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

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Scaffold(
      backgroundColor: BColors.background,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        surfaceTintColor: BColors.surface,
        foregroundColor: BColors.ink,
        title: const Text('Ratings & Reviews', style: BText.title),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 400 && error == null) _load();
          return false;
        },
        child: CustomScrollView(slivers: [
          if (s != null)
            SliverToBoxAdapter(
              child: Panel(
                child: Row(children: [
                  Column(children: [
                    Text(s.average?.toStringAsFixed(1) ?? '–', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: BColors.ink)),
                    StarRow(s.average ?? 0, size: 16),
                    const SizedBox(height: 4),
                    Text('${s.total} ratings', style: BText.tiny),
                  ]),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [5, 4, 3, 2, 1].map((star) {
                        final count = s.breakdown[star] ?? 0;
                        final ratio = s.total == 0 ? 0.0 : count / s.total;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            SizedBox(width: 14, child: Text('$star', style: BText.tiny)),
                            const Icon(Icons.star_rounded, size: 12, color: BColors.star),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: BColors.divider, color: BColors.star),
                              ),
                            ),
                            SizedBox(width: 34, child: Text('$count', textAlign: TextAlign.right, style: BText.tiny)),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
                ]),
              ),
            ),
          SliverToBoxAdapter(
            child: Container(
              color: BColors.surface,
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _chip('All', rating == null && !withImages, () => _setFilter()),
                  _chip('With photos${s != null ? ' (${s.withImages})' : ''}', withImages, () => _setFilter(photos: true)),
                  for (final star in [5, 4, 3, 2, 1]) _chip('$star ★${s != null ? ' (${s.breakdown[star] ?? 0})' : ''}', rating == star, () => _setFilter(stars: star)),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: Divider(height: 1, color: BColors.divider)),
          if (reviews.isEmpty && loading)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: BColors.brand)))
          else if (reviews.isEmpty && error != null)
            SliverFillRemaining(hasScrollBody: false, child: ErrorState(message: error!, onRetry: () => _load(reset: true)))
          else if (reviews.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: Icons.rate_review_outlined, title: 'No reviews here yet', message: 'Try another filter.'),
            )
          else ...[
            SliverList.separated(
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: BColors.divider),
              itemBuilder: (_, i) => ReviewTile(review: reviews[i]),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 64,
                child: Center(
                  child: loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: BColors.brand))
                      : error != null
                          ? TextButton(onPressed: _load, child: const Text('Couldn\'t load more — retry'))
                          : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: active,
          showCheckmark: false,
          onSelected: (_) => onTap(),
          backgroundColor: BColors.background,
          selectedColor: BColors.brandSurface,
          side: BorderSide(color: active ? BColors.brand : Colors.transparent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
          labelStyle: TextStyle(fontSize: 12.5, color: active ? BColors.brand : BColors.ink),
        ),
      );
}

class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BColors.surface,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: BColors.brandSurface,
            child: Text(review.author.characters.first.toUpperCase(), style: const TextStyle(fontSize: 12, color: BColors.brand, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(review.author, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Text(formatDate(review.createdAt), style: BText.tiny),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          StarRow(review.rating.toDouble(), size: 14),
          if (review.verifiedPurchase) ...[
            const SizedBox(width: 8),
            const Icon(Icons.verified, size: 13, color: BColors.success),
            const SizedBox(width: 2),
            const Text('Verified purchase', style: TextStyle(fontSize: 11, color: BColors.success)),
          ],
        ]),
        if (review.variant != null) ...[
          const SizedBox(height: 4),
          Text('Variation: ${review.variant}', style: BText.tiny),
        ],
        if (review.comment != null) ...[
          const SizedBox(height: 8),
          Text(review.comment!, style: BText.body),
        ],
        if (review.images.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: review.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    insetPadding: const EdgeInsets.all(12),
                    backgroundColor: Colors.black,
                    child: InteractiveViewer(child: NetImage(review.images[i], fit: BoxFit.contain)),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BRadius.sm),
                  child: SizedBox(width: 72, height: 72, child: NetImage(review.images[i])),
                ),
              ),
            ),
          ),
        ],
        if (review.sellerResponse != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: BColors.background,
            child: Text.rich(TextSpan(children: [
              const TextSpan(text: 'Seller\'s response: ', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: review.sellerResponse),
            ]), style: const TextStyle(fontSize: 12.5, color: BColors.ink, height: 1.35)),
          ),
        ],
      ]),
    );
  }
}
