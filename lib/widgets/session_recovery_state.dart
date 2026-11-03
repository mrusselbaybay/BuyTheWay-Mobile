import 'package:flutter/material.dart';

import 'brand_logo.dart';

/// Branded recovery state for an expired session or a failed account load.
class SessionRecoveryState extends StatelessWidget {
  const SessionRecoveryState({
    super.key,
    required this.message,
    required this.onSignIn,
    this.onRetry,
    this.detailNote,
  });

  final String message;
  final VoidCallback onSignIn;
  final VoidCallback? onRetry;
  final String? detailNote;

  static const _teal = Color(0xFF0D9488);
  static const _darkTeal = Color(0xFF0F766E);
  static const _ink = Color(0xFF172923);
  static const _muted = Color(0xFF64748B);
  static const _canvas = Color(0xFFF4F8F7);

  @override
  Widget build(BuildContext context) {
    final expired = message.toLowerCase().contains('session has expired');
    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BagLogo(size: 32),
                        SizedBox(width: 9),
                        BrandWordmark(fontSize: 20),
                      ],
                    ),
                    const SizedBox(height: 42),
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDDF1EC),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              expired ? Icons.lock_clock_rounded : Icons.wifi_off_rounded,
                              size: 46,
                              color: _darkTeal,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 1,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: _canvas, width: 3),
                              ),
                              child: Icon(
                                expired ? Icons.key_rounded : Icons.refresh_rounded,
                                size: 17,
                                color: _teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F4F1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        expired ? 'SECURE ACCOUNT ACCESS' : 'CONNECTION CHECK',
                        style: const TextStyle(
                          color: _darkTeal,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      expired ? 'Your session has expired' : 'We could not load your account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 23,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      expired ? 'Sign in again to return to your account.' : message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
                    ),
                    if (detailNote != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE1EAE7)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.shield_outlined, size: 18, color: _teal),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                detailNote!,
                                style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    if (onRetry != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: onRetry,
                          style: FilledButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 19),
                          label: const Text('Try again'),
                        ),
                      ),
                      const SizedBox(height: 11),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: onSignIn,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _darkTeal,
                          side: const BorderSide(color: Color(0xFFB9D7D1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: Text(onRetry == null ? 'Sign in again' : 'Back to sign in'),
                      ),
                    ),
                  ],
                ),
              ),
          ),
        ),
      ),
    );
  }
}
