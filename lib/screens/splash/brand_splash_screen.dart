import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../widgets/brand_logo.dart';
import '../auth/auth_screen.dart';
import '../buyer/buyer_shell.dart';
import '../driver/driver_shell.dart';
import '../logistics/logistics_shell.dart';

/// App-launch splash: the shopping bag drops in, its handle is drawn on,
/// the pathway is "paved" through the bag, then the wordmark rises in.
/// Hands off to [AuthScreen] with a fade once the sequence finishes.
class BrandSplashScreen extends StatefulWidget {
  const BrandSplashScreen({super.key});

  @override
  State<BrandSplashScreen> createState() => _BrandSplashScreenState();
}

class _BrandSplashScreenState extends State<BrandSplashScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

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
      final destination = await _resolveDestination();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ));
    });
  }

  Future<Widget> _resolveDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return const AuthScreen();

    final cachedRole = prefs.getString('last_auth_role');
    try {
      final user = await _api.getUser(token);
      final metadata = (user['user_metadata'] as Map?) ?? {};
      final role = (metadata['role'] ?? user['role'] ?? '').toString();
      final status = (metadata['status'] ?? '').toString();
      final destination = _dashboardFor(role);
      if (destination != null && status != 'rejected') {
        await prefs.setString('last_auth_role', role);
        return destination;
      }

      await prefs.remove('auth_token');
      await prefs.remove('last_auth_role');
      return const AuthScreen();
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 419) {
        await prefs.remove('auth_token');
        await prefs.remove('last_auth_role');
        return const AuthScreen();
      }
      return _dashboardFor(cachedRole ?? '') ?? const AuthScreen();
    } catch (_) {
      // If the device is temporarily offline, the role saved at sign-in lets
      // the correct shell handle its own connection/session state.
      return _dashboardFor(cachedRole ?? '') ?? const AuthScreen();
    }
  }

  Widget? _dashboardFor(String role) {
    switch (role) {
      case 'buyer':
        return const BuyerShell();
      case 'courier':
      case 'driver':
        return const DriverShell();
      case 'logistics':
      case 'logistics_admin':
        return const LogisticsShell();
      default:
        return null;
    }
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
