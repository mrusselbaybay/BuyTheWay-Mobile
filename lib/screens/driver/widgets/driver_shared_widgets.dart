import 'dart:async';

import 'package:flutter/material.dart';

import '../driver_models.dart';
import '../driver_theme.dart';

/// Wraps a scrollable page body in this app's pull-to-refresh gesture.
///
/// Every screen in the driver app is refreshable, so the indicator colour
/// and the "a short page must still be pullable" detail live here once
/// rather than in each screen: [child] should be a scrollable given
/// `physics: const AlwaysScrollableScrollPhysics()`, which keeps the pull
/// available even when the content doesn't overflow the viewport.
class DriverRefreshable extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const DriverRefreshable({super.key, required this.onRefresh, required this.child});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: DriverColors.primary,
      onRefresh: onRefresh,
      child: child,
    );
  }
}

/// Title + optional trailing text-button action, used above every list.
class DriverSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const DriverSectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: DriverText.sectionTitle),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: DriverColors.primary, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text(actionLabel!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class DriverEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const DriverEmptyState({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: DriverColors.primary.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]),
            child: Icon(icon, color: DriverColors.primary, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, style: DriverText.sectionTitle, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(subtitle, style: DriverText.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class DriverStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const DriverStatusBadge({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 3)],
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// The Teal gradient hero header used at the top of the "Mission Control"
/// screens (Deliveries, History, Delivery details) — one shared widget so
/// the three stay visually identical instead of drifting apart. [leading]
/// defaults to a back button when [onBack] is given, otherwise nothing;
/// pass [trailing] for a header-right action (History shortcut, etc).
class DriverGradientHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  const DriverGradientHeader({super.key, required this.title, required this.subtitle, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: DriverColors.heroGradient),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.15)),
            ),
            const SizedBox(width: 4),
          ] else
            const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 21), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Color(0xFFCCFBF1), fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small "dispatched by {logistics company}" sub-badge — the real,
/// non-fabricated stand-in for a per-dispatcher identity (see
/// [AssignedDelivery.dispatchedByLabel]'s docblock). [label] is clamped to
/// one line so a long company name can never overflow the card that hosts
/// it.
class DriverDispatchChip extends StatelessWidget {
  final String label;
  const DriverDispatchChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: DriverColors.primarySurface,
        borderRadius: BorderRadius.circular(8),
        border: const Border(bottom: BorderSide(color: DriverColors.primary, width: 1.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_shipping_outlined, size: 11, color: DriverColors.primaryDark),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Dispatched by $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: DriverColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small circular Teal-gradient call button — used wherever a card offers
/// a one-tap "call this person" quick action.
class DriverCallFab extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  const DriverCallFab({super.key, required this.onTap, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: DriverColors.primaryGradient),
          boxShadow: DriverColors.glow(DriverColors.primary, blur: 10, spread: 0),
        ),
        child: Icon(Icons.call_rounded, color: Colors.white, size: size * 0.45),
      ),
    );
  }
}

/// Skeleton block with a slow sweeping shimmer, used while any list is in
/// its (simulated) loading state.
class DriverShimmerBox extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const DriverShimmerBox({super.key, required this.height, this.width, this.radius = 10});

  @override
  State<DriverShimmerBox> createState() => _DriverShimmerBoxState();
}

class _DriverShimmerBoxState extends State<DriverShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: Container(
            height: widget.height,
            width: widget.width ?? double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + t * 3, 0),
                end: Alignment(0 + t * 3, 0),
                colors: [DriverColors.border, Colors.grey.shade50, DriverColors.border],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DriverCardSkeleton extends StatelessWidget {
  const DriverCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DriverColors.border)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DriverShimmerBox(height: 14, width: 140),
          SizedBox(height: 8),
          DriverShimmerBox(height: 11, width: 200),
          SizedBox(height: 12),
          DriverShimmerBox(height: 22, width: double.infinity),
        ],
      ),
    );
  }
}

/// A stylized, schematic pickup→dropoff visual used in place of a real
/// map (no maps SDK/API key is wired into this project). Not a literal
/// map — a deliberately abstract route card that still communicates
/// distance, direction and the two stops at a glance.
class RouteSchematic extends StatelessWidget {
  final String pickupLabel;
  final String dropoffLabel;
  final double distanceKm;
  final int etaMinutes;

  const RouteSchematic({super.key, required this.pickupLabel, required this.dropoffLabel, required this.distanceKm, required this.etaMinutes});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(18)),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _RouteGridPainter())),
          Positioned.fill(child: CustomPaint(painter: _RoutePathPainter())),
          Positioned(left: 18, top: 18, child: _pin(Icons.storefront_rounded, DriverColors.primary, pickupLabel)),
          Positioned(right: 18, bottom: 18, child: _pin(Icons.flag_rounded, DriverColors.error, dropoffLabel)),
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)]),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route_rounded, size: 13, color: DriverColors.primary),
                  const SizedBox(width: 4),
                  Text('${distanceKm.toStringAsFixed(1)} km · $etaMinutes min', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DriverColors.textPrimary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pin(IconData icon, Color color, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]),
          child: Icon(icon, color: Colors.white, size: 15),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: DriverColors.textPrimary)),
        ),
      ],
    );
  }
}

class _RouteGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DriverColors.primary.withOpacity(0.08)
      ..strokeWidth = 1;
    const step = 22.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoutePathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DriverColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(44, 52)
      ..cubicTo(size.width * 0.35, 40, size.width * 0.55, size.height - 60, size.width - 56, size.height - 46);
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 7.0;
    const dashSpace = 5.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Horizontal 4-step progress tracker for the pickup → dropoff lifecycle.
class DeliveryStageStepper extends StatelessWidget {
  final DeliveryStage stage;
  const DeliveryStageStepper({super.key, required this.stage});

  static const _stages = [
    ('To pickup', Icons.moped_rounded),
    ('At pickup', Icons.storefront_rounded),
    ('To dropoff', Icons.local_shipping_rounded),
    ('At dropoff', Icons.flag_rounded),
  ];

  int get _activeIndex {
    switch (stage) {
      case DeliveryStage.headingToPickup:
        return 0;
      case DeliveryStage.atPickup:
        return 1;
      case DeliveryStage.headingToDropoff:
        return 2;
      case DeliveryStage.atDropoff:
        return 3;
      case DeliveryStage.completed:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex;

    Widget node(int index) {
      final entry = _stages[index];
      final done = index < active;
      final isCurrent = index == active;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done || isCurrent ? DriverColors.primary : Colors.white,
              border: Border.all(color: DriverColors.primary, width: done || isCurrent ? 0 : 1.4),
              boxShadow: isCurrent ? [BoxShadow(color: DriverColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))] : null,
            ),
            child: Icon(done ? Icons.check_rounded : entry.$2, size: 16, color: done || isCurrent ? Colors.white : DriverColors.primary),
          ),
          const SizedBox(height: 5),
          Text(entry.$1, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: done || isCurrent ? DriverColors.primary : DriverColors.textSecondary)),
        ],
      );
    }

    Widget line(int index) {
      final on = index < active;
      return Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 18), color: on ? DriverColors.primary : DriverColors.border));
    }

    return Row(children: [node(0), line(0), node(1), line(1), node(2), line(2), node(3)]);
  }
}

/// Sent/received chat message bubble.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});

  String _time(DateTime t) {
    final local = t.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final mine = message.fromDriver;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: mine ? const LinearGradient(colors: DriverColors.primaryGradient) : null,
          color: mine ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: DriverColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(message.text, style: TextStyle(fontSize: 13.5, color: mine ? Colors.white : DriverColors.textPrimary, height: 1.3)),
            const SizedBox(height: 3),
            Text(_time(message.sentAt), style: TextStyle(fontSize: 9.5, color: mine ? Colors.white70 : DriverColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Circular countdown used on the request-details screen.
class CountdownRing extends StatelessWidget {
  final double progress;
  final int secondsLeft;
  const CountdownRing({super.key, required this.progress, required this.secondsLeft});

  @override
  Widget build(BuildContext context) {
    final urgent = secondsLeft <= 10;
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              backgroundColor: DriverColors.border,
              valueColor: AlwaysStoppedAnimation(urgent ? DriverColors.error : DriverColors.primary),
            ),
          ),
          Text('$secondsLeft', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: urgent ? DriverColors.error : DriverColors.primary)),
        ],
      ),
    );
  }
}

/// A modern, rounded confirmation toast that slides down from the *top* of
/// the screen and auto-dismisses — the replacement for the bottom
/// `SnackBar` the "commit" actions (pickup confirmed, delivery completed)
/// used to show. It's mounted in the root [Overlay], not the current
/// route's, so it stays on screen even when the screen that fired it is
/// popped in the same frame (as [AssignedDeliveryDetailScreen] does right
/// after a successful pickup). Tap it to dismiss early.
class DriverTopNotification {
  DriverTopNotification._();

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle_rounded,
    Color accent = DriverColors.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _DriverTopNotificationCard(
        message: message,
        icon: icon,
        accent: accent,
        duration: duration,
        onDismissed: entry.remove,
      ),
    );
    overlay.insert(entry);
  }
}

class _DriverTopNotificationCard extends StatefulWidget {
  const _DriverTopNotificationCard({
    required this.message,
    required this.icon,
    required this.accent,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final IconData icon;
  final Color accent;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_DriverTopNotificationCard> createState() => _DriverTopNotificationCardState();
}

class _DriverTopNotificationCardState extends State<_DriverTopNotificationCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  late final Animation<Offset> _slide = Tween<Offset>(begin: const Offset(0, -1.4), end: Offset.zero)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic));
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  Timer? _dismissTimer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_leaving) return;
    _leaving = true;
    _dismissTimer?.cancel();
    if (!mounted) {
      widget.onDismissed();
      return;
    }
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topInset + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: DriverColors.border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: widget.accent.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(widget.icon, color: widget.accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: DriverColors.textPrimary, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
