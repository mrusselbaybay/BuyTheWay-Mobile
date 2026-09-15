import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../chat/chat_models.dart';
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

/// A small circular outlined button — the secondary counterpart to
/// [DriverCallFab] (that one's solid teal gradient stays the primary
/// action) wherever a contact card also offers a one-tap "message this
/// person" quick action.
class DriverMessageFab extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  const DriverMessageFab({super.key, required this.onTap, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DriverColors.primarySurface,
          border: Border.all(color: DriverColors.primary.withOpacity(0.3)),
        ),
        child: Icon(Icons.chat_bubble_outline_rounded, color: DriverColors.primary, size: size * 0.42),
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

/// Shimmering placeholder message bubbles, shaped like a real thread
/// (alternating sides, varied widths) — shown the instant a conversation
/// screen opens while its real messages are still in flight, instead of a
/// bare spinner. Used both by [DriverChatConversationScreen] (opening any
/// thread that has nothing cached yet) and by the "Message" button's
/// create-then-open flow on the delivery-detail screen.
class DriverChatSkeleton extends StatelessWidget {
  const DriverChatSkeleton({super.key});

  static const _bubbles = [
    (mine: false, width: 0.55),
    (mine: false, width: 0.38),
    (mine: true, width: 0.5),
    (mine: false, width: 0.62),
    (mine: true, width: 0.34),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final b in _bubbles) ...[
          Align(
            alignment: b.mine ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: b.width,
              alignment: b.mine ? Alignment.centerRight : Alignment.centerLeft,
              child: const DriverShimmerBox(height: 38, radius: 16),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Matches [DriverChatConversationScreen]'s real app bar layout (avatar +
/// two text lines) so the transition from "resolving the conversation" to
/// "conversation loaded" doesn't jump — used only while the conversation
/// itself doesn't exist yet client-side (the very first "Message" tap for
/// a delivery contact), never for a normal inbox open, which already has a
/// real conversation (and usually cached messages) to show immediately.
class DriverChatHeaderSkeleton extends StatelessWidget {
  const DriverChatHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        DriverShimmerBox(height: 34, width: 34, radius: 17),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DriverShimmerBox(height: 13, width: 110),
              SizedBox(height: 6),
              DriverShimmerBox(height: 10, width: 60),
            ],
          ),
        ),
      ],
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

/// Employer avatar used by both the inbox row and the conversation header —
/// a real photo (`ChatConversation.employerAvatarUrl`, the logistics
/// company owner's uploaded avatar) when one exists, falling back to the
/// same gradient-circle + business icon/initial placeholder used before
/// avatars were fetched at all.
class ChatAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double size;
  final bool online;
  final bool priority;
  final String fallbackText;

  const ChatAvatar({
    super.key,
    required this.avatarUrl,
    required this.size,
    this.online = false,
    this.priority = false,
    this.fallbackText = '?',
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = avatarUrl?.isNotEmpty == true;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: hasUrl
              ? Image.network(
                  avatarUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null ? child : _fallback(),
                  errorBuilder: (context, error, stack) => _fallback(),
                )
              : _fallback(),
        ),
        if (online)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(color: DriverColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            ),
          ),
      ],
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(gradient: LinearGradient(colors: DriverColors.primaryGradient), shape: BoxShape.circle),
      child: priority
          ? Icon(Icons.business_rounded, color: Colors.white, size: size * 0.46)
          : Text(fallbackText, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

/// Sent/received chat message bubble. [onRetry] is only used when
/// [message] is [MessageStatus.failed] — shows a "Failed · Retry" row
/// instead of the timestamp.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;
  const ChatBubble({super.key, required this.message, this.onRetry});

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
    final sending = message.status == MessageStatus.sending;
    final failed = message.status == MessageStatus.failed;
    final hasAttachments = message.attachments.isNotEmpty;
    final hasText = message.text.isNotEmpty;
    final hasContext = message.orderContext != null || message.productContext != null;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 260),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // A pure "Inquire about a certain parcel" card — the whole
            // message IS the card, no text bubble alongside it (mirrors
            // Chat.vue's identical inline-inquiry-card treatment).
            if (message.isInquiry) ...[
              _InquiryCard(message: message),
              const SizedBox(height: 3),
            ]
            // Otherwise, if this text/attachment message still points at a
            // specific order/product (the picker was used before typing),
            // show a small "Regarding" chip above the normal bubble instead
            // of the full-size card.
            else if (hasContext) ...[
              _RegardingChip(message: message),
              const SizedBox(height: 4),
            ],
            // Attachments render bare (no bubble chrome), fixed-size cards
            // laid out horizontally — mirrors the web inbox's Messenger-style
            // `.msg-attachments` grid instead of stretching to fit inside a
            // text bubble.
            if (hasAttachments) ...[
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 6,
                children: message.attachments.map((a) => _AttachmentCard(attachment: a)).toList(),
              ),
              if (hasText) const SizedBox(height: 4),
            ],
            if (hasText)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: mine && !failed ? const LinearGradient(colors: DriverColors.primaryGradient) : null,
                  color: failed ? DriverColors.errorSurface : (mine ? null : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(mine ? 16 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 16),
                  ),
                  border: (mine && !failed) ? null : Border.all(color: failed ? DriverColors.error.withOpacity(0.3) : DriverColors.border),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Text(
                  message.text,
                  style: TextStyle(fontSize: 13.5, color: failed ? DriverColors.error : (mine ? Colors.white : DriverColors.textPrimary), height: 1.3),
                ),
              ),
            const SizedBox(height: 3),
            if (sending)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 9, height: 9, child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(DriverColors.textSecondary.withOpacity(0.6)))),
                  const SizedBox(width: 5),
                  const Text('Sending…', style: TextStyle(fontSize: 9.5, color: DriverColors.textSecondary)),
                ],
              )
            else if (failed)
              GestureDetector(
                onTap: onRetry,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 12, color: DriverColors.error),
                    const SizedBox(width: 4),
                    const Text('Failed to send', style: TextStyle(fontSize: 10, color: DriverColors.error, fontWeight: FontWeight.w600)),
                    if (onRetry != null) ...[
                      const SizedBox(width: 6),
                      const Text('Retry', style: TextStyle(fontSize: 10, color: DriverColors.error, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                    ],
                  ],
                ),
              )
            else
              Text(_time(message.sentAt), style: const TextStyle(fontSize: 9.5, color: DriverColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// The full-size "Inquiring About" card for a pure inquiry message (no
/// typed text) — mirrors Chat.vue's inline inquiry card: a thumbnail, the
/// product name (or order number if no specific product was picked),
/// qty/price, and the tracking number when known.
class _InquiryCard extends StatelessWidget {
  final ChatMessage message;
  const _InquiryCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final product = message.productContext;
    final order = message.orderContext;
    final image = product?.image ?? order?.previewImage;
    final title = product?.name ?? (order != null ? 'Order #${order.orderNumber}' : 'Order');
    final trackingNumber = product?.trackingNumber;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DriverColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InquiryThumbnail(url: image, size: 56),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('INQUIRING ABOUT', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: DriverColors.primary)),
                const SizedBox(height: 2),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: DriverColors.textPrimary)),
                if (product != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Qty: ${product.quantity ?? 1} · ₱${product.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, color: DriverColors.textSecondary)),
                  )
                else if (order != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${order.itemCount} item${order.itemCount == 1 ? '' : 's'} · ₱${order.total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11.5, color: DriverColors.textSecondary),
                    ),
                  ),
                if (trackingNumber != null && trackingNumber.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('TN: $trackingNumber', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: DriverColors.textSecondary)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact chip shown above a normal text/attachment bubble when that
/// message is still tagged with a specific order/product — the smaller
/// counterpart to [_InquiryCard], used when the buyer typed a message
/// alongside picking an order.
class _RegardingChip extends StatelessWidget {
  final ChatMessage message;
  const _RegardingChip({required this.message});

  @override
  Widget build(BuildContext context) {
    final product = message.productContext;
    final order = message.orderContext;
    final image = product?.image ?? order?.previewImage;
    final title = product?.name ?? (order != null ? 'Order #${order.orderNumber}' : 'Order');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: DriverColors.border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _InquiryThumbnail(url: image, size: 36),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('REGARDING', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: DriverColors.textSecondary)),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: DriverColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InquiryThumbnail extends StatelessWidget {
  final String? url;
  final double size;
  const _InquiryThumbnail({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.inventory_2_outlined, color: DriverColors.primary, size: size * 0.4),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(width: size, height: size, color: Colors.black12, alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (context, error, stack) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.inventory_2_outlined, color: DriverColors.primary, size: size * 0.4),
        ),
      ),
    );
  }
}

/// A single sent/received attachment — a fixed-size square thumbnail for
/// images and videos (never stretched, never stacked: several attachments
/// on one message wrap horizontally via [ChatBubble]'s [Wrap]), or a
/// compact file chip for anything else. Tapping an image opens it full
/// screen; tapping a video hands off to the device's own player, since
/// this project doesn't bundle an in-app video player.
class _AttachmentCard extends StatelessWidget {
  final ChatAttachment attachment;
  static const _size = 104.0;

  const _AttachmentCard({required this.attachment});

  Future<void> _open(BuildContext context) async {
    if (attachment.url.isEmpty) return; // still uploading — nothing to open yet
    if (attachment.isImage) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _AttachmentImageViewer(url: attachment.url, heroTag: attachment.id),
        fullscreenDialog: true,
      ));
    } else if (attachment.isVideo) {
      final uri = Uri.tryParse(attachment.url);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage || attachment.isVideo) {
      return GestureDetector(
        onTap: () => _open(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: _size,
            height: _size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (attachment.isImage) _imageContent() else _videoPlaceholder(),
                if (attachment.isVideo)
                  Container(
                    color: Colors.black.withOpacity(0.22),
                    alignment: Alignment.center,
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                if (attachment.url.isEmpty)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: _size * 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: DriverColors.border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_rounded, size: 16, color: DriverColors.primaryDark),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              attachment.fileName ?? 'Attachment',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: DriverColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageContent() {
    if (attachment.localBytes != null) {
      return Image.memory(attachment.localBytes!, fit: BoxFit.cover);
    }
    return Image.network(
      attachment.url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : Container(color: Colors.black12, alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2)),
      errorBuilder: (context, error, stack) =>
          Container(color: Colors.black12, alignment: Alignment.center, child: const Icon(Icons.broken_image_outlined, color: DriverColors.textSecondary)),
    );
  }

  /// Videos never get a decoded frame preview (no video-thumbnail package in
  /// this project) — a neutral dark card with the play badge above is the
  /// whole treatment, for both a freshly-picked local file and one already
  /// hosted on the server.
  Widget _videoPlaceholder() => Container(color: DriverColors.textPrimary.withOpacity(0.85));
}

class _AttachmentImageViewer extends StatelessWidget {
  final String url;
  final String heroTag;
  const _AttachmentImageViewer({required this.url, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.network(url, errorBuilder: (context, error, stack) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
          ),
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

/// Centered "are you sure" confirmation — leads with an icon and gives the
/// confirming action its own filled button instead of two same-looking
/// [TextButton]s, the same upgrade [ResignationCancelConfirmDialog]
/// (driver_work_screen.dart) already made over a plain [AlertDialog].
/// Reusable across the driver app wherever a lightweight yes/no confirm is
/// needed (archive/unarchive a conversation, etc).
class DriverConfirmDialog extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final IconData confirmIcon;

  const DriverConfirmDialog({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmIcon,
    this.cancelLabel = 'Cancel',
  });

  static Future<bool?> show(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String title,
    required String message,
    required String confirmLabel,
    required IconData confirmIcon,
    String cancelLabel = 'Cancel',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DriverConfirmDialog(
        icon: icon,
        accent: accent,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        confirmIcon: confirmIcon,
        cancelLabel: cancelLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 32, offset: const Offset(0, 12))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: accent.withOpacity(0.14), shape: BoxShape.circle),
              child: Icon(icon, color: accent, size: 30),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: DriverColors.textPrimary)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: DriverColors.textSecondary, height: 1.45)),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DriverColors.textPrimary,
                      side: const BorderSide(color: DriverColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(cancelLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: Icon(confirmIcon, size: 16),
                    label: Text(confirmLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 220.ms).scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 260.ms);
  }
}
