import 'package:flutter/material.dart';

import '../buyer_models.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';

/// Where a return / refund request stands — mirrors the web
/// ReturnTrackingModal. Read-only: it shows what the order payload already
/// carries, so opening it costs no request.
Future<void> showReturnTrackingSheet(BuildContext context, OrderItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: BColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => ReturnTrackingSheet(item: item),
  );
}

/// Badge copy and colours for a request — shared by the sheet and the
/// summary row so they never disagree.
({String label, Color color, Color surface}) returnBadge(ReturnRequestInfo r) {
  switch (r.state) {
    case 'rejected':
      return (label: 'Rejected', color: BColors.error, surface: BColors.errorSurface);
    case 'cancelled':
      return (label: 'Cancelled', color: BColors.muted, surface: BColors.divider);
    case 'completed':
      return (label: r.isReturn ? 'Returned & refunded' : 'Refunded', color: BColors.success, surface: BColors.successSurface);
    case 'approved':
      return r.isReturn
          ? (label: 'Approved · awaiting return', color: BColors.brand, surface: BColors.brandSurface)
          : (label: 'Refunded', color: BColors.success, surface: BColors.successSurface);
    default:
      return (label: 'Pending', color: BColors.warning, surface: BColors.warningSurface);
  }
}

String _summary(ReturnRequestInfo r) => switch (r.state) {
      'approved' => r.isReturn
          ? 'The seller approved your request. A courier will collect the item; you are refunded once it reaches the seller.'
          : 'The seller approved your request and the refund is on its way.',
      'completed' => 'The item was returned and your refund is complete.',
      'cancelled' => 'This request was cancelled.',
      'rejected' => 'The seller declined this request.',
      _ => 'Waiting for the seller to review your request.',
    };

const _reasons = {
  'damaged': 'Product arrived damaged',
  'wrong_item': 'Wrong product received',
  'incomplete': 'Missing parts or items',
  'not_as_described': 'Product is not as described',
  'quality_issue': 'Product quality issue',
};

String _reasonLabel(ReturnRequestInfo r) => r.reason == 'other' && r.otherReason != null ? r.otherReason! : _reasons[r.reason] ?? 'Other reason';

class ReturnTrackingSheet extends StatelessWidget {
  const ReturnTrackingSheet({super.key, required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final r = item.returnRequest;
    final badge = r == null ? null : returnBadge(r);
    final rejected = r?.state == 'rejected';
    final refunded = r != null && r.refundedAmount != null && (r.state == 'approved' || r.state == 'completed');
    final steps = <(String, DateTime?)>[
      if (r != null) ('Submitted', r.submittedAt),
      if (r != null && r.state != 'pending') (rejected ? 'Declined' : 'Reviewed', r.resolvedAt),
      if (r != null && r.isReturn) ('Item returned', r.returnedAt),
    ].where((s) => s.$2 != null).toList();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: BColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Track request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BColors.ink)),
          const SizedBox(height: 16),
          if (r == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No return or refund request for this item.', style: BText.small)),
            )
          else ...[
            Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: BColors.divider)),
                child: ClipRRect(borderRadius: BorderRadius.circular(11), child: NetImage(item.image, fallbackIcon: categoryIcon(item.category))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: BColors.ink)),
                  const SizedBox(height: 2),
                  Text('${r.isReturn ? 'Return and refund' : 'Refund only'} · Qty ${r.quantity}', style: BText.small),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: badge!.surface, borderRadius: BorderRadius.circular(999)),
                child: Text(badge.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: badge.color)),
              ),
            ]),
            const SizedBox(height: 14),
            Text(_summary(r), style: BText.body),
            // Why the seller declined: the thing the buyer most needs to see.
            if (rejected) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BColors.errorSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.error_outline_rounded, size: 20, color: BColors.error),
                      SizedBox(width: 8),
                      Text('Reason for rejection', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: BColors.error)),
                    ]),
                    const SizedBox(height: 8),
                    SelectableText(
                      r.resolutionNote ?? 'The seller did not leave a reason.',
                      style: const TextStyle(fontSize: 14.5, height: 1.45, color: BColors.ink),
                    ),
                  ]),
                ),
              ),
            ] else if (refunded) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BColors.successSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BColors.success.withValues(alpha: 0.35)),
                ),
                child: Row(children: [
                  const Expanded(child: Text('Refund amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: BColors.success))),
                  Text(peso(r.refundedAmount!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BColors.success)),
                ]),
              ),
            ],
            const SizedBox(height: 18),
            const Text('Reason', style: BText.tiny),
            const SizedBox(height: 2),
            Text(_reasonLabel(r), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: BColors.ink)),
            if (r.details != null) ...[
              const SizedBox(height: 14),
              const Text('Your details', style: BText.tiny),
              const SizedBox(height: 2),
              Text(r.details!, style: BText.body),
            ],
            if (r.evidence.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Evidence', style: BText.tiny),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < r.evidence.length; i++)
                  Semantics(
                    label: 'Open evidence photo ${i + 1}',
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openPhoto(context, r.evidence[i]),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: BColors.border)),
                        child: ClipRRect(borderRadius: BorderRadius.circular(11), child: NetImage(r.evidence[i], fallbackIcon: Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
              ]),
            ],
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: BColors.divider),
              const SizedBox(height: 12),
              for (final (label, at) in steps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(child: Text(label, style: BText.small)),
                    Text(formatDate(at), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: BColors.ink)),
                  ]),
                ),
            ],
          ],
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ]),
      ),
    );
  }

  void _openPhoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (dialog) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(children: [
          Positioned.fill(child: InteractiveViewer(child: NetImage(url, fit: BoxFit.contain, fallbackIcon: Icons.broken_image_outlined))),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), tooltip: 'Close', onPressed: () => Navigator.pop(dialog)),
            ),
          ),
        ]),
      ),
    );
  }
}
