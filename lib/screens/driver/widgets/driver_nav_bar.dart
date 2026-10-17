import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Driver/courier bottom navigation — the same floating white pill as the
/// buyer's [BuyerNavBar] (screens/buyer/widgets/buyer_nav_bar.dart): icon-only
/// tabs, Home in the middle, the selected tab's icon turns teal.
///
/// Left to right: Deliveries · Remittances/Earnings · Home · Chat · Settings
/// (shell tab indices 1 · 2 · 0 · 3 · 4).
///
/// Hosted with `Scaffold.extendBody: true`, so tab bodies receive the bar's
/// height in `MediaQuery.padding.bottom` and pad themselves past it.
///
/// History no longer has its own tab — it's a compact icon shortcut in the
/// Deliveries app bar (see driver_deliveries_screen.dart).
class DriverNavBar extends StatelessWidget {
  const DriverNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadChats = 0,
    this.isCourier = false,
  });

  /// 0 Home, 1 Deliveries, 2 Remittances/Earnings, 3 Chat, 4 Settings.
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadChats;
  final bool isCourier;

  static const Color _teal = Color(0xFF0D9488);
  static const double _barHeight = 66;

  void _handleTap(int index) {
    HapticFeedback.selectionClick();
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: Container(
        height: _barHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          _DriverNavItem(icon: Icons.assignment_turned_in_outlined, label: 'Deliveries', selected: currentIndex == 1, onTap: () => _handleTap(1)),
          _DriverNavItem(
            icon: isCourier ? Icons.currency_exchange_rounded : Icons.account_balance_wallet_outlined,
            label: isCourier ? 'Remittances' : 'Earnings',
            selected: currentIndex == 2,
            onTap: () => _handleTap(2),
          ),
          _DriverNavItem(icon: Icons.home_outlined, label: 'Home', selected: currentIndex == 0, onTap: () => _handleTap(0)),
          _DriverNavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Chat', selected: currentIndex == 3, badgeCount: unreadChats, onTap: () => _handleTap(3)),
          _DriverNavItem(icon: Icons.settings_outlined, label: 'Settings', selected: currentIndex == 4, onTap: () => _handleTap(4)),
        ]),
      ),
    );
  }
}

class _DriverNavItem extends StatelessWidget {
  const _DriverNavItem({required this.icon, required this.label, required this.selected, required this.onTap, this.badgeCount = 0});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: badgeCount > 0 ? '$label, $badgeCount' : label,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Center(
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(icon, size: 26, color: selected ? DriverNavBar._teal : const Color(0xFF94A3B8)),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: 2,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 1.5)),
                      child: Text(badgeCount > 9 ? '9+' : '$badgeCount', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, height: 1.3)),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
