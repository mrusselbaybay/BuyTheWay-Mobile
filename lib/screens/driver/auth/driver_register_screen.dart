import 'package:flutter/material.dart';

import '../../../widgets/common.dart';
import '../../../widgets/password_strength_meter.dart';
import '../driver_shell.dart';
import 'driver_otp_screen.dart';

/// Two-step driver registration (personal/vehicle info, then password),
/// finishing with phone OTP verification. All hardcoded/mocked — there is
/// no backend account created here.
class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  int _step = 0;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _vehicleType;
  String _error = '';
  bool _obscure = true;

  static const _vehicleTypes = ['Motorcycle', 'Bicycle', 'Sedan', 'Van', 'Truck'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0) {
      if (_nameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty ||
          _vehicleType == null ||
          _plateController.text.trim().isEmpty) {
        setState(() => _error = 'Please fill in all fields to continue.');
        return;
      }
      setState(() {
        _error = '';
        _step = 1;
      });
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = "Passwords don't match.");
      return;
    }
    setState(() => _error = '');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverOtpScreen(
          phone: _phoneController.text.trim(),
          onVerified: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const DriverShell()), (route) => false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => _step == 0 ? Navigator.pop(context) : setState(() => _step = 0),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text('Create your account', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  _step == 0 ? 'Tell us about you and your vehicle' : 'Secure your account',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13.5),
                ),
                const SizedBox(height: 18),
                StepIndicator(total: 2, currentIndex: _step),
                const SizedBox(height: 22),
                GlassPanel(child: _step == 0 ? _stepOne() : _stepTwo()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledField(label: 'Full name', controller: _nameController, hint: 'Juan Dela Cruz'),
        const SizedBox(height: 14),
        LabeledField(label: 'Email', controller: _emailController, hint: 'you@example.com', keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        LabeledField(label: 'Phone number', controller: _phoneController, hint: '+63 9XX XXX XXXX', keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        LabeledDropdown(label: 'Vehicle type', items: _vehicleTypes, value: _vehicleType, hint: 'Select your vehicle', onChanged: (v) => setState(() => _vehicleType = v)),
        const SizedBox(height: 14),
        LabeledField(label: 'Plate number', controller: _plateController, hint: 'NBC 2245'),
        MessageBanner(error: _error),
        const SizedBox(height: 18),
        GradientButton(label: 'Continue', icon: Icons.arrow_forward_rounded, onPressed: _next),
      ],
    );
  }

  Widget _stepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledField(
          label: 'Password',
          controller: _passwordController,
          obscure: _obscure,
          hint: 'At least 6 characters',
          suffix: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19, color: AppColors.slate500),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _passwordController,
          builder: (context, value, _) =>
              PasswordStrengthMeter(password: value.text),
        ),
        const SizedBox(height: 14),
        LabeledField(label: 'Confirm password', controller: _confirmController, obscure: _obscure, hint: 'Re-enter your password'),
        MessageBanner(error: _error),
        const SizedBox(height: 18),
        GradientButton(label: 'Create account', icon: Icons.check_rounded, onPressed: _next),
      ],
    );
  }
}
