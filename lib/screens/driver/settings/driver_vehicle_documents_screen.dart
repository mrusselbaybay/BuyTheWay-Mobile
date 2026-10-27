import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/api_service.dart';
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
  final String accessToken;

  /// Pull-to-refresh — re-reads the profile (vehicle/plate/license all
  /// come from `GET /api/driver/profile`'s `vehicle` block), so a support
  /// update lands here without restarting the app.
  final Future<void> Function() onRefresh;

  const DriverVehicleDocumentsScreen({
    super.key,
    required this.account,
    required this.accessToken,
    required this.onRefresh,
  });

  @override
  State<DriverVehicleDocumentsScreen> createState() => _DriverVehicleDocumentsScreenState();
}

class _DriverVehicleDocumentsScreenState extends State<DriverVehicleDocumentsScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic> _documents = {};
  bool _loadingDocuments = false;
  String? _documentError;

  @override
  void initState() {
    super.initState();
    if (widget.account.role == 'courier') _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() { _loadingDocuments = true; _documentError = null; });
    try {
      final result = await _api.getCourierRegistrationDocuments(accessToken: widget.accessToken);
      if (!mounted) return;
      setState(() => _documents = Map<String, dynamic>.from(result['documents'] as Map? ?? {}));
    } catch (_) {
      if (mounted) setState(() => _documentError = 'Could not load your registration documents.');
    } finally {
      if (mounted) setState(() => _loadingDocuments = false);
    }
  }

  Future<void> _viewDocument(String type) async {
    final item = _documents[type];
    final url = item is Map ? item['url']?.toString() : null;
    if (url == null || url.isEmpty) return;
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open this document.')));
  }

  Future<void> _replaceDocument(String type, String label) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read the selected file.')));
      return;
    }
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a file smaller than 5 MB.')));
      return;
    }
    try {
      await _api.replaceCourierRegistrationDocument(
        accessToken: widget.accessToken, documentType: type, bytes: bytes, fileName: file.name,
      );
      await _loadDocuments();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label replaced and submitted for review.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not replace document: $error')));
    }
  }

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
      if (a.role == 'courier') ...[
        const SizedBox(height: 20),
        Text('Registration documents', style: DriverText.sectionTitle),
        const SizedBox(height: 10),
        if (_loadingDocuments) const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()))
        else if (_documentError != null)
          TextButton.icon(onPressed: _loadDocuments, icon: const Icon(Icons.refresh_rounded), label: Text('$_documentError Retry'))
        else ...[
          _documentTile('orcr', 'OR/CR', Icons.description_outlined),
          const SizedBox(height: 10),
          _documentTile('drivers_license', "Driver's license", Icons.badge_outlined),
          const SizedBox(height: 12),
          const SettingsInfoNote('Replacing a document sends it for verification again.'),
        ],
      ] else
        const SizedBox(height: 14),
      if (a.role != 'courier') const SettingsInfoNote('To update vehicle or document details, contact support.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _documentTile(String type, String label, IconData icon) {
    final data = _documents[type];
    final hasFile = data is Map && data['url'] != null;
    final status = data is Map ? data['status']?.toString() : null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: DriverColors.primary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(hasFile ? 'On file${status == null ? '' : ' · ${status[0].toUpperCase()}${status.substring(1)}'}' : 'Not on file', style: DriverText.caption),
        ])),
        if (hasFile) IconButton(tooltip: 'View $label', onPressed: () => _viewDocument(type), icon: const Icon(Icons.visibility_outlined)),
        IconButton(tooltip: 'Replace $label', onPressed: () => _replaceDocument(type, label), icon: const Icon(Icons.upload_file_rounded)),
      ]),
    );
  }
}
