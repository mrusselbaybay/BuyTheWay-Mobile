import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logistics_theme.dart';

class LogisticsNavBar extends StatelessWidget {
  const LogisticsNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onOpenNotifications,
    this.badges = const {},
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onOpenNotifications;
  final Map<int, int> badges;

  static const _teal = LogisticsTheme.primary;
  static const _surface = Colors.white;
  static const _muted = Color(0xFF64748B);
  static const _items = [
    (index: 0, icon: Icons.home_rounded, label: 'Today'),
    (index: 1, icon: Icons.inventory_2_outlined, label: 'Parcels'),
    (index: -1, icon: Icons.notifications_none_rounded, label: 'Notifications'),
  ];

  void _select(int index) {
    HapticFeedback.selectionClick();
    if (index == -1) {
      onOpenNotifications();
    } else {
      onTap(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 62,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: LogisticsTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    for (final item in _items)
                      Expanded(
                        flex: currentIndex == item.index ? 3 : 2,
                        child: _NavItem(
                          index: item.index,
                          icon: item.icon,
                          label: item.label,
                          selected: currentIndex == item.index,
                          badgeCount: badges[item.index == -1 ? 3 : item.index] ?? 0,
                          onTap: () => _select(item.index),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              selected: currentIndex == 2,
              label: 'Account and settings',
              child: Material(
                color: currentIndex == 2 ? _teal : _surface,
                shape: const CircleBorder(),
                elevation: 5,
                shadowColor: Colors.black.withValues(alpha: 0.24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _select(2),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: Icon(
                      Icons.manage_accounts_rounded,
                      size: 25,
                      color: currentIndex == 2 ? Colors.white : _teal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  static const _muted = Color(0xFF64748B);

  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final int index;
  final IconData icon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: index == -1 ? 'View all notifications' : label,
        child: Tooltip(
          message: index == -1 ? 'Notifications' : label,
          child: Material(
          color: selected ? LogisticsTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(28),
              child: SizedBox.expand(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: selected
                          ? Row(
                              key: const ValueKey('selected'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon, size: 22, color: Colors.white),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Icon(
                              icon,
                              key: const ValueKey('icon'),
                              size: 23,
                              color: _muted,
                            ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: 6,
                        right: 8,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 17),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB95137),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

