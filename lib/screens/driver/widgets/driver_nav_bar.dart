import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bottom navigation for the driver app — modeled on [CourierNavBar]'s
/// floating-center pattern (widgets/navigation/courier_navbar.dart) but
/// extended to 5 tabs: Deliveries and Earnings sit left of the floating Home
/// button, Chat and Account sit right of it.
///
/// History no longer has its own tab here — it moved to a compact icon
/// shortcut (tooltip "History") in the Deliveries screen's app bar, the
/// same "demoted from a tab to an app-bar action" pattern Settings already
/// uses from the Account screen. See driver_deliveries_screen.dart.
class DriverNavBar extends StatelessWidget {
  const DriverNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadChats = 0,
    this.isCourier = false,
  });

  /// 0 Home, 1 Deliveries, 2 Earnings, 3 Chat, 4 Account.
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadChats;
  final bool isCourier;

  static const Color _teal = Color(0xFF0D9488);

  void _handleTap(int index) {
    HapticFeedback.selectionClick();
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    // The bar is a fixed 72px content band, but the inner SafeArea steals
    // the device's bottom inset (gesture pill / home indicator) out of it —
    // on insets around ~14px that squeezed the nav items' column past its
    // box and tripped a "RenderFlex overflowed by 3.0 pixels" on the bottom.
    // Growing the bar (and the floating-button offset) by the inset gives
    // SafeArea its own room to pad, leaving the full 72px for the row.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: 92 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 72 + bottomInset,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, -6))],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(child: _DriverNavItem(icon: Icons.assignment_turned_in_rounded, label: 'Deliveries', selected: currentIndex == 1, onTap: () => _handleTap(1))),
                    Expanded(child: _DriverNavItem(icon: isCourier ? Icons.receipt_long_rounded : Icons.account_balance_wallet_rounded, label: isCourier ? 'Payslips' : 'Earnings', selected: currentIndex == 2, onTap: () => _handleTap(2))),
                    const SizedBox(width: 64),
                    Expanded(
                      child: _DriverNavItem(
                        icon: Icons.chat_bubble_rounded,
                        label: 'Chat',
                        selected: currentIndex == 3,
                        badgeCount: unreadChats,
                        onTap: () => _handleTap(3),
                      ),
                    ),
                    Expanded(child: _DriverNavItem(icon: Icons.settings_rounded, label: 'Settings', selected: currentIndex == 4, onTap: () => _handleTap(4))),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30 + bottomInset,
            child: GestureDetector(
              onTap: () => _handleTap(0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: currentIndex == 0 ? const [Color(0xFF14B8A6), _teal] : const [Color(0xFF5EEAD4), Color(0xFF2DD4BF)],
                  ),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: AnimatedScale(
                  scale: currentIndex == 0 ? 1.0 : 0.92,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverNavItem extends StatelessWidget {
  const _DriverNavItem({
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
                    color: selected ? _teal.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 21, color: selected ? _teal : _inactive),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
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
            // FittedBox keeps this to one line and shrinks it rather than
            // wrapping — under a squeeze narrow enough to wrap "Deliveries"
            // or "Settings" onto two lines, the Column's height would blow
            // past its 60px cap and trip a RenderFlex overflow.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(fontSize: 10.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? _teal : _inactive),
                child: Text(label, maxLines: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
