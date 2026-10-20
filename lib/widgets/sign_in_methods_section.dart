import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/driver/driver_theme.dart';
import '../screens/driver/settings/driver_change_password_sheet.dart';
import '../screens/driver/settings/widgets/settings_widgets.dart';
import '../services/api_service.dart';
import '../services/google_auth_service.dart';
import 'sign_in_methods_sheets.dart';
import 'solid_ui.dart' show GoogleMark;

/// Which ways the signed-in profile can log in. Lives on the profile, so
/// every role of the account shows the same thing.
class SignInMethodsState {
  const SignInMethodsState({
    required this.email,
    required this.hasPassword,
    required this.hasGoogle,
    this.googleEmail,
    this.googleLinkedAt,
  });

  factory SignInMethodsState.fromJson(Map<String, dynamic> json) => SignInMethodsState(
        email: (json['email'] ?? '') as String,
        hasPassword: json['has_password'] == true,
        hasGoogle: json['has_google'] == true,
        googleEmail: json['google_email'] as String?,
        googleLinkedAt: DateTime.tryParse((json['google_linked_at'] ?? '') as String),
      );

  final String email;
  final bool hasPassword;
  final bool hasGoogle;
  final String? googleEmail;
  final DateTime? googleLinkedAt;
}

/// "Sign-in methods" for Login & Security (buyer, driver/courier, logistics):
/// email + password (change, or set one on a Google-only account) and the
/// connected Google account (connect / disconnect). Replaces each screen's
/// own "Change password" row.
class SignInMethodsSection extends StatefulWidget {
  const SignInMethodsSection({super.key});

  @override
  State<SignInMethodsSection> createState() => _SignInMethodsSectionState();
}

class _SignInMethodsSectionState extends State<SignInMethodsSection> {
  final ApiService _api = ApiService();
  SignInMethodsState? _state;
  String? _token;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String> _requireToken() async {
    _token ??= (await SharedPreferences.getInstance()).getString('auth_token');
    final token = _token;
    if (token == null || token.isEmpty) {
      throw ApiException(message: 'Your session has expired. Please sign in again.', statusCode: 401);
    }
    return token;
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final json = await _api.getSignInMethods(await _requireToken());
      if (mounted) setState(() => _state = SignInMethodsState.fromJson(json));
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load your sign-in methods.');
    }
  }

  /// Applies a server-confirmed state (never optimistic).
  void _apply(Map<String, dynamic> json) {
    if (mounted) setState(() => _state = SignInMethodsState.fromJson(json));
  }

  // ---------------------------------------------------------------- actions

  Future<void> _connectGoogle() async {
    final token = await _requireToken();
    if (!mounted) return;
    await showPasswordConfirmSheet(
      context,
      title: 'Connect Google',
      icon: Icons.link_rounded,
      message:
          "Enter your current password, then choose the Google account to connect. It doesn't have to use the same email as this account.",
      actionLabel: 'Continue with Google',
      onSubmit: (password) async {
        try {
          final idToken = await GoogleAuthService.instance.pickIdToken();
          if (idToken == null) return ''; // cancelled: stay quiet
          final json = await _api.linkGoogle(token, idToken: idToken, currentPassword: password);
          _apply(json);
          if (mounted) SettingsToast.success(context, 'Google connected.');
          return null;
        } on ApiException catch (e) {
          if (e.code == 'already_linked') _load();
          return _linkMessage(e);
        } on GoogleAuthException catch (e) {
          return e.toString();
        } catch (_) {
          return 'Could not connect Google. Check your connection and try again.';
        } finally {
          // Don't leave the chosen account signed in on the device.
          await GoogleAuthService.instance.signOut();
        }
      },
    );
  }

  Future<void> _disconnectGoogle() async {
    final token = await _requireToken();
    if (!mounted) return;
    await showPasswordConfirmSheet(
      context,
      title: 'Disconnect Google?',
      icon: Icons.link_off_rounded,
      message:
          "You won't be able to sign in with ${_state?.googleEmail ?? 'Google'} anymore. You can still sign in with your email and password.",
      actionLabel: 'Disconnect',
      destructive: true,
      onSubmit: (password) async {
        try {
          _apply(await _api.disconnectGoogle(token, password));
          if (mounted) SettingsToast.success(context, 'Google disconnected.');
          return null;
        } on ApiException catch (e) {
          return _linkMessage(e);
        } catch (_) {
          return 'Could not disconnect Google. Check your connection and try again.';
        }
      },
    );
  }

  Future<void> _setPassword() async {
    final state = _state;
    if (state == null) return;
    final token = await _requireToken();
    if (!mounted) return;
    final result = await showSetPasswordSheet(context, api: _api, token: token, email: state.email);
    if (result == null) return;
    if (result.isEmpty) return _load(); // a password already existed
    _apply(result);
    if (mounted) SettingsToast.success(context, 'Password set. You can now sign in with your email and password.');
  }

  static String _linkMessage(ApiException e) {
    switch (e.code) {
      case 'invalid_password':
        return "That isn't your current password.";
      case 'too_many_attempts':
        return 'Too many attempts. Try again in a minute.';
      case 'google_already_linked_other':
        return 'That Google account is already connected to another BuyTheWay account.';
      case 'google_email_belongs_to_other':
        return 'That Google email belongs to another BuyTheWay account.';
      case 'google_email_unverified':
        return "Google couldn't verify that account's email.";
      case 'already_linked':
        return 'A Google account is already connected. Disconnect it first.';
      case 'no_password_set':
        return 'Set a password first.';
      case 'invalid_token':
        return 'Google sign-in failed. Please try again.';
      default:
        return e.message;
    }
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionLabel('Sign-in methods'),
        if (state != null)
          SettingsGroupCard(dividerIndent: 64, children: [
            _passwordTile(state),
            _googleTile(state),
          ])
        else if (_loadError != null)
          SettingsErrorBanner(message: _loadError!, onRetry: _load)
        else
          const _SignInSkeleton(),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _passwordTile(SignInMethodsState s) {
    return _MethodTile(
      icon: const Icon(Icons.mail_outline_rounded, size: 18, color: DriverColors.primary),
      title: 'Email & password',
      lines: s.hasPassword
          ? [s.email, 'Password set']
          : ['No password yet', 'Use your email ${s.email} + this password on any device'],
      actionLabel: s.hasPassword ? 'Change' : 'Set password',
      onAction: s.hasPassword
          ? () => showChangePasswordSheet(context, api: _api, email: s.email)
          : _setPassword,
    );
  }

  Widget _googleTile(SignInMethodsState s) {
    final linked = s.googleLinkedAt;
    return _MethodTile(
      icon: const SizedBox(width: 20, height: 20, child: GoogleMark()),
      iconBackground: Colors.white,
      title: 'Google',
      lines: s.hasGoogle
          ? [
              s.googleEmail ?? 'Connected',
              if (linked != null) 'Connected on ${SettingsFormat.dateShort(linked)}',
              if (!s.hasPassword) 'Set a password first to disconnect',
            ]
          : ['Not connected', 'Enables one-tap sign-in with Google'],
      actionLabel: s.hasGoogle ? 'Disconnect' : 'Connect',
      destructive: s.hasGoogle,
      onAction: s.hasGoogle ? (s.hasPassword ? _disconnectGoogle : null) : _connectGoogle,
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.lines,
    required this.actionLabel,
    required this.onAction,
    this.iconBackground,
    this.destructive = false,
  });

  final Widget icon;
  final Color? iconBackground;
  final String title;
  final List<String> lines;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? DriverColors.error : DriverColors.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBackground ?? DriverColors.primary.withValues(alpha: 0.12),
              border: iconBackground == null ? null : Border.all(color: DriverColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: icon,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: DriverColors.textPrimary)),
                for (final line in lines) ...[
                  const SizedBox(height: 2),
                  Text(line, style: DriverText.caption),
                ],
              ],
            ),
          ),
          Semantics(
            button: true,
            enabled: onAction != null,
            label: '$actionLabel $title',
            excludeSemantics: true,
            child: TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: color,
                minimumSize: const Size(64, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(actionLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same footprint as the loaded card (two tiles) so nothing jumps on load.
class _SignInSkeleton extends StatelessWidget {
  const _SignInSkeleton();

  Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: const Color(0xFFE9ECF1), borderRadius: BorderRadius.circular(6)),
      );

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SizedBox(
        height: 48,
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: const Color(0xFFE9ECF1), borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(width: 14),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_bar(110, 13), const SizedBox(height: 8), _bar(170, 10)],
          ),
        ]),
      ),
    );
    final card = SettingsGroupCard(dividerIndent: 64, children: [row, row]);
    if (MediaQuery.disableAnimationsOf(context)) return card;
    return Semantics(
      label: 'Loading sign-in methods',
      child: ExcludeSemantics(
        child: card.animate(onPlay: (c) => c.repeat()).shimmer(
              duration: 1200.ms,
              color: Colors.white.withValues(alpha: 0.6),
            ),
      ),
    );
  }
}
