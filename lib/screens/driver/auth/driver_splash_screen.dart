import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/api_service.dart';
import '../../../widgets/common.dart';
import '../driver_shell.dart';
import 'driver_login_screen.dart';

/// Brand splash — logo scale/fade in, then either continues straight into
/// [DriverShell] (a still-valid saved session) or advances to
/// [DriverLoginScreen]. Avoids forcing a driver/courier to re-enter
/// credentials on every app launch when they're already signed in.
class DriverSplashScreen extends StatefulWidget {
  const DriverSplashScreen({super.key});

  @override
  State<DriverSplashScreen> createState() => _DriverSplashScreenState();
}

class _DriverSplashScreenState extends State<DriverSplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final Animation<double> _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOut));
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), _resolveSession);
  }

  Future<void> _resolveSession() async {
    if (!mounted) return;

    Widget destination = const DriverLoginScreen();
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? true;
    final token = rememberMe ? prefs.getString('auth_token') : null;

    if (!rememberMe) {
      await prefs.remove('auth_token');
    } else if (token != null && token.isNotEmpty) {
      try {
        final user = await _api.getUser(token);
        final metadata = (user['user_metadata'] as Map?) ?? {};
        final role = (metadata['role'] ?? '').toString();
        final status = (metadata['status'] ?? '').toString();
        if ((role == 'driver' || role == 'courier') && status != 'rejected') {
          destination = const DriverShell();
        } else {
          await prefs.remove('auth_token');
        }
      } catch (_) {
        // Token is missing/expired/unreachable — fall back to login rather
        // than blocking the splash screen indefinitely.
        await prefs.remove('auth_token');
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, __) => FadeTransition(opacity: animation, child: destination),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.4),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 42),
                ),
                const SizedBox(height: 18),
                const Text('BuyTheWay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text('DRIVER', style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
