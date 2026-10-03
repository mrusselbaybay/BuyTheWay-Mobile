import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';

const _ratingLabels = ['', 'Terrible', 'Poor', 'Okay', 'Good', 'Amazing'];

/// Write or edit a product rating. Pass [reviewId] to edit an existing one
/// (otherwise [orderItemId] creates a new review). Resolves true on save.
Future<bool> showReviewSheet(
  BuildContext context, {
  required String productName,
  String? orderItemId,
  String? reviewId,
  int initialRating = 0,
  String? initialComment,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BRadius.md))),
    builder: (_) => _ReviewSheet(
      productName: productName,
      orderItemId: orderItemId,
      reviewId: reviewId,
      initialRating: initialRating,
      initialComment: initialComment,
    ),
  );
  return saved ?? false;
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.productName, this.orderItemId, this.reviewId, required this.initialRating, this.initialComment});

  final String productName;
  final String? orderItemId;
  final String? reviewId;
  final int initialRating;
  final String? initialComment;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final store = BuyerStore.instance;
  late int rating = widget.initialRating;
  late final comment = TextEditingController(text: widget.initialComment);
  bool saving = false;

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => saving = true);
    final text = comment.text.trim().isEmpty ? null : comment.text.trim();
    try {
      if (widget.reviewId != null) {
        await store.api.updateReview(widget.reviewId!, rating, text);
      } else {
        await store.api.createReview(widget.orderItemId!, rating, text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      showToast(context, store.handleError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.reviewId != null ? 'Edit your rating' : 'Rate this product', style: BText.title),
            const SizedBox(height: 4),
            Text(widget.productName, maxLines: 2, overflow: TextOverflow.ellipsis, style: BText.small),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return Semantics(
                  button: true,
                  label: '$star star${star > 1 ? 's' : ''}',
                  selected: rating == star,
                  child: IconButton(
                    iconSize: 38,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => rating = star);
                    },
                    icon: Icon(star <= rating ? Icons.star_rounded : Icons.star_outline_rounded, color: BColors.star),
                  ),
                );
              }),
            ),
            SizedBox(
              height: 20,
              child: Center(child: Text(_ratingLabels[rating], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: BColors.star))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: comment,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'What did you like or dislike? How was the quality and packaging?',
                hintStyle: const TextStyle(fontSize: 13, color: BColors.faint),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
                focusedBorder:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(BRadius.sm), borderSide: const BorderSide(color: BColors.brand, width: 1.5)),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: rating == 0 || saving ? null : _submit,
              style: BButtons.cta(height: 48),
              child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(rating == 0 ? 'Tap a star to rate' : 'Submit'),
            ),
          ]),
        ),
      ),
    );
  }
}
