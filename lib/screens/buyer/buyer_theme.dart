import 'package:flutter/material.dart';

/// Buyer app palette. Teal is identity (header, nav, selection); orange is
/// reserved for money and commitment — prices, Buy Now, Place Order, sale
/// badges — so it always means "this is the action / the cost".
class BColors {
  BColors._();

  static const Color brand = Color(0xFF0F766E);
  static const Color brandDark = Color(0xFF115E59);
  static const Color brandSurface = Color(0xFFF0FDFA);

  // #CF4510 keeps 4.6:1 against white so small prices stay AA-legible.
  static const Color cta = Color(0xFFCF4510);
  static const Color ctaSurface = Color(0xFFFFF4ED);

  static const Color background = Color(0xFFF4F5F7);
  static const Color surface = Colors.white;
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color faint = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);

  static const Color star = Color(0xFFF59E0B);
  static const Color success = Color(0xFF15803D);
  static const Color successSurface = Color(0xFFF0FDF4);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSurface = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFDC2626);
  static const Color errorSurface = Color(0xFFFEF2F2);
}

class BText {
  BText._();

  static const TextStyle title = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: BColors.ink);
  static const TextStyle section = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BColors.ink);
  static const TextStyle body = TextStyle(fontSize: 14, height: 1.4, color: BColors.ink);
  static const TextStyle small = TextStyle(fontSize: 12.5, color: BColors.muted);
  static const TextStyle tiny = TextStyle(fontSize: 11.5, color: BColors.muted);
}

/// Small radii on purpose: flat, dense commerce UI.
class BRadius {
  BRadius._();

  static const double sm = 4;
  static const double md = 8;
  static const double card = 14;
  static const double tile = 18;
}

/// Soft elevation shared by floating cards (courier-app language).
List<BoxShadow> softShadow([double opacity = 0.06]) => [
      BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: opacity), blurRadius: 14, offset: const Offset(0, 4)),
    ];

const List<Color> kHeroGradient = [Color(0xFF0F766E), Color(0xFF0D9488)];

class BButtons {
  BButtons._();

  static ButtonStyle cta({double height = 46}) => ElevatedButton.styleFrom(
        backgroundColor: BColors.cta,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE5C3B5),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      );

  static ButtonStyle brand({double height = 46}) => ElevatedButton.styleFrom(
        backgroundColor: BColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      );

  static ButtonStyle outline({double height = 40, Color color = BColors.brand}) => OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      );
}

/// `₱1,234.50`
String peso(num value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '${negative ? '-' : ''}₱$buffer.${parts[1]}';
}

/// `₱1,299` for whole amounts, `₱1,299.50` otherwise — listing cards.
String pesoCompact(num value) {
  final full = peso(value);
  return full.endsWith('.00') ? full.substring(0, full.length - 3) : full;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// `Oct 3, 2026` (+ `, 2:05 PM` when [withTime]).
String formatDate(DateTime? date, {bool withTime = false}) {
  if (date == null) return '—';
  final d = date.toLocal();
  final base = '${_months[d.month - 1]} ${d.day}, ${d.year}';
  if (!withTime) return base;
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$base, $hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// Must mirror seller_details.line_of_business — see the web
/// useCategoryMeta.js; every product's category is one of these strings.
const List<String> kCategories = [
  'Pet Supplies',
  'Kids and Baby',
  'Electronics and Gadgets',
  'House and Garden',
  "Woman's Apparel",
  "Men's Apparel",
  'Sports and Outdoors',
  'Health and Beauty',
];

IconData categoryIcon(String? category) {
  switch (category) {
    case 'Pet Supplies':
      return Icons.pets_outlined;
    case 'Kids and Baby':
      return Icons.child_friendly_outlined;
    case 'Electronics and Gadgets':
      return Icons.devices_other_outlined;
    case 'House and Garden':
      return Icons.chair_outlined;
    case "Woman's Apparel":
      return Icons.woman_outlined;
    case "Men's Apparel":
      return Icons.man_outlined;
    case 'Sports and Outdoors':
      return Icons.sports_basketball_outlined;
    case 'Health and Beauty':
      return Icons.spa_outlined;
    default:
      return Icons.shopping_bag_outlined;
  }
}

/// Per-category accent — the same families the web uses (useCategoryMeta's
/// `accent`), so a category reads the same colour on every surface.
Color categoryAccent(String? category) {
  switch (category) {
    case 'Pet Supplies':
      return const Color(0xFF0D9488);
    case 'Kids and Baby':
      return const Color(0xFFEA580C);
    case 'Electronics and Gadgets':
      return const Color(0xFF4F46E5);
    case 'House and Garden':
      return const Color(0xFFD97706);
    case "Woman's Apparel":
      return const Color(0xFFDB2777);
    case "Men's Apparel":
      return const Color(0xFF2563EB);
    case 'Sports and Outdoors':
      return const Color(0xFF16A34A);
    case 'Health and Beauty':
      return const Color(0xFF9333EA);
    default:
      return BColors.muted;
  }
}

/// Short labels for the dense category strip / rail.
String categoryShortLabel(String category) {
  switch (category) {
    case 'Electronics and Gadgets':
      return 'Electronics';
    case 'House and Garden':
      return 'Home & Garden';
    case "Woman's Apparel":
      return "Women's";
    case "Men's Apparel":
      return "Men's";
    case 'Sports and Outdoors':
      return 'Sports';
    case 'Health and Beauty':
      return 'Beauty';
    case 'Kids and Baby':
      return 'Kids & Baby';
    default:
      return category;
  }
}
