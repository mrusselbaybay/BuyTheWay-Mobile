import 'package:flutter/material.dart';

/// Bell for the Home header (sits on the dark hero, so it is white-on-glass).
/// 48dp touch target; the badge caps at 99+.
class DriverNotificationBell extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;

  const DriverNotificationBell({super.key, required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.16)),
              child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
            ),
            if (unread > 0)
              Positioned(
                top: 3,
                right: 1,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFFD64560), borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white, width: 1.5)),
                  child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, height: 1.1)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
