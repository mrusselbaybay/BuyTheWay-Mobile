import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/api_service.dart';
import '../../../widgets/common.dart';
import '../driver_shell.dart';
import 'driver_forgot_password_screen.dart';
import 'driver_register_screen.dart';

/// Sign-in screen for the driver/courier app — signs in against the same
/// Laravel/Supabase backend the buyer and seller apps use (`POST
/// /api/auth/login`), then saves the access token for DriverShell to load
/// the real profile with.
class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = ApiService();
  bool _rememberMe = true;
  bool _obscure = true;
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _identifierController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email/phone and password to continue.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final response = await _api.login(email, password);

      if (!response.containsKey('access_token')) {
        setState(() {
          _error = response['message'] as String? ?? 'Login failed.';
          _loading = false;
        });
        return;
      }

      final token = response['access_token'] as String;
      final userData = (response['user'] as Map?) ?? {};
      final metadata = (userData['user_metadata'] as Map?) ?? {};
      final role = (metadata['role'] ?? userData['role'] ?? '').toString();

      if (role != 'driver' && role != 'courier') {
        setState(() {
          _error = 'This app is for drivers and couriers only.';
          _loading = false;
        });
        return;
      }

      final status = (metadata['status'] ?? 'pending').toString();
      if (status == 'rejected') {
        setState(() {
          _error = 'Your account registration was rejected. Please contact support.';
          _loading = false;
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      // DriverShell always needs the token from storage for this running
      // session, but DriverSplashScreen only auto-continues past login on
      // the next launch when this was set — that's what "remember me"
      // actually controls here.
      await prefs.setBool('remember_me', _rememberMe);

      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const DriverShell()), (route) => false);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Connection error. Please check your network and try again.';
        _loading = false;
      });
    }
  }

  void _biometricStub() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Biometric login isn't wired up in this preview."), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.3))),
                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 20),
                const Text('Welcome back', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Sign in to start your shift', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13.5)),
                const SizedBox(height: 28),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LabeledField(label: 'Email or phone', controller: _identifierController, hint: 'you@example.com', keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 16),
                      LabeledField(
                        label: 'Password',
                        controller: _passwordController,
                        obscure: _obscure,
                        hint: 'Enter your password',
                        suffix: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19, color: AppColors.slate500),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => setState(() => _rememberMe = !_rememberMe),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_rememberMe ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 18, color: AppColors.teal600),
                                const SizedBox(width: 6),
                                const Text('Remember me', style: TextStyle(fontSize: 12.5, color: AppColors.slate600, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DriverForgotPasswordScreen())),
                            style: TextButton.styleFrom(foregroundColor: AppColors.teal700, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            child: const Text('Forgot password?', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      MessageBanner(error: _error),
                      const SizedBox(height: 18),
                      GradientButton(label: 'Log in', icon: Icons.arrow_forward_rounded, loading: _loading, onPressed: _loading ? null : _login),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.slate300)),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('or', style: TextStyle(color: AppColors.slate500, fontSize: 11.5, fontWeight: FontWeight.w600))),
                          Expanded(child: Divider(color: AppColors.slate300)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _biometricStub,
                          icon: const Icon(Icons.fingerprint_rounded, size: 18),
                          label: const Text('Use biometric login'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.teal700,
                            side: BorderSide(color: AppColors.teal600.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                      children: [
                        const TextSpan(text: 'New driver? '),
                        TextSpan(
                          text: 'Create an account',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()..onTap = () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DriverRegisterScreen())),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
