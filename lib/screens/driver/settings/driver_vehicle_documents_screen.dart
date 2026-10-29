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
  State<DriverVehicleDocumentsScreen> createState() =>
      _DriverVehicleDocumentsScreenState();
}

class _DriverVehicleDocumentsScreenState
    extends State<DriverVehicleDocumentsScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic> _documents = {};
  bool _loadingDocuments = false;
  bool _savingVehicle = false;
  final Set<String> _cancellingDocuments = {};
  String? _documentError;
  String _vehicle = '';
  final TextEditingController _plateNumber = TextEditingController();
  DateTime? _licenseExpiryDate;
  static const _vehicles = ['Motorcycle', 'Car', 'Van', 'Bicycle', 'Truck'];

  @override
  void initState() {
    super.initState();
    _vehicle = _vehicles.contains(widget.account.vehicleType)
        ? widget.account.vehicleType
        : '';
    _plateNumber.text = widget.account.plateNumber == 'Not on file'
        ? ''
        : widget.account.plateNumber;
    _licenseExpiryDate = DateTime.tryParse(widget.account.licenseExpiresOn);
    if (widget.account.role == 'courier') _loadDocuments();
  }

  @override
  void dispose() {
    _plateNumber.dispose();
    super.dispose();
  }

  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _chooseLicenseExpiry() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final existing = _licenseExpiryDate;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          existing != null && !existing.isBefore(today) ? existing : today,
      firstDate: today,
      lastDate: DateTime(today.year + 30),
      helpText: 'Select the license expiry date',
    );
    if (picked != null && mounted)
      setState(() => _licenseExpiryDate = DateUtils.dateOnly(picked));
  }

  Future<void> _saveVehicle() async {
    final plate = _plateNumber.text.trim();
    final expiry = _licenseExpiryDate;
    if (!_vehicles.contains(_vehicle)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a valid vehicle type.')));
      return;
    }
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 -]{1,18}[A-Za-z0-9]$')
        .hasMatch(plate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Enter a plate number with 3–20 letters, numbers, spaces, or hyphens.')));
      return;
    }
    if (expiry == null ||
        DateUtils.dateOnly(expiry)
            .isBefore(DateUtils.dateOnly(DateTime.now()))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Choose a license expiry date that is today or later.')));
      return;
    }
    final savedExpiry = DateTime.tryParse(widget.account.licenseExpiresOn);
    if (savedExpiry == null ||
        DateUtils.dateOnly(expiry) != DateUtils.dateOnly(savedExpiry)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "To change the license expiry date, choose the new date above and upload the renewed driver's license below. Both will be sent to Logistics together.")));
      return;
    }

    setState(() => _savingVehicle = true);
    try {
      final result = await _api.updateCourierVehicle(
        accessToken: widget.accessToken,
        vehicle: _vehicle,
        plateNumber: plate,
        licenseExpiresOn: _isoDate(expiry),
      );
      final updated =
          Map<String, dynamic>.from(result['vehicle'] as Map? ?? {});
      widget.account.vehicleType = (updated['vehicle'] as String?) ?? _vehicle;
      widget.account.plateNumber =
          (updated['plate_number'] as String?) ?? plate;
      widget.account.licenseExpiresOn =
          (updated['license_expires_on'] as String?) ?? _isoDate(expiry);
      widget.account.vehicleVerificationStatus =
          (updated['vehicle_verification_status'] as String?) ?? 'pending';
      try {
        await widget.onRefresh();
      } catch (_) {
        // The profile response already contains the saved snapshot; a
        // background refresh failure must not report that save as failed.
      }
      if (mounted) {
        final message =
            result['message']?.toString() ?? 'Vehicle details saved.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      final lowerMessage = error.message.toLowerCase();
      final message = error.statusCode == 422 &&
              (lowerMessage.contains('renewed') ||
                  lowerMessage.contains('license'))
          ? 'To change your license expiry date, replace your driver’s license with the renewed one first. Logistics needs to verify the new document and expiry date together.'
          : error.statusCode != null && error.statusCode! >= 500
              ? 'We couldn’t save your vehicle details right now. Please try again shortly.'
              : error.statusCode == 401
                  ? 'Your session has expired. Sign in again to save vehicle details.'
                  : error.statusCode == 403
                      ? 'You don’t have permission to update these vehicle details.'
                      : 'We couldn’t save your vehicle details. Please check your information and try again.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'We couldn’t save your vehicle details. Check your connection and try again.')));
    } finally {
      if (mounted) setState(() => _savingVehicle = false);
    }
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loadingDocuments = true;
      _documentError = null;
    });
    try {
      final result = await _api.getCourierRegistrationDocuments(
          accessToken: widget.accessToken);
      if (!mounted) return;
      setState(() => _documents =
          Map<String, dynamic>.from(result['documents'] as Map? ?? {}));
    } catch (_) {
      if (mounted)
        setState(() =>
            _documentError = 'Could not load your registration documents.');
    } finally {
      if (mounted) setState(() => _loadingDocuments = false);
    }
  }

  Future<void> _viewDocument(String type) async {
    final item = _documents[type];
    final url = item is Map ? item['url']?.toString() : null;
    if (url == null || url.isEmpty) return;
    final opened =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this document.')));
  }

  Future<void> _cancelDocumentReplacement(String type, String label) async {
    if (_cancellingDocuments.contains(type)) return;
    setState(() => _cancellingDocuments.add(type));
    try {
      await _api.cancelCourierRegistrationDocumentReplacement(
        accessToken: widget.accessToken,
        documentType: type,
      );
      await _loadDocuments();
      try {
        await widget.onRefresh();
      } catch (_) {
        // Cancellation already succeeded; the next refresh will reload profile data.
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '$label replacement canceled. Your previous document and expiry date are restored.')),
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      final message = error.statusCode == 409
          ? 'This request is no longer pending, so it cannot be canceled.'
          : error.statusCode != null && error.statusCode! >= 500
              ? 'We couldn’t cancel this replacement right now. Please try again.'
              : 'We couldn’t cancel this replacement. Refresh and try again.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'We couldn’t cancel this replacement. Check your connection and try again.')));
    } finally {
      if (mounted) setState(() => _cancellingDocuments.remove(type));
    }
  }

  Future<void> _replaceDocument(String type, String label) async {
    if (_loadingDocuments) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read the selected file.')));
      return;
    }
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Choose a file that is 5 MB or smaller.')));
      return;
    }
    if (type == 'drivers_license' &&
        (_licenseExpiryDate == null ||
            DateUtils.dateOnly(_licenseExpiryDate!)
                .isBefore(DateUtils.dateOnly(DateTime.now())))) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Set a license expiry date that is today or later before replacing the license.')));
      return;
    }
    try {
      await _api.replaceCourierRegistrationDocument(
        accessToken: widget.accessToken,
        documentType: type,
        bytes: bytes,
        fileName: file.name,
        licenseExpiresOn:
            type == 'drivers_license' ? _isoDate(_licenseExpiryDate!) : null,
      );
      await _loadDocuments();
      try {
        await widget.onRefresh();
      } catch (_) {
        // The document update succeeded; the list can refresh on pull-to-refresh.
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$label replaced and submitted for review.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      final message = switch (error.statusCode ?? -1) {
        401 =>
          'Your session has expired. Sign in again to replace this document.',
        403 => 'Only courier accounts can replace these documents.',
        409 =>
          'A replacement is already pending. Cancel the pending request before sending another.',
        413 => type == 'drivers_license'
            ? 'The license could not be replaced. Check that the file is JPG, PNG, or PDF, is 5 MB or smaller, and the expiry date is today or later.'
            : 'The document could not be replaced. Check that the file is JPG, PNG, or PDF and is 5 MB or smaller.',
        422 => type == 'drivers_license'
            ? 'We couldn’t submit the license. Choose a valid file and make sure its expiry date is today or later.'
            : 'We couldn’t submit this document. Choose a JPG, PNG, or PDF file that is 5 MB or smaller.',
        >= 500 =>
          'We couldn’t upload your document right now. Please try again shortly.',
        0 =>
          'We couldn’t connect to upload your document. Check your connection and try again.',
        _ =>
          'We couldn’t replace this document right now. Please try again shortly.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not replace this document. Check your connection and try again.')));
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
      if (a.role != 'courier') ...[
        SettingsInfoRow(
            icon: Icons.two_wheeler_rounded,
            label: 'Vehicle',
            value: a.vehicleType),
        SettingsInfoRow(
            icon: Icons.badge_outlined,
            label: 'Plate number',
            value: a.plateNumber),
      ],
      if (a.role == 'driver')
        SettingsInfoRow(
          icon: Icons.card_membership_outlined,
          label: "Driver's license no.",
          value: a.licenseNumber.isEmpty ? 'Not on file' : a.licenseNumber,
        ),
      if (a.logisticsCompanyName != null && a.logisticsCompanyName!.isNotEmpty)
        SettingsInfoRow(
            icon: Icons.business_rounded,
            label: 'Logistics company',
            value: a.logisticsCompanyName!),
      SettingsInfoRow(
          icon: Icons.qr_code_2_rounded,
          label: '${SettingsFormat.roleLabel(a.role)} ID',
          value: a.driverId),
    ];

    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: DriverColors.textPrimary,
        title: const Text('Vehicle & Documents',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: DriverRefreshable(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              SettingsGroupCard(children: rows),
              if (a.role == 'courier') ...[
                const SizedBox(height: 16),
                Text('Vehicle details', style: DriverText.sectionTitle),
                const SizedBox(height: 10),
                SettingsGroupCard(
                  padding: const EdgeInsets.all(14),
                  children: [
                    SettingsChoiceField(
                      label: 'Vehicle type',
                      value: _vehicle.isEmpty ? null : _vehicle,
                      options: _vehicles,
                      enabled: !_savingVehicle,
                      onChanged: (value) =>
                          setState(() => _vehicle = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    SettingsTextField(
                      label: 'Plate number',
                      controller: _plateNumber,
                      enabled: !_savingVehicle,
                      maxLength: 20,
                      hint: 'ABC-1234',
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    SettingsDateField(
                      label: "Driver's license expiry date",
                      value: _licenseExpiryDate,
                      enabled: !_savingVehicle,
                      onTap: _chooseLicenseExpiry,
                    ),
                    const SizedBox(height: 8),
                    const SettingsInfoNote(
                        "To change this date, choose the new expiry and upload the renewed driver's license below. Logistics reviews them together."),
                    const SizedBox(height: 10),
                    SettingsInfoNote(
                      a.vehicleVerificationStatus == 'pending'
                          ? 'Changes are visible to Logistics and need re-verification.'
                          : 'Changes to vehicle details are sent to Logistics for re-verification.',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _savingVehicle ? null : _saveVehicle,
                        icon: _savingVehicle
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(_savingVehicle
                            ? 'Saving…'
                            : 'Save vehicle details'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              if (a.role == 'courier') ...[
                const SizedBox(height: 20),
                Text('Registration documents', style: DriverText.sectionTitle),
                const SizedBox(height: 10),
                if (_loadingDocuments)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator()))
                else if (_documentError != null)
                  TextButton.icon(
                      onPressed: _loadDocuments,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text('$_documentError Retry'))
                else ...[
                  _documentTile('orcr', 'OR/CR', Icons.description_outlined),
                  const SizedBox(height: 10),
                  _documentTile('drivers_license', "Driver's license",
                      Icons.badge_outlined),
                  const SizedBox(height: 12),
                  const SettingsInfoNote(
                      'A replacement is sent to Logistics for review. You can cancel it while it is pending.'),
                ],
              ] else
                const SizedBox(height: 14),
              if (a.role != 'courier')
                const SettingsInfoNote(
                    'To update vehicle or document details, contact support.'),
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
    final replacementPending =
        data is Map && data['replacement_pending'] == true;
    final cancelling = _cancellingDocuments.contains(type);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: DriverColors.primary),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            replacementPending
                ? 'Replacement sent · Pending Logistics review'
                : hasFile
                    ? 'On file${status == null ? '' : ' · ${status[0].toUpperCase()}${status.substring(1)}'}'
                    : 'Not on file',
            style: DriverText.caption,
          ),
        ])),
        if (hasFile)
          IconButton(
              tooltip: 'View $label',
              onPressed: () => _viewDocument(type),
              icon: const Icon(Icons.visibility_outlined)),
        if (replacementPending)
          TextButton.icon(
            onPressed: cancelling
                ? null
                : () => _cancelDocumentReplacement(type, label),
            icon: cancelling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.close_rounded),
            label: Text(cancelling ? 'Canceling' : 'Cancel'),
          )
        else
          IconButton(
              tooltip: 'Replace $label',
              onPressed: () => _replaceDocument(type, label),
              icon: const Icon(Icons.upload_file_rounded)),
      ]),
    );
  }
}
