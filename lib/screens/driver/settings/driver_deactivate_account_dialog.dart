import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../driver_theme.dart';
import 'widgets/settings_widgets.dart';

/// Confirms courier account deactivation with the exact phrase and current
/// password before calling the backend. The settings hub owns signing out.
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
  bool passwordVisible = false;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
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
              confirmationPhrase: confirmPhrase.text.trim().toUpperCase(),
              password: password.text,
            );
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            if (context.mounted) {
              SettingsToast.success(context,
                  'Your account has been deactivated. Signing you out…');
            }
            await Future.delayed(const Duration(milliseconds: 900));
            // Deactivation succeeded on the server, so end the local session
            // even if the settings screen disappeared before the toast showed.
            await onDeactivated();
          } on ApiException catch (e) {
            if (!dialogContext.mounted) return;
            setDialogState(() {
              submitting = false;
              error = e.message;
            });
          } catch (_) {
            if (!dialogContext.mounted) return;
            setDialogState(() {
              submitting = false;
              error = 'Could not deactivate your account. Try again.';
            });
          }
        }

        final canSubmit =
            confirmPhrase.text.trim().toUpperCase() == 'DEACTIVATE' &&
                password.text.isNotEmpty &&
                !submitting;

        return PopScope(
          canPop: !submitting,
          child: Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: 440,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.9),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: DriverColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: DriverColors.errorSurface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.person_off_outlined,
                                color: DriverColors.error, size: 21),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Cancel',
                            onPressed: submitting
                                ? null
                                : () => Navigator.pop(dialogContext),
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                              foregroundColor: DriverColors.textSecondary,
                              backgroundColor: DriverColors.background,
                            ),
                            icon: const Icon(Icons.close_rounded, size: 19),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('ACCOUNT ACCESS',
                          style: DriverText.label.copyWith(
                              color: DriverColors.error, letterSpacing: 1.1)),
                      const SizedBox(height: 5),
                      const Text('Deactivate account?',
                          style: TextStyle(
                              color: DriverColors.textPrimary,
                              fontSize: 23,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.55)),
                      const SizedBox(height: 8),
                      const Text(
                        'This will end your courier session. You’ll need Support to restore access.',
                        style: TextStyle(
                            color: DriverColors.textSecondary,
                            fontSize: 13,
                            height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      const _DeactivationConsequence(
                        icon: Icons.logout_outlined,
                        title: 'You’ll be signed out',
                        subtitle:
                            'Your session ends as soon as deactivation succeeds.',
                      ),
                      const SizedBox(height: 10),
                      const _DeactivationConsequence(
                        icon: Icons.support_agent_outlined,
                        title: 'Reactivation needs Support',
                        subtitle:
                            'You can’t turn courier access back on from the app.',
                      ),
                      const SizedBox(height: 20),
                      const _FieldLabel(
                          number: '01', text: 'Confirm the action'),
                      const SizedBox(height: 7),
                      TextField(
                        controller: confirmPhrase,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        decoration: _deactivationInputDecoration(
                          hintText: 'Type DEACTIVATE',
                          prefixIcon: Icons.keyboard_outlined,
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel(
                          number: '02', text: 'Verify your password'),
                      const SizedBox(height: 7),
                      TextField(
                        controller: password,
                        obscureText: !passwordVisible,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: canSubmit ? (_) => confirm() : null,
                        decoration: _deactivationInputDecoration(
                          hintText: 'Current password',
                          prefixIcon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            tooltip: passwordVisible
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: () => setDialogState(
                                () => passwordVisible = !passwordVisible),
                            icon: Icon(passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                          ),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: error.isEmpty
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    color: DriverColors.errorSurface,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.error_outline_rounded,
                                          size: 17, color: DriverColors.error),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(error,
                                            style: const TextStyle(
                                                color: DriverColors.error,
                                                fontSize: 12,
                                                height: 1.35,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: submitting
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                foregroundColor: DriverColors.textPrimary,
                                side: const BorderSide(
                                    color: DriverColors.border),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Keep account'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: canSubmit ? confirm : null,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor: DriverColors.error,
                                disabledBackgroundColor:
                                    DriverColors.error.withValues(alpha: 0.28),
                                foregroundColor: Colors.white,
                                disabledForegroundColor:
                                    Colors.white.withValues(alpha: 0.82),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 160),
                                child: submitting
                                    ? const Row(
                                        key: ValueKey('submitting'),
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          ),
                                          SizedBox(width: 8),
                                          Text('Deactivating'),
                                        ],
                                      )
                                    : const Text('Deactivate',
                                        key: ValueKey('deactivate')),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  ).whenComplete(() {
    confirmPhrase.dispose();
    password.dispose();
  });
}

class _DeactivationConsequence extends StatelessWidget {
  const _DeactivationConsequence({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: DriverColors.background,
          borderRadius: BorderRadius.circular(13),
          border:
              Border.all(color: DriverColors.border.withValues(alpha: 0.75)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: DriverColors.primaryDark),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: DriverColors.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: DriverColors.textSecondary,
                          fontSize: 10.5,
                          height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(number,
              style: const TextStyle(
                  color: DriverColors.primaryDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  color: DriverColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ],
      );
}

InputDecoration _deactivationInputDecoration({
  required String hintText,
  required IconData prefixIcon,
  Widget? suffixIcon,
}) =>
    InputDecoration(
      hintText: hintText,
      hintStyle:
          const TextStyle(color: DriverColors.textSecondary, fontSize: 12.5),
      prefixIcon: Icon(prefixIcon, size: 18, color: DriverColors.textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: DriverColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: DriverColors.primary, width: 1.5),
      ),
    );
