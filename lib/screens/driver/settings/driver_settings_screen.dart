import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/api_service.dart';
import '../../../services/push_service.dart';
import '../../../services/remittance_api_service.dart';
import '../../remittances/payment_qr_screen.dart';
import '../../remittances/remittances_screen.dart';
import '../../auth/auth_screen.dart';
import '../driver_models.dart';
import '../driver_theme.dart';
import '../work/driver_work_screen.dart';
import '../../../widgets/sign_in_methods_section.dart';
import 'driver_deactivate_account_dialog.dart';
import 'driver_profile_info_screen.dart';
import 'driver_vehicle_documents_screen.dart';
import '../widgets/driver_shared_widgets.dart';
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

  /// "Go online" shift toggle — whether the rider is currently available
  /// for delivery assignments. Owned by DriverShell (persisted via
  /// `PUT /api/driver/availability`), same lifted-state pattern as the
  /// preferences below.
  final bool deliveryOnline;
  final ValueChanged<bool> onDeliveryOnlineChanged;

  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsChanged;
  final bool soundEnabled;
  final ValueChanged<bool> onSoundChanged;
  final String language;
  final ValueChanged<String> onLanguageChanged;

  /// Pull-to-refresh — re-reads `GET /api/driver/profile` through the
  /// shell so the summary card, address row and vehicle row reflect
  /// changes made elsewhere (e.g. an admin edit).
  final Future<void> Function() onRefresh;

  const DriverSettingsScreen({
    super.key,
    required this.account,
    required this.accessToken,
    required this.deliveryOnline,
    required this.onDeliveryOnlineChanged,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
    required this.soundEnabled,
    required this.onSoundChanged,
    required this.language,
    required this.onLanguageChanged,
    required this.onRefresh,
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
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => DriverVehicleDocumentsScreen(
            account: widget.account,
            onRefresh: widget.onRefresh,
          ),
        ))
        .then((_) => setState(() {}));
  }

  /// Browsing logistics companies + applications is a courier-specific
  /// flow (there's no equivalent "find work" concept for an already-
  /// employed driver in the backend) — see DriverWorkScreen.
  void _openFindWork() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DriverWorkScreen(accessToken: widget.accessToken)));
  }

  void _pickLanguage() {
    showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select language'),
        children: ['English', 'Filipino', 'Cebuano']
            .map((lang) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, lang),
                child: Text(lang)))
            .toList(),
      ),
    ).then((value) {
      if (value != null) widget.onLanguageChanged(value);
    });
  }

  void _comingSoon(String label) =>
      SettingsToast.info(context, '$label is coming soon.');

  // ==================== Sign out / deactivate ====================

  Future<void> _signOut() async {
    await PushService.instance.unregister(authToken: widget.accessToken); // before the session is cleared
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const AuthScreen(portal: AuthPortal.partner)),
        (route) => false);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: DriverColors.error.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.logout_rounded,
                    size: 30, color: DriverColors.error),
              ),
              const SizedBox(height: 16),
              const Text('Log out?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text("You'll need to sign in again to go back online.",
                  textAlign: TextAlign.center, style: DriverText.body),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: DriverColors.error,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Log out'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    await _signOut();
  }

  void _openDeactivateDialog() {
    showDeactivateAccountDialog(context,
        api: _api, accessToken: widget.accessToken, onDeactivated: _signOut);
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
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: DriverRefreshable(
          onRefresh: widget.onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
            children: [
              SettingsProfileSummary(
                name: a.name,
                email: a.email,
                status: a.accountStatus,
                role: SettingsFormat.roleLabel(a.role),
                memberSince: a.memberSince,
                avatarUrl: a.avatarUrl.isEmpty ? null : a.avatarUrl,
                onTap: () => _openProfileInfo(),
              ),
              const SizedBox(height: 26),
              const SettingsSectionLabel('Account'),
              const SizedBox(height: 8),
              SettingsGroupCard(children: [
                SettingsNavTile(
                  icon: Icons.currency_exchange_rounded,
                  title: 'Remittances',
                  subtitle: 'View courier contributions and remittance history',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RemittancesScreen(
                      accessToken: widget.accessToken,
                      role: RemittanceRole.courier,
                    ),
                  )),
                ),
                SettingsNavTile(
                  icon: Icons.qr_code_2_rounded,
                  title: 'Payment QR',
                  subtitle: 'Let your company pay your earnings by GCash',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        PaymentQrScreen(accessToken: widget.accessToken),
                  )),
                ),
                SettingsNavTile(
                  icon: Icons.badge_outlined,
                  title: 'Personal Information',
                  subtitle: 'Name, contact number, birthday',
                  onTap: () => _openProfileInfo(),
                ),
                SettingsNavTile(
                  icon: Icons.location_on_outlined,
                  title: 'Home Address',
                  subtitle: a.fullAddress.isEmpty
                      ? 'No address on file yet'
                      : a.fullAddress,
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
              const SignInMethodsSection(),
              const SettingsSectionLabel('Availability'),
              const SizedBox(height: 8),
              SettingsGroupCard(children: [
                SettingsOptimisticSwitchTile(
                  icon: Icons.delivery_dining_rounded,
                  title: 'Go online',
                  subtitle: (on) => on
                      ? 'Available for delivery assignments'
                      : 'Offline — not receiving assignments',
                  value: widget.deliveryOnline,
                  onChanged: widget.onDeliveryOnlineChanged,
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
                SettingsNavTile(
                    icon: Icons.support_agent_rounded,
                    title: 'Help & Support',
                    onTap: () => _comingSoon('Help & support')),
                SettingsNavTile(
                    icon: Icons.description_outlined,
                    title: 'Terms & Conditions',
                    onTap: () => _comingSoon('Terms & conditions')),
              ]),
              const SizedBox(height: 30),
              OutlinedButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Log out',
                    style: TextStyle(fontWeight: FontWeight.w700)),
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
                      style: TextButton.styleFrom(
                          foregroundColor: DriverColors.error),
                      child: const Text('Deactivate account',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
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
      ),
    );
  }
}
