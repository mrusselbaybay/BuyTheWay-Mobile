import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/common.dart';

/// 6-digit OTP entry with a resend countdown. There is no SMS gateway
/// behind this — the accepted code is hardcoded and shown on-screen so the
/// mock is honest about what it is rather than pretending to send a real
/// text message.
class DriverOtpScreen extends StatefulWidget {
  final String phone;
  final VoidCallback onVerified;
  const DriverOtpScreen({super.key, required this.phone, required this.onVerified});

  @override
  State<DriverOtpScreen> createState() => _DriverOtpScreenState();
}

class _DriverOtpScreenState extends State<DriverOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  Timer? _timer;
  int _secondsLeft = 30;
  String _error = '';
  bool _verifying = false;

  static const _demoCode = '123456';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsLeft = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = '';
    });
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    if (_code != _demoCode) {
      setState(() {
        _verifying = false;
        _error = 'Incorrect code. Try the demo code below.';
      });
      return;
    }
    setState(() => _verifying = false);
    widget.onVerified();
  }

  void _resend() {
    if (_secondsLeft > 0) return;
    HapticFeedback.selectionClick();
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A new code has been "sent" (demo code stays 123456).'), behavior: SnackBarBehavior.floating),
    );
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
                const Text('Verify your number', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Enter the 6-digit code sent to ${widget.phone.isEmpty ? 'your phone' : widget.phone}',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13.5),
                ),
                const SizedBox(height: 28),
                GlassPanel(
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(6, (i) => _otpBox(i))),
                      MessageBanner(error: _error),
                      const SizedBox(height: 18),
                      GradientButton(label: 'Verify', icon: Icons.check_rounded, loading: _verifying, onPressed: _verifying ? null : _verify),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: _secondsLeft == 0 ? _resend : null,
                        child: Text(
                          _secondsLeft == 0 ? 'Resend code' : 'Resend in ${_secondsLeft}s',
                          style: TextStyle(color: _secondsLeft == 0 ? AppColors.teal700 : AppColors.slate400, fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.teal50, borderRadius: BorderRadius.circular(10)),
                        child: const Text('Preview build — demo code is 123456', style: TextStyle(fontSize: 11, color: AppColors.teal700, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 44,
      height: 54,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.slate800),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white.withOpacity(0.6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.6))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.6))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.teal500, width: 1.6)),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          setState(() {});
        },
      ),
    );
  }
}
