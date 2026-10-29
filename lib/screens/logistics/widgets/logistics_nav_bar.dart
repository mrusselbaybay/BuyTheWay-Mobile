import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logistics_theme.dart';

class LogisticsNavBar extends StatelessWidget {
  const LogisticsNavBar(
      {super.key,
      required this.currentIndex,
      required this.onTap,
      this.badges = const {}});

  final int currentIndex;
  final ValueChanged<int> onTap;
  final Map<int, int> badges;

  static const _items = [
    (index: 0, icon: Icons.grid_view_rounded, label: 'Today'),
    (index: 1, icon: Icons.qr_code_scanner_rounded, label: 'Parcels'),
    (index: 2, icon: Icons.person_outline_rounded, label: 'Account'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            color: LogisticsTheme.surface,
            border: Border(top: BorderSide(color: LogisticsTheme.border))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: currentIndex == _items[i].index,
                    button: true,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTap(_items[i].index);
                      },
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Badge(
                              isLabelVisible:
                                  (badges[_items[i].index] ?? 0) > 0,
                              label: Text((badges[_items[i].index] ?? 0) > 99
                                  ? '99+'
                                  : '${badges[_items[i].index]}'),
                              backgroundColor: const Color(0xFFB95137),
                              child: Container(
                                width: 32,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: currentIndex == _items[i].index
                                    ? BoxDecoration(
                                        color: LogisticsTheme.primarySoft,
                                        borderRadius: BorderRadius.circular(8))
                                    : null,
                                child: Icon(_items[i].icon,
                                    size: 20,
                                    color: currentIndex == _items[i].index
                                        ? LogisticsTheme.primary
                                        : LogisticsTheme.muted),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(_items[i].label,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: currentIndex == _items[i].index
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: currentIndex == _items[i].index
                                        ? LogisticsTheme.primary
                                        : LogisticsTheme.muted)),
                          ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}
