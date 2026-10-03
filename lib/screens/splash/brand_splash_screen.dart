import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/brand_logo.dart';
import '../auth/auth_screen.dart';

/// App-launch splash: the shopping bag drops in, its handle is drawn on,
/// the pathway is "paved" through the bag, then the wordmark rises in.
/// Hands off to [AuthScreen] with a fade once the sequence finishes.
class BrandSplashScreen extends StatefulWidget {
  const BrandSplashScreen({super.key});

  @override
  State<BrandSplashScreen> createState() => _BrandSplashScreenState();
}

class _BrandSplashScreenState extends State<BrandSplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() async {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const AuthScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _controller, curve: Interval(begin, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoSize = math.min(size.width * 0.5, 220.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _interval(0.0, 0.18),
              child: ScaleTransition(
                scale: Tween(begin: 0.6, end: 1.0).animate(_interval(0.0, 0.32, Curves.easeOutBack)),
                child: BagLogo(
                  size: logoSize,
                  handle: _interval(0.22, 0.52, Curves.easeInOut),
                  road: _interval(0.45, 0.78, Curves.easeInOutCubic),
                  repaint: _controller,
                ),
              ),
            ),
            const SizedBox(height: 20),
            BrandWordmark(
              fontSize: logoSize * 0.26,
              animations: [
                _interval(0.66, 0.86),
                _interval(0.74, 0.94),
                _interval(0.80, 1.0),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
