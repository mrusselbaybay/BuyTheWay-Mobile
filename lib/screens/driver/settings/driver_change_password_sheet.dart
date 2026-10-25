import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../widgets/password_strength_meter.dart';
import '../driver_theme.dart';
import 'widgets/settings_widgets.dart';

/// The Change Password flow, as a self-contained bottom sheet — reuses the
/// same `/api/password/*` email-code endpoints the buyer web account
/// settings page uses (see PasswordResetController): request a 6-digit
/// code by email, verify it, then set the new password.
///
/// Pulled out of the settings screen it used to live inside so it can be
/// opened from anywhere in the Security section without that screen
/// needing to own 200+ lines of sheet-building logic itself.
Future<void> showChangePasswordSheet(
  BuildContext context, {
  required ApiService api,
  required String email,
}) {
  String step = 'request'; // request | verify | update
  bool sending = false;
  String error = '';
  final codeDigits = List<String>.filled(6, '');
  final codeInputs = List<FocusNode?>.filled(6, null);
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  bool obscure1 = true, obscure2 = true;
  bool submitting = false;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Future<void> requestCode() async {
          setSheetState(() {
            sending = true;
            error = '';
          });
          try {
            await api.sendPasswordResetCode(email);
            setSheetState(() {
              sending = false;
              step = 'verify';
            });
          } on ApiException catch (e) {
            setSheetState(() {
              sending = false;
              error = e.message;
            });
          } catch (_) {
            setSheetState(() {
              sending = false;
              error = 'Could not send the code. Check your connection.';
            });
          }
        }

        Future<void> verifyCode() async {
          final code = codeDigits.join();
          if (code.length != 6) return;
          setSheetState(() {
            sending = true;
            error = '';
          });
          try {
            await api.verifyPasswordResetCode(email, code);
            setSheetState(() {
              sending = false;
              step = 'update';
            });
          } on ApiException catch (e) {
            setSheetState(() {
              sending = false;
              error = e.message;
            });
          } catch (_) {
            setSheetState(() {
              sending = false;
              error = 'Could not verify the code. Try again.';
            });
          }
        }

        Future<void> submitNewPassword() async {
          if (newPassword.text.length < 8) {
            setSheetState(() => error = 'Password must be at least 8 characters.');
            return;
          }
          if (newPassword.text != confirmPassword.text) {
            setSheetState(() => error = 'Passwords do not match.');
            return;
          }
          setSheetState(() {
            submitting = true;
            error = '';
          });
          try {
            await api.resetPassword(email, codeDigits.join(), newPassword.text, confirmPassword.text);
            Navigator.pop(sheetContext);
            if (!context.mounted) return;
            SettingsToast.success(context, 'Password changed successfully.');
          } on ApiException catch (e) {
            setSheetState(() {
              submitting = false;
              error = e.message;
            });
          } catch (_) {
            setSheetState(() {
              submitting = false;
              error = 'Could not update your password. Try again.';
            });
          }
        }

        Widget stepRequest() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "We'll send a 6-digit verification code to ${SettingsFormat.maskedEmail(email)} to confirm it's really you.",
                  style: DriverText.body,
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(error, style: const TextStyle(color: DriverColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: sending ? null : requestCode,
                    style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(sending ? 'Sending…' : 'Send code', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            );

        Widget stepVerify() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enter the 6-digit code sent to ${SettingsFormat.maskedEmail(email)}.', style: DriverText.body),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    codeInputs[i] ??= FocusNode();
                    return SizedBox(
                      width: 42,
                      child: TextField(
                        focusNode: codeInputs[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: DriverColors.background,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) {
                          setSheetState(() {
                            codeDigits[i] = v;
                            error = '';
                          });
                          if (v.isNotEmpty && i < 5) {
                            FocusScope.of(sheetContext).requestFocus(codeInputs[i + 1]);
                          }
                          if (codeDigits.join().length == 6) verifyCode();
                        },
                      ),
                    );
                  }),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(error, style: const TextStyle(color: DriverColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: sending ? null : requestCode,
                    style: TextButton.styleFrom(foregroundColor: DriverColors.primary, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text(sending ? 'Sending…' : 'Resend code', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: sending || codeDigits.join().length != 6 ? null : verifyCode,
                    style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(sending ? 'Verifying…' : 'Verify code', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            );

        Widget stepUpdate() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New password', style: DriverText.label),
                const SizedBox(height: 6),
                TextField(
                  controller: newPassword,
                  obscureText: obscure1,
                  onChanged: (_) => setSheetState(() => error = ''),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: DriverColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19),
                      onPressed: () => setSheetState(() => obscure1 = !obscure1),
                    ),
                  ),
                ),
                PasswordStrengthMeter(password: newPassword.text),
                const SizedBox(height: 12),
                const Text('Confirm new password', style: DriverText.label),
                const SizedBox(height: 6),
                TextField(
                  controller: confirmPassword,
                  obscureText: obscure2,
                  onChanged: (_) => setSheetState(() => error = ''),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: DriverColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19),
                      onPressed: () => setSheetState(() => obscure2 = !obscure2),
                    ),
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(error, style: const TextStyle(color: DriverColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: submitting ? null : submitNewPassword,
                    style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(submitting ? 'Updating…' : 'Update password', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            );

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
                const Row(
                  children: [
                    Icon(Icons.lock_reset_rounded, color: DriverColors.primary),
                    SizedBox(width: 8),
                    Text('Change password', style: DriverText.title),
                  ],
                ),
                const SizedBox(height: 16),
                if (step == 'request') stepRequest() else if (step == 'verify') stepVerify() else stepUpdate(),
              ],
            ),
          ),
        );
      },
    ),
  ).whenComplete(() {
    for (final node in codeInputs) {
      node?.dispose();
    }
  });
}
