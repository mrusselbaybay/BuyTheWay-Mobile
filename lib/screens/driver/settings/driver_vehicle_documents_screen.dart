import 'package:flutter/material.dart';

import '../driver_models.dart';
import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';
import 'widgets/settings_widgets.dart';

/// Read-only vehicle & document details — split out of the old
/// all-in-one settings screen into its own destination so the hub isn't
/// carrying a whole card of information the driver can't even edit here
/// (vehicle/document changes go through support, same as before).
class DriverVehicleDocumentsScreen extends StatefulWidget {
  final DriverAccount account;

  /// Pull-to-refresh — re-reads the profile (vehicle/plate/license all
  /// come from `GET /api/driver/profile`'s `vehicle` block), so a support
  /// update lands here without restarting the app.
  final Future<void> Function() onRefresh;

  const DriverVehicleDocumentsScreen({
    super.key,
    required this.account,
    required this.onRefresh,
  });

  @override
  State<DriverVehicleDocumentsScreen> createState() => _DriverVehicleDocumentsScreenState();
}

class _DriverVehicleDocumentsScreenState extends State<DriverVehicleDocumentsScreen> {
  Future<void> _refresh() async {
    await widget.onRefresh();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    final rows = <Widget>[
      SettingsInfoRow(icon: Icons.two_wheeler_rounded, label: 'Vehicle', value: a.vehicleType),
      SettingsInfoRow(icon: Icons.badge_outlined, label: 'Plate number', value: a.plateNumber),
      if (a.role == 'driver')
        SettingsInfoRow(
          icon: Icons.card_membership_outlined,
          label: "Driver's license no.",
          value: a.licenseNumber.isEmpty ? 'Not on file' : a.licenseNumber,
        ),
      if (a.logisticsCompanyName != null && a.logisticsCompanyName!.isNotEmpty)
        SettingsInfoRow(icon: Icons.business_rounded, label: 'Logistics company', value: a.logisticsCompanyName!),
      SettingsInfoRow(icon: Icons.qr_code_2_rounded, label: '${SettingsFormat.roleLabel(a.role)} ID', value: a.driverId),
    ];

    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: DriverColors.textPrimary,
        title: const Text('Vehicle & Documents', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: DriverRefreshable(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              SettingsGroupCard(children: rows),
              const SizedBox(height: 14),
              const SettingsInfoNote('To update vehicle or document details, contact support.'),
            ],
          ),
        ),
      ),
    );
  }
}
