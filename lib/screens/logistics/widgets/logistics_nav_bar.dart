import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    (icon: Icons.grid_view_rounded, label: 'Overview'),
    (icon: Icons.qr_code_scanner_rounded, label: 'Parcels'),
    (icon: Icons.person_outline_rounded, label: 'Account'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            color: Color(0xFFF3F2EC),
            border: Border(top: BorderSide(color: Color(0xFFE2E4DD)))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: currentIndex == i,
                    button: true,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTap(i);
                      },
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Badge(
                              isLabelVisible: (badges[i] ?? 0) > 0,
                              label: Text((badges[i] ?? 0) > 99
                                  ? '99+'
                                  : '${badges[i]}'),
                              backgroundColor: const Color(0xFFB95137),
                              child: Container(
                                width: 32,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: currentIndex == i
                                    ? BoxDecoration(color: const Color(0xFFE0E8DD), borderRadius: BorderRadius.circular(8))
                                    : null,
                                child: Icon(_items[i].icon,
                                    size: 20,
                                    color: currentIndex == i
                                        ? const Color(0xFF285A45)
                                        : const Color(0xFF84938A)),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(_items[i].label,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: currentIndex == i
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: currentIndex == i
                                        ? const Color(0xFF285A45)
                                        : const Color(0xFF84938A))),
                          ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}
