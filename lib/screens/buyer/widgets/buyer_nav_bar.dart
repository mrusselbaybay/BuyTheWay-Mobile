import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buyer_theme.dart';

/// Buyer bottom navigation: a floating frosted-glass pill that content
/// scrolls underneath.
///
/// Orders · Home · Account, with Home centered — Cart and Chat moved to
/// shortcuts beside the home search bar, so they're dropped here to avoid
/// duplicating them. [currentIndex] still uses the shell's full tab indices
/// (0 Home, 1 Orders, 2 Cart, 3 Chat, 4 Account), so the bar simply shows
/// nothing selected while a shortcut tab (Cart/Chat) is active.
///
/// Hosted with `Scaffold.extendBody: true`, so tab bodies receive the bar's
/// height in `MediaQuery.padding.bottom` and pad themselves past it.
class BuyerNavBar extends StatelessWidget {
  const BuyerNavBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _pillHeight = 66;

  void _tap(int index) {
    if (index != currentIndex) HapticFeedback.selectionClick();
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final gap = bottomInset > 0 ? bottomInset : 14.0;
    final radius = BorderRadius.circular(_pillHeight / 2);

    Widget item(int i, IconData icon, IconData activeIcon, String label, {int badge = 0, String badgeNoun = 'new'}) => Expanded(
          child: _NavItem(
            icon: icon,
            activeIcon: activeIcon,
            label: label,
            selected: currentIndex == i,
            badge: badge,
            badgeNoun: badgeNoun,
            onTap: () => _tap(i),
          ),
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, gap),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.10), blurRadius: 28, offset: const Offset(0, 10)),
            BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: _pillHeight,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: radius,
                border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              ),
              child: Row(children: [
                item(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders'),
                item(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                item(4, Icons.person_outline_rounded, Icons.person_rounded, 'Account'),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
    this.badgeNoun = 'new',
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;
  final String badgeNoun;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BColors.brand : BColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '$label, $badge $badgeNoun' : label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        highlightColor: Colors.transparent,
        splashColor: BColors.brand.withValues(alpha: 0.08),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, a) => ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: child)),
              child: Icon(selected ? activeIcon : icon, key: ValueKey(selected), size: 24, color: color),
            ),
            if (badge > 0)
              Positioned(
                top: -5,
                right: -10,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(badge),
                  tween: Tween(begin: 1.35, end: 1),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                  child: _CountBadge(count: badge),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(fontSize: 11, height: 1, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color),
            child: Text(label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
          ),
        ]),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
        constraints: const BoxConstraints(minWidth: 18),
        decoration: BoxDecoration(color: BColors.cta, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 1.5)),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, height: 1.3),
        ),
      );
}
