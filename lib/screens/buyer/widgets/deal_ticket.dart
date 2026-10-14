import 'package:flutter/material.dart';

import '../buyer_models.dart';
import '../buyer_theme.dart';

/// Compact claimable voucher: tinted stub, dashed seam, details and a Claim button.
class DealTicket extends StatelessWidget {
  const DealTicket({super.key, required this.coupon, required this.claimed, required this.claiming, required this.onClaim, this.onUse});

  final Coupon coupon;
  final bool claimed;
  final bool claiming;
  final VoidCallback onClaim;

  /// When set, a claimed voucher shows a "Use" button instead of "Claimed".
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final shipping = coupon.isShipping;
    final accent = shipping ? BColors.brand : const Color(0xFFDC2626);
    final soft = shipping ? BColors.brandSurface : const Color(0xFFFEF2F2);
    final border = shipping ? const Color(0xFF99F6E4) : const Color(0xFFFECACA);
    return Container(
      width: 300,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        Container(
          width: 78,
          color: soft,
          alignment: Alignment.center,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(shipping ? Icons.local_shipping_rounded : Icons.sell_rounded, color: accent, size: 24),
            const SizedBox(height: 4),
            Text(shipping ? 'Shipping' : 'Discount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent)),
          ]),
        ),
        SizedBox(width: 1, height: double.infinity, child: CustomPaint(painter: DealDashPainter(border))),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            child: Row(children: [
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(coupon.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: accent)),
                  const SizedBox(height: 2),
                  Text(coupon.minSpend > 0 ? 'on orders ${pesoCompact(coupon.minSpend)}+' : 'No minimum spend', maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.small),
                  if (coupon.expiresAt != null) Text('Till ${formatDate(coupon.expiresAt)}', style: BText.tiny),
                ]),
              ),
              const SizedBox(width: 8),
              claimed && onUse != null
                  ? OutlinedButton(
                      onPressed: onUse,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent, width: 1.3),
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Use', style: TextStyle(fontWeight: FontWeight.w800)),
                    )
                  : claimed
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(border: Border.all(color: BColors.border), borderRadius: BorderRadius.circular(999)),
                      child: const Text('Claimed', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: BColors.muted)),
                    )
                  : FilledButton(
                      onPressed: claiming ? null : onClaim,
                      style: FilledButton.styleFrom(backgroundColor: BColors.brand, minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 16), shape: const StadiumBorder()),
                      child: claiming ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Claim', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class DealDashPainter extends CustomPainter {
  const DealDashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    for (double y = 6; y < size.height - 6; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant DealDashPainter old) => old.color != color;
}

