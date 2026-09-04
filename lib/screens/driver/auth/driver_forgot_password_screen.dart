import 'package:flutter/material.dart';

import '../../../widgets/common.dart';

/// Password reset request screen. No email is actually sent — the success
/// state is shown after a simulated delay, matching the rest of this
/// module's "hardcoded for now" scope.
class DriverForgotPasswordScreen extends StatefulWidget {
  const DriverForgotPasswordScreen({super.key});

  @override
  State<DriverForgotPasswordScreen> createState() => _DriverForgotPasswordScreenState();
}

class _DriverForgotPasswordScreenState extends State<DriverForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _sent = false;
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_emailController.text.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Reset password', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text("We'll send a reset link to your email", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13.5)),
                const SizedBox(height: 28),
                GlassPanel(child: _sent ? _sentState() : _formState()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledField(label: 'Email address', controller: _emailController, hint: 'you@example.com', keyboardType: TextInputType.emailAddress),
        MessageBanner(error: _error),
        const SizedBox(height: 18),
        GradientButton(label: 'Send reset link', icon: Icons.send_rounded, loading: _loading, onPressed: _loading ? null : _send),
      ],
    );
  }

  Widget _sentState() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.successGreen.withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.mark_email_read_rounded, color: AppColors.successGreen, size: 26),
        ),
        const SizedBox(height: 14),
        const Text('Check your inbox', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.slate800)),
        const SizedBox(height: 6),
        Text('A reset link was sent to ${_emailController.text.trim()}.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.slate600)),
        const SizedBox(height: 18),
        OutlineActionButton(label: 'Back to log in', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}
