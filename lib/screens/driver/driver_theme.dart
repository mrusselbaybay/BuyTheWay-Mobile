import 'package:flutter/material.dart';

/// Brand palette for the standalone driver app module.
///
/// Deliberately separate from [WorkAppColors] (work/driver_work_screen.dart)
/// and the courier dashboard's inline constants — this file isn't imported
/// by either, so there is no risk of the name collisions that already
/// exist between driver_work_screen.dart and widgets/common.dart.
class DriverColors {
  DriverColors._();

  static const Color primary = Color(0xFF0D9488);
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color primarySurface = Color(0xFFE6FFFA);

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  static const Color success = Color(0xFF16A34A);
  static const Color successSurface = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorSurface = Color(0xFFFEE2E2);
  static const Color info = primary;

  static const List<Color> primaryGradient = [primaryLight, primaryDark];

  // ---- "Mission control" dashboard accents (Deliveries + History) ----
  // A darker teal-leaning gradient for hero/header surfaces, distinct from
  // [primaryGradient] (used on smaller elements like the nav FAB) — this
  // one is meant to cover a full-width band.
  static const List<Color> heroGradient = [Color(0xFF0F766E), Color(0xFF0D9488)];

  /// A soft outer glow in [color] — used for the "pulsing" live/urgent
  /// indicators the Mission Control dashboard calls for, without pulling in
  /// an animation package: callers wrap this in their own AnimationController
  /// when they want it to breathe (see DriverDeliveriesScreen's priority
  /// alert banner).
  static List<BoxShadow> glow(Color color, {double blur = 18, double spread = 1}) => [
        BoxShadow(color: color.withOpacity(0.35), blurRadius: blur, spreadRadius: spread),
      ];
}

/// Shared button styling for the module's primary "commit" actions (Mark as
/// picked up, Mark as delivered, Confirm pickup, ...) — big, tall, and
/// heavily rounded, since these are one-tap-per-delivery commitments the
/// driver needs to hit confidently at arm's length, not a compact form
/// control.
class DriverButtonStyle {
  DriverButtonStyle._();

  static ButtonStyle primary(Color background, {Color foreground = Colors.white}) => ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withOpacity(0.35),
        disabledForegroundColor: foreground.withOpacity(0.8),
        minimumSize: const Size.fromHeight(60),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
      );
}

/// Shared text styles so every screen in the module reads consistently
/// without repeating raw [TextStyle] literals everywhere.
class DriverText {
  DriverText._();

  static const TextStyle title = TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: DriverColors.textPrimary);
  static const TextStyle sectionTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: DriverColors.textPrimary);
  static const TextStyle body = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DriverColors.textPrimary);
  static const TextStyle caption = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: DriverColors.textSecondary);
  static const TextStyle label = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: DriverColors.textSecondary, letterSpacing: 0.3);
}
