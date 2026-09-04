import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../driver_theme.dart';
import 'widgets/settings_widgets.dart';

/// The "Deactivate account" confirmation dialog — requires typing the
/// literal word DEACTIVATE plus the current password before the button
/// activates, matching the deliberately high-friction pattern the rest of
/// the app uses for irreversible actions. [onDeactivated] runs after the
/// backend confirms — the caller (Settings hub) owns what "signed out"
/// means (clearing the token, navigating to the login screen), this
/// dialog only owns the confirmation UI and the API call itself.
Future<void> showDeactivateAccountDialog(
  BuildContext context, {
  required ApiService api,
  required String accessToken,
  required Future<void> Function() onDeactivated,
}) {
  final confirmPhrase = TextEditingController();
  final password = TextEditingController();
  String error = '';
  bool submitting = false;

  return showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        Future<void> confirm() async {
          setDialogState(() {
            submitting = true;
            error = '';
          });
          try {
            await api.deactivateDriverAccount(
              accessToken: accessToken,
              confirmationPhrase: confirmPhrase.text.trim(),
              password: password.text,
            );
            Navigator.pop(dialogContext);
            if (context.mounted) {
              SettingsToast.success(context, 'Your account has been deactivated. Signing you out…');
            }
            await Future.delayed(const Duration(milliseconds: 900));
            // Always sign out, even if the toast above couldn't show because
            // the screen was already gone — deactivation already succeeded
            // on the server, so the local session must end regardless.
            await onDeactivated();
          } on ApiException catch (e) {
            setDialogState(() {
              submitting = false;
              error = e.message;
            });
          } catch (_) {
            setDialogState(() {
              submitting = false;
              error = 'Could not deactivate your account. Try again.';
            });
          }
        }

        final canSubmit = confirmPhrase.text.trim() == 'DEACTIVATE' && password.text.isNotEmpty && !submitting;

        return AlertDialog(
          title: const Text('Deactivate your account?', style: TextStyle(color: DriverColors.error, fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This is irreversible. Deactivating will immediately end your session and require support assistance to reactivate.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                const Text('Type DEACTIVATE to confirm', style: DriverText.label),
                const SizedBox(height: 6),
                TextField(
                  controller: confirmPhrase,
                  autocorrect: false,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: DriverColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 14),
                const Text('Current password', style: DriverText.label),
                const SizedBox(height: 6),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: DriverColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(error, style: const TextStyle(color: DriverColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: DriverColors.error),
              onPressed: canSubmit ? confirm : null,
              child: Text(submitting ? 'Deactivating…' : 'Deactivate account'),
            ),
          ],
        );
      },
    ),
  );
}
