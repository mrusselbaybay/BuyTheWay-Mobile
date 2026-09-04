import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modern floating-home bottom nav bar for the courier dashboard.
/// 0: Salary, 1: Home (floating, center), 2: Pickups
///
/// The floating Home button pulses with a soft expanding ring whenever
/// there are pending pickups waiting — an ambient nudge back to the
/// dashboard rather than a decorative animation with no meaning attached.
class CourierNavBar extends StatefulWidget {
  const CourierNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.pendingPickups = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Shown as a small badge on the Pickups tab when > 0, and drives the
  /// attention pulse around the floating Home button.
  final int pendingPickups;

  @override
  State<CourierNavBar> createState() => _CourierNavBarState();
}

class _CourierNavBarState extends State<CourierNavBar> with SingleTickerProviderStateMixin {
  static const Color _teal = Color(0xFF0D9488);

  late final AnimationController _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..repeat();

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // ---- Bar background ----
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, -6))],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Salary',
                        selected: widget.currentIndex == 0,
                        onTap: () => _handleTap(0),
                      ),
                    ),
                    const SizedBox(width: 76),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.inventory_2_rounded,
                        label: 'Pickups',
                        selected: widget.currentIndex == 2,
                        badgeCount: widget.pendingPickups,
                        onTap: () => _handleTap(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---- Floating Home button ----
          Positioned(
            bottom: 30,
            child: GestureDetector(
              onTap: () => _handleTap(1),
              child: SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.pendingPickups > 0)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final t = _pulseController.value;
                          return Container(
                            width: 62 + t * 22,
                            height: 62 + t * 22,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: _teal.withOpacity((1 - t) * 0.22)),
                          );
                        },
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: widget.currentIndex == 1 ? const [Color(0xFF14B8A6), Color(0xFF0D9488)] : const [Color(0xFF5EEAD4), Color(0xFF2DD4BF)],
                        ),
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [BoxShadow(color: _teal.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: AnimatedScale(
                        scale: widget.currentIndex == 1 ? 1.0 : 0.92,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(Icons.home_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  static const Color _teal = Color(0xFF0D9488);
  static const Color _inactive = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: selected ? _teal.withOpacity(0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: selected ? _teal : _inactive),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800, height: 1.3),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? _teal : _inactive),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
