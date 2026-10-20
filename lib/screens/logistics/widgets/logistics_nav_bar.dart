import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../driver/driver_theme.dart';

/// Bottom navigation for the Logistics mobile app — same rounded white bar
/// + teal accent language as [DriverNavBar] (widgets/driver_nav_bar.dart),
/// simplified to a plain 3-item row since Dashboard/Inventory/Settings has
/// no natural "hero" tab to float a center button over the way the driver
/// app's Home tab does.
class LogisticsNavBar extends StatelessWidget {
  const LogisticsNavBar({super.key, required this.currentIndex, required this.onTap, this.badges = const {}});

  /// Tab index -> count shown as a badge (hidden at 0).
  final Map<int, int> badges;

  /// 0 Dashboard, 1 Inventory, 2 Settings.
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (icon: Icons.space_dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.inventory_2_rounded, label: 'Inventory'),
    (icon: Icons.settings_rounded, label: 'Settings'),
  ];

  void _handleTap(int index) {
    HapticFeedback.selectionClick();
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 72 + bottomInset,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _LogisticsNavItem(
                  icon: _items[i].icon,
                  label: _items[i].label,
                  selected: currentIndex == i,
                  badge: badges[i] ?? 0,
                  onTap: () => _handleTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogisticsNavItem extends StatelessWidget {
  const _LogisticsNavItem({required this.icon, required this.label, required this.selected, required this.onTap, this.badge = 0});

  final int badge;

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? DriverColors.primary : DriverColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: selected ? DriverColors.primary.withOpacity(0.12) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
              child: Badge(
                isLabelVisible: badge > 0,
                label: Text(badge > 99 ? '99+' : '$badge'),
                backgroundColor: DriverColors.warning,
                child: Icon(icon, size: 22, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}
