import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/driver/driver_theme.dart';
import '../screens/driver/settings/widgets/settings_widgets.dart';
import '../services/api_service.dart';
import 'password_strength_meter.dart';

/// Runs the action behind a [showPasswordConfirmSheet]. Return `null` when it
/// succeeded (the sheet closes), an empty string when the user backed out of
/// something along the way (the sheet stays, silently), or a message to show
/// inline.
typedef PasswordSubmit = Future<String?> Function(String password);

/// Bottom sheet asking for the account's current password before a sensitive
/// change (connecting / disconnecting Google).
Future<void> showPasswordConfirmSheet(
  BuildContext context, {
  required String title,
  required IconData icon,
  required String message,
  required String actionLabel,
  required PasswordSubmit onSubmit,
  bool destructive = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PasswordConfirmSheet(
      title: title,
      icon: icon,
      message: message,
      actionLabel: actionLabel,
      destructive: destructive,
      onSubmit: onSubmit,
    ),
  );
}

/// Bottom sheet for a Google-only account to set its first password: an
/// emailed 6-digit code, then the new password. Pops the refreshed
/// sign-in-methods map, or an empty map when a password already existed
/// (caller should reload).
Future<Map<String, dynamic>?> showSetPasswordSheet(
  BuildContext context, {
  required ApiService api,
  required String token,
  required String email,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SetPasswordSheet(api: api, token: token, email: email),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: DriverColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(children: [
                Icon(icon, color: DriverColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: DriverText.title)),
              ]),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    this.autofillHint = AutofillHints.password,
    this.onChanged,
    this.error,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String autofillHint;
  final ValueChanged<String>? onChanged;
  final String? error;
  final bool autofocus;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsFieldLabel(widget.label),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          autofocus: widget.autofocus,
          autofillHints: [widget.autofillHint],
          onChanged: widget.onChanged,
          style: DriverText.body,
          decoration: InputDecoration(
            filled: true,
            fillColor: DriverColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: widget.error != null ? DriverColors.error : Colors.transparent),
            ),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show password' : 'Hide password',
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        SettingsFieldError(widget.error),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed, this.destructive = false});

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: destructive ? DriverColors.error : DriverColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        liveRegion: true,
        child: Text(message,
            style: const TextStyle(color: DriverColors.error, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confirm with current password
// ---------------------------------------------------------------------------

class _PasswordConfirmSheet extends StatefulWidget {
  const _PasswordConfirmSheet({
    required this.title,
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.destructive,
    required this.onSubmit,
  });

  final String title;
  final IconData icon;
  final String message;
  final String actionLabel;
  final bool destructive;
  final PasswordSubmit onSubmit;

  @override
  State<_PasswordConfirmSheet> createState() => _PasswordConfirmSheetState();
}

class _PasswordConfirmSheetState extends State<_PasswordConfirmSheet> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.onSubmit(_password.text);
    if (!mounted) return;
    if (result == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = result.isEmpty ? null : result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: widget.title,
      icon: widget.icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: DriverText.body),
          const SizedBox(height: 14),
          _PasswordField(
            label: 'Current password',
            controller: _password,
            autofocus: true,
            error: _error,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 18),
          _PrimaryButton(
            label: _busy ? 'Please wait…' : widget.actionLabel,
            destructive: widget.destructive,
            onPressed: _busy || _password.text.isEmpty ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Set a password (Google-only accounts)
// ---------------------------------------------------------------------------

class _SetPasswordSheet extends StatefulWidget {
  const _SetPasswordSheet({required this.api, required this.token, required this.email});

  final ApiService api;
  final String token;
  final String email;

  @override
  State<_SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends State<_SetPasswordSheet> {
  static const _resendSeconds = 60;

  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  int _cooldown = 0;
  Timer? _timer;
  String? _error;
  String? _codeError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _cooldown = _resendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = (_cooldown - 1).clamp(0, _resendSeconds));
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.sendPasswordResetCode(widget.email);
    } on ApiException catch (e) {
      // 429: a code was just sent; carry on to entering it.
      if (e.statusCode != 429) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = e.message;
          });
        }
        return;
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not send the code. Check your connection.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _codeSent = true;
    });
    _startCooldown();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final code = _code.text.trim();
    setState(() {
      _error = null;
      _codeError = RegExp(r'^\d{6}$').hasMatch(code) ? null : 'Enter the 6-digit code.';
      _passwordError = _password.text.length >= 8 ? null : 'Use at least 8 characters.';
      _confirmError = _confirm.text == _password.text ? null : 'The passwords do not match.';
    });
    if (_codeError != null || _passwordError != null || _confirmError != null) return;

    setState(() => _busy = true);
    try {
      final result = await widget.api.setPassword(
        widget.token,
        code: code,
        password: _password.text,
        passwordConfirmation: _confirm.text,
      );
      if (mounted) Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'password_already_set') {
        Navigator.of(context).pop(<String, dynamic>{});
        return;
      }
      setState(() {
        _busy = false;
        if (e.code == 'otp_invalid') {
          _codeError = e.message;
        } else {
          _error = e.message;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not set your password. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final masked = SettingsFormat.maskedEmail(widget.email);
    return _SheetFrame(
      title: 'Set a password',
      icon: Icons.lock_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Use your email ${widget.email} + this password on any device.', style: DriverText.body),
          const SizedBox(height: 14),
          if (!_codeSent) ...[
            Text("We'll email a 6-digit code to $masked to confirm it's really you.", style: DriverText.caption),
            if (_error != null) _InlineError(_error!),
            const SizedBox(height: 18),
            _PrimaryButton(label: _busy ? 'Sending…' : 'Email me a code', onPressed: _busy ? null : _sendCode),
          ] else ...[
            SettingsFieldLabel('6-digit code sent to $masked'),
            const SizedBox(height: 6),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              onChanged: (_) => setState(() => _codeError = null),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 6),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: DriverColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _codeError != null ? DriverColors.error : Colors.transparent),
                ),
              ),
            ),
            SettingsFieldError(_codeError),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy || _cooldown > 0 ? null : _sendCode,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(_cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend code',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ),
            _PasswordField(
              label: 'New password',
              controller: _password,
              autofillHint: AutofillHints.newPassword,
              error: _passwordError,
              onChanged: (_) => setState(() => _passwordError = null),
            ),
            PasswordStrengthMeter(password: _password.text),
            const SizedBox(height: 12),
            _PasswordField(
              label: 'Confirm new password',
              controller: _confirm,
              autofillHint: AutofillHints.newPassword,
              error: _confirmError,
              onChanged: (_) => setState(() => _confirmError = null),
            ),
            if (_error != null) _InlineError(_error!),
            const SizedBox(height: 18),
            _PrimaryButton(label: _busy ? 'Saving…' : 'Set password', onPressed: _busy ? null : _submit),
          ],
        ],
      ),
    );
  }
}
