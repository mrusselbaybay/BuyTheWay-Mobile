import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../driver/driver_theme.dart';
import '../../driver/settings/driver_change_password_sheet.dart';
import '../../driver/settings/widgets/settings_widgets.dart';
import '../logistics_models.dart';

/// "User Settings" — the third of the Logistics mobile app's three
/// sections. Reuses the same settings component library the courier app's
/// Settings hub is built from (SettingsGroupCard/SettingsNavTile/
/// SettingsProfileSummary/SettingsToast — driver/settings/widgets/
/// settings_widgets.dart) for full visual consistency, trimmed to what a
/// logistics account actually has: no vehicle documents, no delivery
/// availability toggle, no profile editor (there is no
/// `PUT /logistics/profile` endpoint on the backend to save to — only
/// [showChangePasswordSheet]'s shared `/api/password/*` flow and sign-out
/// are wired to something real).
class LogisticsSettingsScreen extends StatelessWidget {
  final LogisticsAccount account;
  final String accessToken;
  final VoidCallback onSignOut;

  const LogisticsSettingsScreen({
    super.key,
    required this.account,
    required this.accessToken,
    required this.onSignOut,
  });

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to access the Logistics app.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed == true) onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final api = ApiService();

    return Scaffold(
      backgroundColor: DriverColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Align(alignment: Alignment.centerLeft, child: Text('Settings', style: DriverText.title)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  SettingsProfileSummary(
                    name: account.ownerName,
                    email: account.email,
                    status: account.status,
                    role: account.companyName,
                    memberSince: account.memberSince,
                    onTap: () {},
                  ),
                  const SizedBox(height: 20),
                  const SettingsSectionLabel('Security'),
                  SettingsGroupCard(
                    children: [
                      SettingsNavTile(
                        icon: Icons.lock_outline_rounded,
                        title: 'Change password',
                        subtitle: 'Update your account password',
                        onTap: () => showChangePasswordSheet(context, api: api, email: account.email),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const SettingsSectionLabel('Support'),
                  SettingsGroupCard(
                    children: [
                      SettingsNavTile(
                        icon: Icons.info_outline_rounded,
                        title: 'About the Inventory checkpoint',
                        subtitle: 'Why parcels must be scanned before dispatch',
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('About the Inventory checkpoint'),
                            content: const Text(
                              'A parcel a courier hands over — picked up from a seller, or arriving via a company-to-company transfer — sits in "For Inventory" until its QR code is scanned here. '
                              'Only a successful, matching scan moves it into "Inventory" and makes it eligible for delivery or transfer.',
                            ),
                            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it'))],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SettingsGroupCard(
                    children: [
                      SettingsNavTile(
                        icon: Icons.logout_rounded,
                        title: 'Sign out',
                        iconColor: DriverColors.error,
                        titleColor: DriverColors.error,
                        onTap: () => _confirmSignOut(context),
                      ),
                    ],
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
