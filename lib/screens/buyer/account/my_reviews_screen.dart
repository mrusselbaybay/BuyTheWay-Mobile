import 'package:flutter/material.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../orders/review_sheet.dart';
import '../product/product_detail_screen.dart';
import '../widgets/buyer_widgets.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final store = BuyerStore.instance;
  List<MyReview>? reviews;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final list = await store.api.myReviews();
      if (mounted) setState(() => reviews = list);
    } catch (e) {
      if (mounted) setState(() => error = store.handleError(e));
    }
  }

  Future<void> _edit(MyReview r) async {
    final saved = await showReviewSheet(context, productName: r.productName, reviewId: r.id, initialRating: r.rating, initialComment: r.comment);
    if (saved && mounted) {
      showToast(context, 'Rating updated');
      _load();
    }
  }

  Future<void> _delete(MyReview r) async {
    final ok = await confirmDialog(context, title: 'Delete this review?', message: 'Your rating for ${r.productName} will be removed.', confirmLabel: 'Delete', destructive: true);
    if (!ok) return;
    final previous = reviews;
    setState(() => reviews = reviews?.where((x) => x.id != r.id).toList());
    try {
      await store.api.deleteReview(r.id);
      if (mounted) showToast(context, 'Review deleted');
    } catch (e) {
      if (!mounted) return;
      setState(() => reviews = previous);
      showToast(context, store.handleError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = reviews;
    return Scaffold(
      backgroundColor: BColors.background,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        surfaceTintColor: BColors.surface,
        foregroundColor: BColors.ink,
        title: const Text('My Reviews', style: BText.title),
      ),
      body: list == null
          ? (error != null ? ErrorState(message: error!, onRetry: _load) : const Center(child: CircularProgressIndicator(color: BColors.brand)))
          : RefreshIndicator(
              color: BColors.brand,
              onRefresh: _load,
              child: list.isEmpty
                  ? ListView(children: const [
                      SizedBox(
                        height: 420,
                        child: EmptyState(
                          icon: Icons.rate_review_outlined,
                          title: 'No reviews yet',
                          message: 'Rate items from your delivered orders to help other shoppers.',
                        ),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final r = list[i];
                        return Panel(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            InkWell(
                              onTap: r.productId == null
                                  ? null
                                  : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: r.productId!))),
                              child: Row(children: [
                                CategoryThumb(category: r.category, image: r.image, size: 48),
                                const SizedBox(width: 10),
                                Expanded(child: Text(r.productName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5))),
                              ]),
                            ),
                            const SizedBox(height: 10),
                            Row(children: [
                              StarRow(r.rating.toDouble(), size: 16),
                              const SizedBox(width: 8),
                              Text('${formatDate(r.createdAt)}${r.isEdited ? ' · Edited' : ''}', style: BText.tiny),
                              const Spacer(),
                              IconButton(tooltip: 'Edit', visualDensity: VisualDensity.compact, onPressed: () => _edit(r), icon: const Icon(Icons.edit_outlined, size: 19, color: BColors.brand)),
                              IconButton(tooltip: 'Delete', visualDensity: VisualDensity.compact, onPressed: () => _delete(r), icon: const Icon(Icons.delete_outline, size: 19, color: BColors.muted)),
                            ]),
                            if (r.comment != null) Text(r.comment!, style: BText.body),
                            if (r.sellerResponse != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                color: BColors.background,
                                child: Text.rich(
                                  TextSpan(children: [
                                    const TextSpan(text: 'Seller\'s response: ', style: TextStyle(fontWeight: FontWeight.w700)),
                                    TextSpan(text: r.sellerResponse),
                                  ]),
                                  style: const TextStyle(fontSize: 12.5, height: 1.35),
                                ),
                              ),
                            ],
                          ]),
                        );
                      },
                    ),
            ),
    );
  }
}
