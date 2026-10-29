import 'package:flutter/material.dart';

/// Shared visual language for the hub's operational screens.
class LogisticsTheme {
  LogisticsTheme._();

  static const ink = Color(0xFF172923);
  static const muted = Color(0xFF596B61);
  static const canvas = Color(0xFFF5F6F1);
  static const surface = Colors.white;
  static const border = Color(0xFFDDE3DC);
  static const primary = Color(0xFF0F766E);
  static const primarySoft = Color(0xFFDDF1EC);
  static const warning = Color(0xFF9B682D);
  static const warningSoft = Color(0xFFFFF4E2);
  static const error = Color(0xFFB95137);

  static const pageTitle = TextStyle(
    color: ink,
    fontSize: 28,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
  );
  static const sectionTitle = TextStyle(
    color: ink,
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );
  static const body = TextStyle(
    color: ink,
    fontSize: 14,
    height: 1.4,
  );
  static const secondary = TextStyle(
    color: muted,
    fontSize: 12,
    height: 1.4,
  );
}
