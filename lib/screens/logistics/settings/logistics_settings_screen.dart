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
        content: const Text(
            'You will need to sign in again to access the Logistics app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed == true) onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5EF),
      body: SafeArea(
        child: DriverRefreshable(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
            children: [
              const Text('BUYTHEWAY  /  LOGISTICS',
                  style: TextStyle(
                      color: Color(0xFF184D3B),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              const SizedBox(height: 7),
              const Text('Account & access',
                  style: TextStyle(
                      color: Color(0xFF172923),
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8)),
              const SizedBox(height: 20),
              _LogisticsAccountPanel(account: account),
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
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Got it'))
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              OutlinedButton.icon(
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Sign out',
                    style: TextStyle(fontWeight: FontWeight.w700)),
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

class _LogisticsAccountPanel extends StatelessWidget {
  const _LogisticsAccountPanel({required this.account});
  final LogisticsAccount account;

  @override
  Widget build(BuildContext context) {
    final initials = account.ownerName.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2).map((part) => part[0].toUpperCase()).join();
    final joined = account.memberSince.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF244C3B),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x20244C3B), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF3E6853), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF78917D).withOpacity(.5))),
            child: Text(initials.isEmpty ? '—' : initials, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: .5)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(account.ownerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(account.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFC7D5C8), fontSize: 11, fontWeight: FontWeight.w500)),
          ])),
          const SizedBox(width: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: account.status.toLowerCase() == 'active' ? const Color(0xFFB7CF8B) : const Color(0xFFD8A16E), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(account.status.toUpperCase(), style: const TextStyle(color: Color(0xFFE1E9DE), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: .7)),
          ]),
        ]),
        const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: Color(0x447B9880))),
        Text(account.companyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFE8EFE5), fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text('Partner since ${months[joined.month - 1]} ${joined.year}', style: const TextStyle(color: Color(0xFFB7C8B9), fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
