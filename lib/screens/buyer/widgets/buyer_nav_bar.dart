import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buyer_store.dart';

/// Buyer bottom navigation: a floating deep-teal pill with icon-only tabs.
/// The selected tab sits in a lighter circle and swaps to its filled icon.
///
/// 0 Home · 1 Orders · 2 Cart · 3 Chat · 4 Account.
///
/// Hosted with `Scaffold.extendBody: true`, so tab bodies receive the bar's
/// height in `MediaQuery.padding.bottom` and pad themselves past it.
class BuyerNavBar extends StatelessWidget {
  const BuyerNavBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const Color _bar = Color(0xFF0F5F5A);
  static const double _barHeight = 66;

  void _handleTap(int index) {
    HapticFeedback.selectionClick();
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final store = BuyerStore.instance;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: Container(
        height: _barHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _bar,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [BoxShadow(color: _bar.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => Row(children: [
            _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', selected: currentIndex == 0, onTap: () => _handleTap(0)),
            _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Orders', selected: currentIndex == 1, onTap: () => _handleTap(1)),
            _NavItem(icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart_rounded, label: 'Cart', selected: currentIndex == 2, badgeCount: store.cartCount, onTap: () => _handleTap(2)),
            _NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Chat', selected: currentIndex == 3, badgeCount: store.chatUnread, onTap: () => _handleTap(3)),
            _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Account', selected: currentIndex == 4, onTap: () => _handleTap(4)),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap, this.badgeCount = 0});

  final IconData icon;
  final IconData activeIcon;
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent),
                  child: AnimatedScale(
                    scale: selected ? 1.08 : 1,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutBack,
                    child: Icon(selected ? activeIcon : icon, size: 24, color: selected ? Colors.white : Colors.white.withValues(alpha: 0.65)),
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: 2,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(20), border: Border.all(color: BuyerNavBar._bar, width: 1.5)),
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
