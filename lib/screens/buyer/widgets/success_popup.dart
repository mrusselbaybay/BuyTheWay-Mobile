import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buyer_theme.dart';

/// Centered "it worked" pop-up: a green badge that pops in with a ring pulse
/// and a drawn check, a title and an optional message. Closes itself after
/// [duration] (tap anywhere to close sooner).
Future<void> showSuccessPopup(
  BuildContext context, {
  required String title,
  String? message,
  Duration duration = const Duration(milliseconds: 2200),
}) async {
  HapticFeedback.mediumImpact();
  final timer = Timer(duration, () {
    if (context.mounted) Navigator.of(context, rootNavigator: true).maybePop();
  });
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => _SuccessCard(title: title, message: message),
    transitionBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(scale: Tween(begin: 0.86, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)), child: child),
    ),
  );
  timer.cancel();
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.title, this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).maybePop(),
            child: Container(
              width: 300,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: softShadow(0.25)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const _CheckBadge(),
                const SizedBox(height: 20),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: BColors.ink)),
                if (message != null && message!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(message!, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, height: 1.4, color: BColors.muted)),
                ],
              ]),
            ),
          ),
        ),
      );
}

/// Green disc with an expanding ring and a check that draws itself.
class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          final pop = Curves.elasticOut.transform((t * 1.4).clamp(0.0, 1.0));
          final draw = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
          return SizedBox(
            width: 96,
            height: 96,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: 96 * (0.7 + 0.3 * t),
                height: 96 * (0.7 + 0.3 * t),
                decoration: BoxDecoration(shape: BoxShape.circle, color: BColors.success.withValues(alpha: 0.12 * (1 - t) + 0.08)),
              ),
              Transform.scale(
                scale: pop,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF22C55E), Color(0xFF15803D)])),
                  child: CustomPaint(painter: _CheckPainter(draw)),
                ),
              ),
            ]),
          );
        },
      );
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.73, size.height * 0.36);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.progress != progress;
}
