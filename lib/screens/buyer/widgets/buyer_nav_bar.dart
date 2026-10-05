import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buyer_store.dart';

/// Buyer bottom navigation — a direct port of the courier app's
/// [DriverNavBar] (screens/driver/widgets/driver_nav_bar.dart): same white
/// rounded bar, same floating gradient Home button, same item treatment.
///
/// 0 Home (center) · 1 Orders · 2 Cart · 3 Chat · 4 Account.
///
/// Hosted with `Scaffold.extendBody: true`, so tab bodies receive the bar's
/// height in `MediaQuery.padding.bottom` and pad themselves past it.
class BuyerNavBar extends StatelessWidget {
  const BuyerNavBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const Color _teal = Color(0xFF0D9488);

  void _handleTap(int index) {
    HapticFeedback.selectionClick();
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final store = BuyerStore.instance;
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
                child: ListenableBuilder(
                  listenable: store,
                  builder: (context, _) => Row(
                    children: [
                      Expanded(child: _NavItem(icon: Icons.receipt_long_rounded, label: 'Orders', selected: currentIndex == 1, onTap: () => _handleTap(1))),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.shopping_cart_rounded,
                          label: 'Cart',
                          selected: currentIndex == 2,
                          badgeCount: store.cartCount,
                          onTap: () => _handleTap(2),
                        ),
                      ),
                      const SizedBox(width: 64),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Chat',
                          selected: currentIndex == 3,
                          badgeCount: store.chatUnread,
                          onTap: () => _handleTap(3),
                        ),
                      ),
                      Expanded(child: _NavItem(icon: Icons.person_rounded, label: 'Account', selected: currentIndex == 4, onTap: () => _handleTap(4))),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30 + bottomInset,
            child: Semantics(
              button: true,
              selected: currentIndex == 0,
              label: 'Home',
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
                    child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
                  ),
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
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap, this.badgeCount = 0});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  static const Color _teal = Color(0xFF0D9488);
  static const Color _inactive = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: badgeCount > 0 ? '$label, $badgeCount' : label,
      excludeSemantics: true,
      child: InkWell(
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
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: DefaultTextStyle.of(context).style.copyWith(
                      fontSize: 10.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? _teal : _inactive),
                  child: Text(label, maxLines: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
