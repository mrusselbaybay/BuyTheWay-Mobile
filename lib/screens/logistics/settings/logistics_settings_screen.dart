import 'package:flutter/material.dart';

import '../../../services/remittance_api_service.dart';
import '../../driver/driver_theme.dart';
import '../../remittances/payment_qr_screen.dart';
import '../../../widgets/sign_in_methods_section.dart';
import '../../driver/settings/widgets/settings_widgets.dart';
import '../../driver/widgets/driver_shared_widgets.dart';
import '../logistics_models.dart';

/// "User Settings" — the third of the Logistics mobile app's three
/// sections. Reuses the same settings component library the courier app's
/// Settings hub is built from (SettingsGroupCard/SettingsNavTile/
/// SettingsProfileSummary/SettingsToast — driver/settings/widgets/
/// settings_widgets.dart), and mirrors its screen chrome (AppBar, pull-to-
/// refresh, spacing, bottom sign-out button — see DriverSettingsScreen) for
/// full visual consistency, trimmed to what a logistics account actually
/// has: no vehicle documents, no delivery availability toggle, no profile
/// editor (there is no `PUT /logistics/profile` endpoint on the backend to
/// save to — only [showChangePasswordSheet]'s shared `/api/password/*` flow
/// and sign-out are wired to something real).
class LogisticsSettingsScreen extends StatelessWidget {
  final LogisticsAccount account;
  final String accessToken;
  final VoidCallback onSignOut;
  final Future<void> Function() onRefresh;

  const LogisticsSettingsScreen({
    super.key,
    required this.account,
    required this.accessToken,
    required this.onSignOut,
    required this.onRefresh,
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
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: DriverColors.textPrimary,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: DriverRefreshable(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
            children: [
              SettingsProfileSummary(
                name: account.ownerName,
                email: account.email,
                status: account.status,
                role: account.companyName,
                memberSince: account.memberSince,
                onTap: () {},
              ),
              const SizedBox(height: 26),

              const SettingsSectionLabel('Payments'),
              const SizedBox(height: 8),
              SettingsGroupCard(
                children: [
                  SettingsNavTile(
                    icon: Icons.qr_code_2_rounded,
                    title: 'Payment QR',
                    subtitle: 'Let sellers pay your delivery fees by GCash',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PaymentQrScreen(
                        accessToken: accessToken,
                        role: RemittanceRole.logistics,
                      ),
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              const SignInMethodsSection(),

              const SettingsSectionLabel('Support'),
              const SizedBox(height: 8),
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
              const SizedBox(height: 30),

              OutlinedButton.icon(
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DriverColors.textPrimary,
                  side: const BorderSide(color: DriverColors.border),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
