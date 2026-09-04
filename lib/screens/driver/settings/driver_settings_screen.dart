import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/api_service.dart';
import '../auth/driver_login_screen.dart';
import '../driver_models.dart';
import '../driver_theme.dart';
import '../work/driver_work_screen.dart';
import 'driver_change_password_sheet.dart';
import 'driver_deactivate_account_dialog.dart';
import 'driver_profile_info_screen.dart';
import 'driver_vehicle_documents_screen.dart';
import 'widgets/settings_widgets.dart';

/// Settings hub — reached from the Account tab's gear icon. Redesigned
/// from a single 1,600-line scroll (every field, every card, every action
/// on one screen) into a scannable navigation list: a compact profile
/// summary up top, grouped rows for Account/Security/Preferences/Support,
/// and a clearly-separated (but not alarming) sign-out/deactivate area at
/// the bottom. Heavy editing surfaces — Personal Information & Home
/// Address, Vehicle & Documents — now live on their own pushed pages
/// instead of being permanently rendered here.
///
/// Fully wired to the real Laravel/Supabase backend, same as before:
/// `GET/PUT /api/driver/profile`, `DELETE /api/driver/account/deactivate`,
/// and the shared `/api/password/*` email-code flow.
class DriverSettingsScreen extends StatefulWidget {
  final DriverAccount account;
  final String accessToken;
  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsChanged;
  final bool soundEnabled;
  final ValueChanged<bool> onSoundChanged;
  final String language;
  final ValueChanged<String> onLanguageChanged;

  const DriverSettingsScreen({
    super.key,
    required this.account,
    required this.accessToken,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
    required this.soundEnabled,
    required this.onSoundChanged,
    required this.language,
    required this.onLanguageChanged,
  });

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> {
  final ApiService _api = ApiService();

  void _openProfileInfo({bool autoEdit = false, bool scrollToAddress = false}) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => DriverProfileInfoScreen(
            account: widget.account,
            accessToken: widget.accessToken,
            autoEdit: autoEdit,
            scrollToAddress: scrollToAddress,
          ),
        ))
        .then((_) => setState(() {})); // reflect any saved profile changes
  }

  void _openVehicleDocuments() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DriverVehicleDocumentsScreen(account: widget.account)));
  }

  /// Browsing logistics companies + applications is a courier-specific
  /// flow (there's no equivalent "find work" concept for an already-
  /// employed driver in the backend) — see DriverWorkScreen.
  void _openFindWork() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DriverWorkScreen(accessToken: widget.accessToken)));
  }

  void _openChangePassword() {
    showChangePasswordSheet(context, api: _api, email: widget.account.email);
  }

  void _pickLanguage() {
    showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select language'),
        children: ['English', 'Filipino', 'Cebuano']
            .map((lang) => SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, lang), child: Text(lang)))
            .toList(),
      ),
    ).then((value) {
      if (value != null) widget.onLanguageChanged(value);
    });
  }

  void _comingSoon(String label) => SettingsToast.info(context, '$label is coming soon.');

  // ==================== Sign out / deactivate ====================

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const DriverLoginScreen()), (route) => false);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to sign in again to go back online."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DriverColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _signOut();
  }

  void _openDeactivateDialog() {
    showDeactivateAccountDialog(context, api: _api, accessToken: widget.accessToken, onDeactivated: _signOut);
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: DriverColors.textPrimary,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
          children: [
            SettingsProfileSummary(
              name: a.name,
              email: a.email,
              status: a.accountStatus,
              role: SettingsFormat.roleLabel(a.role),
              memberSince: a.memberSince,
              onTap: () => _openProfileInfo(),
            ),
            const SizedBox(height: 26),

            const SettingsSectionLabel('Account'),
            const SizedBox(height: 8),
            SettingsGroupCard(children: [
              SettingsNavTile(
                icon: Icons.badge_outlined,
                title: 'Personal Information',
                subtitle: 'Name, contact number, birthday',
                onTap: () => _openProfileInfo(),
              ),
              SettingsNavTile(
                icon: Icons.location_on_outlined,
                title: 'Home Address',
                subtitle: a.fullAddress.isEmpty ? 'No address on file yet' : a.fullAddress,
                onTap: () => _openProfileInfo(scrollToAddress: true),
              ),
              SettingsNavTile(
                icon: Icons.two_wheeler_rounded,
                title: 'Vehicle & Documents',
                subtitle: '${a.vehicleType} · ${a.plateNumber}',
                onTap: _openVehicleDocuments,
              ),
              if (a.role == 'courier')
                SettingsNavTile(
                  icon: Icons.storefront_rounded,
                  title: 'Find Work',
                  subtitle: 'Browse logistics companies & applications',
                  onTap: _openFindWork,
                ),
            ]),
            const SizedBox(height: 22),

            const SettingsSectionLabel('Security'),
            const SizedBox(height: 8),
            SettingsGroupCard(children: [
              SettingsNavTile(
                icon: Icons.lock_outline_rounded,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: _openChangePassword,
              ),
            ]),
            const SizedBox(height: 22),

            const SettingsSectionLabel('Preferences'),
            const SizedBox(height: 8),
            SettingsGroupCard(children: [
              SettingsSwitchTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Delivery requests & updates',
                value: widget.notificationsEnabled,
                onChanged: widget.onNotificationsChanged,
              ),
              SettingsSwitchTile(
                icon: Icons.volume_up_outlined,
                title: 'Sound alerts',
                value: widget.soundEnabled,
                onChanged: widget.onSoundChanged,
              ),
              SettingsNavTile(
                icon: Icons.language_rounded,
                title: 'Language',
                trailingText: widget.language,
                onTap: _pickLanguage,
              ),
            ]),
            const SizedBox(height: 22),

            const SettingsSectionLabel('Support'),
            const SizedBox(height: 8),
            SettingsGroupCard(children: [
              SettingsNavTile(icon: Icons.support_agent_rounded, title: 'Help & Support', onTap: () => _comingSoon('Help & support')),
              SettingsNavTile(icon: Icons.description_outlined, title: 'Terms & Conditions', onTap: () => _comingSoon('Terms & conditions')),
            ]),
            const SizedBox(height: 30),

            OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: DriverColors.textPrimary,
                side: const BorderSide(color: DriverColors.border),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Column(
                children: [
                  TextButton(
                    onPressed: _openDeactivateDialog,
                    style: TextButton.styleFrom(foregroundColor: DriverColors.error),
                    child: const Text('Deactivate account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Irreversible — immediately ends your session and requires support to reactivate.',
                      textAlign: TextAlign.center,
                      style: DriverText.caption,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
