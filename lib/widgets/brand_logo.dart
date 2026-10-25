import 'package:flutter/material.dart';

/// Colors sampled from the BuyTheWay logo and wordmark.
class BrandColors {
  static const blue = Color(0xFF1469C1);
  static const blueDark = Color(0xFF0F55A0);
  static const blueTint = Color(0xFFEAF2FB);
  static const handle = Color(0xFFE8740F);
  static const buy = Color(0xFF1C4F9A);
  static const the = Color(0xFFEE7D2D);
  static const way = Color(0xFF4AAFAA);
}

/// Font bundled for the wordmark and display headings.
const String kBrandFont = 'Nunito';

/// The shopping-bag mark (bag, handle, pathway). Static by default; pass
/// [handle]/[road] animations (0→1) to draw those parts on progressively.
class BagLogo extends StatelessWidget {
  const BagLogo({super.key, this.size = 48, this.handle, this.road, this.repaint});

  final double size;
  final Animation<double>? handle;
  final Animation<double>? road;
  final Listenable? repaint;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: _BagLogoPainter(handle: handle, road: road, repaint: repaint),
      ),
    );
  }
}

/// Tri-color "BuyTheWay" wordmark. [animations], when given, must hold
/// three entries that fade/slide each word in.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, required this.fontSize, this.animations});

  final double fontSize;
  final List<Animation<double>>? animations;

  static const _words = [('Buy', BrandColors.buy), ('The', BrandColors.the), ('Way', BrandColors.way)];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'BuyTheWay',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _words.length; i++) _word(i),
        ],
      ),
    );
  }

  Widget _word(int i) {
    final text = Text(
      _words[i].$1,
      style: TextStyle(
        fontFamily: kBrandFont,
        fontWeight: FontWeight.w900,
        fontVariations: const [FontVariation('wght', 1000)],
        fontSize: fontSize,
        letterSpacing: -fontSize * 0.03,
        height: 1.1,
        color: _words[i].$2,
      ),
    );
    final anim = animations?[i];
    if (anim == null) return text;
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(anim),
        child: text,
      ),
    );
  }
}

/// Vector rendition of the bag logo, authored on a 1254×1254 canvas
/// (the source artwork's size) and scaled to fit.
class _BagLogoPainter extends CustomPainter {
  _BagLogoPainter({this.handle, this.road, super.repaint});

  final Animation<double>? handle;
  final Animation<double>? road;

  static const _canvas = 1254.0;
  static const _leftEye = Offset(389, 450);
  static const _rightEye = Offset(861, 450);
  static const _roadStart = Offset(795, 450);

  static final Path _bag = Path()
    ..moveTo(330, 350)
    ..lineTo(928, 350)
    ..quadraticBezierTo(1015, 350, 1032, 435)
    ..lineTo(1180, 1005)
    ..quadraticBezierTo(1205, 1110, 1080, 1145)
    ..lineTo(110, 1145)
    ..quadraticBezierTo(62, 1080, 78, 1000)
    ..lineTo(220, 435)
    ..quadraticBezierTo(238, 350, 330, 350)
    ..close();

  static final Path _eyes = Path()
    ..addOval(Rect.fromCircle(center: _leftEye, radius: 66))
    ..addOval(Rect.fromCircle(center: _rightEye, radius: 66));

  static final Path _road = Path()
    ..moveTo(795, 443)
    ..cubicTo(680, 470, 560, 510, 530, 560)
    ..cubicTo(505, 610, 600, 640, 690, 675)
    ..cubicTo(760, 705, 740, 750, 650, 775)
    ..cubicTo(480, 825, 230, 880, 140, 1010)
    ..cubicTo(110, 1055, 100, 1090, 102, 1110)
    ..lineTo(102, 1160)
    ..lineTo(470, 1160)
    ..cubicTo(440, 1100, 450, 1030, 560, 975)
    ..cubicTo(680, 915, 900, 880, 950, 780)
    ..cubicTo(985, 700, 880, 650, 780, 620)
    ..cubicTo(690, 595, 640, 580, 657, 545)
    ..cubicTo(670, 515, 740, 480, 795, 458)
    ..close();

  static final Path _handle = Path()
    ..moveTo(_leftEye.dx, _leftEye.dy)
    ..lineTo(395, 340)
    ..cubicTo(410, 180, 510, 120, 625, 120)
    ..cubicTo(740, 120, 840, 180, 855, 340)
    ..lineTo(_rightEye.dx, _rightEye.dy);

  /// Fully drawn logo — computed once and shared by every static instance.
  static final Path _staticBag =
      Path.combine(PathOperation.difference, _bag, Path.combine(PathOperation.union, _eyes, _road));

  static final _bagPaint = Paint()..color = BrandColors.blue;
  static final _handlePaint = Paint()
    ..color = BrandColors.handle
    ..style = PaintingStyle.stroke
    ..strokeWidth = 78
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _canvas);
    final roadT = road?.value ?? 1;
    final handleT = handle?.value ?? 1;

    if (roadT >= 1) {
      canvas.drawPath(_staticBag, _bagPaint);
    } else {
      // Pave the road outward from the right grommet down to the bag's base.
      var cutout = _eyes;
      if (roadT > 0) {
        final reach = Path()..addOval(Rect.fromCircle(center: _roadStart, radius: roadT * 1000));
        cutout = Path.combine(PathOperation.union, cutout, Path.combine(PathOperation.intersect, _road, reach));
      }
      canvas.drawPath(Path.combine(PathOperation.difference, _bag, cutout), _bagPaint);
    }

    if (handleT >= 1) {
      canvas.drawPath(_handle, _handlePaint);
    } else if (handleT > 0) {
      final metric = _handle.computeMetrics().first;
      canvas.drawPath(metric.extractPath(0, metric.length * handleT), _handlePaint);
    }
  }

  @override
  bool shouldRepaint(_BagLogoPainter old) => old.handle != handle || old.road != road;
}
