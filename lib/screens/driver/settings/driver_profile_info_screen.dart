import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/api_service.dart';
import '../../../widgets/image_crop_sheet.dart';
import '../driver_models.dart';
import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';
import 'widgets/settings_widgets.dart';

/// Personal Information & Home Address — reached from the Settings hub's
/// "Personal Information" row (or straight from the Account tab's Edit
/// button via [autoEdit]). Combined into one page rather than two because
/// the backend saves both halves together in a single
/// `PUT /api/driver/profile` call (see [ApiService.updateDriverProfile]);
/// splitting them into separate pages would mean each page's Save either
/// re-sends the other half's data from stale local state or risks
/// clobbering it — keeping them on one page keeps the save contract exact.
class DriverProfileInfoScreen extends StatefulWidget {
  final DriverAccount account;
  final String accessToken;

  /// Opens the page already in edit mode — used when reached via the
  /// Account tab's "Edit" button, which wants to skip straight past the
  /// read-only view.
  final bool autoEdit;

  /// When true, the page scrolls straight to the Home Address section on
  /// open — used by the Settings hub's "Home Address" row so tapping it
  /// doesn't land the driver back at the top of the Personal Details
  /// section they didn't ask for.
  final bool scrollToAddress;

  const DriverProfileInfoScreen({
    super.key,
    required this.account,
    required this.accessToken,
    this.autoEdit = false,
    this.scrollToAddress = false,
  });

  @override
  State<DriverProfileInfoScreen> createState() => _DriverProfileInfoScreenState();
}

class _DriverProfileInfoScreenState extends State<DriverProfileInfoScreen> {
  final ApiService _api = ApiService();
  final GlobalKey _addressSectionKey = GlobalKey();

  bool _isEditing = false;
  bool _saving = false;
  bool _dirty = false;
  final Map<String, String> _errors = {};

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _middleInitial;
  late final TextEditingController _contact;
  late final TextEditingController _street;
  late final TextEditingController _houseNo;
  String _sex = '';
  DateTime? _birthday;

  // ---- Profile picture ----
  /// The just-cropped bytes, shown immediately after a successful upload
  /// so the new photo appears without waiting on Supabase's CDN to serve
  /// the replaced object at the (unchanged) avatar URL.
  Uint8List? _pendingAvatar;
  bool _uploadingAvatar = false;

  // ---- Address selection (region + PSGC province/municipality/barangay) ----
  /// Island group — 'Luzon' / 'Visayas' / 'Mindanao'. Not part of the PSGC
  /// chain: it's a free-standing choice the backend validates against
  /// those three values and stores on `addresses.region_name`.
  String _region = '';
  String _provinceCode = '';
  String _provinceName = '';
  String _municipalityCode = '';
  String _municipalityName = '';
  String _barangayName = '';
  List<dynamic> _provinces = [];
  List<dynamic> _municipalities = [];
  List<dynamic> _barangays = [];
  bool _loadingProvinces = false;
  bool _loadingMunicipalities = false;
  bool _loadingBarangays = false;
  String _addressLoadError = '';

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _firstName = TextEditingController(text: a.firstName);
    _lastName = TextEditingController(text: a.lastName);
    _middleInitial = TextEditingController(text: a.middleInitial);
    _contact = TextEditingController(text: a.phone);
    _street = TextEditingController(text: a.street);
    _houseNo = TextEditingController(text: a.houseNo);
    _sex = a.sex;
    _birthday = a.birthday.year <= 1901 ? null : a.birthday;
    _region = a.regionName;
    _provinceCode = a.provinceCode;
    _provinceName = a.provinceName;
    _municipalityCode = a.municipalityCode;
    _municipalityName = a.municipalityName;
    _barangayName = a.barangay;

    for (final c in [_firstName, _lastName, _middleInitial, _contact, _street, _houseNo]) {
      c.addListener(_markDirty);
    }

    if (widget.autoEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startEditing());
    } else if (widget.scrollToAddress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _addressSectionKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic, alignment: 0);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _middleInitial, _contact, _street, _houseNo]) {
      c.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (_isEditing) _dirty = true;
  }

  // ==================== Unsaved-change guard ====================

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved edits. Leaving now will discard them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep editing')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DriverColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Pressing back while editing exits edit mode (reverting any changes)
  /// instead of leaving the page outright — a second back press then
  /// closes the page normally. A dirty form asks for confirmation first.
  Future<void> _handleBackAttempt() async {
    if (_dirty) {
      final discard = await _confirmDiscard();
      if (!discard) return;
    }
    _cancelEditing();
  }

  // ==================== PSGC address lookups ====================

  Future<void> _loadProvinces() async {
    if (_provinces.isNotEmpty) return;
    setState(() {
      _loadingProvinces = true;
      _addressLoadError = '';
    });
    try {
      final provinces = await _api.getProvinces();
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        _loadingProvinces = false;
        if (_provinceCode.isNotEmpty && !provinces.any((p) => p['code'] == _provinceCode)) {
          _provinces = [
            {'code': _provinceCode, 'name': _provinceName},
            ...provinces,
          ];
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingProvinces = false;
        _addressLoadError = 'Could not load provinces. Check your connection.';
      });
    }
  }

  Future<void> _loadMunicipalities(String provinceCode, {bool preserveSelection = false}) async {
    setState(() => _loadingMunicipalities = true);
    try {
      final municipalities = await _api.getMunicipalities(provinceCode: provinceCode);
      if (!mounted) return;
      setState(() {
        _municipalities = municipalities;
        _loadingMunicipalities = false;
        if (preserveSelection &&
            _municipalityCode.isNotEmpty &&
            !municipalities.any((m) => m['code'] == _municipalityCode)) {
          _municipalities = [
            {'code': _municipalityCode, 'name': _municipalityName},
            ...municipalities,
          ];
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMunicipalities = false;
        _addressLoadError = 'Could not load cities/municipalities.';
      });
    }
  }

  Future<void> _loadBarangays(String municipalityCode, {bool preserveSelection = false}) async {
    setState(() => _loadingBarangays = true);
    try {
      final barangays = await _api.getBarangays(municipalityCode: municipalityCode);
      if (!mounted) return;
      setState(() {
        _barangays = barangays;
        _loadingBarangays = false;
        if (preserveSelection && _barangayName.isNotEmpty && !barangays.any((b) => b['name'] == _barangayName)) {
          _barangays = [
            {'code': 'current', 'name': _barangayName},
            ...barangays,
          ];
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingBarangays = false;
        _addressLoadError = 'Could not load barangays.';
      });
    }
  }

  void _onProvinceChanged(String? code) {
    if (code == null) return;
    final match = _provinces.firstWhere((p) => p['code'] == code, orElse: () => null);
    setState(() {
      _provinceCode = code;
      _provinceName = (match?['name'] as String?) ?? '';
      _municipalityCode = '';
      _municipalityName = '';
      _barangayName = '';
      _municipalities = [];
      _barangays = [];
      _errors.remove('province');
      _dirty = true;
    });
    _loadMunicipalities(code);
  }

  void _onMunicipalityChanged(String? code) {
    if (code == null) return;
    final match = _municipalities.firstWhere((m) => m['code'] == code, orElse: () => null);
    setState(() {
      _municipalityCode = code;
      _municipalityName = (match?['name'] as String?) ?? '';
      _barangayName = '';
      _barangays = [];
      _errors.remove('municipality');
      _dirty = true;
    });
    _loadBarangays(code);
  }

  void _onBarangayChanged(String? name) {
    if (name == null) return;
    setState(() {
      _barangayName = name;
      _errors.remove('barangay');
      _dirty = true;
    });
  }

  // ==================== Editing lifecycle ====================

  Future<void> _startEditing() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isEditing = true;
      _dirty = false;
    });
    await _loadProvinces();
    if (_provinceCode.isNotEmpty) {
      await _loadMunicipalities(_provinceCode, preserveSelection: true);
    }
    if (_municipalityCode.isNotEmpty) {
      await _loadBarangays(_municipalityCode, preserveSelection: true);
    }
  }

  void _cancelEditing() {
    final a = widget.account;
    setState(() {
      _errors.clear();
      _firstName.text = a.firstName;
      _lastName.text = a.lastName;
      _middleInitial.text = a.middleInitial;
      _contact.text = a.phone;
      _street.text = a.street;
      _houseNo.text = a.houseNo;
      _sex = a.sex;
      _birthday = a.birthday.year <= 1901 ? null : a.birthday;
      _region = a.regionName;
      _provinceCode = a.provinceCode;
      _provinceName = a.provinceName;
      _municipalityCode = a.municipalityCode;
      _municipalityName = a.municipalityName;
      _barangayName = a.barangay;
      _isEditing = false;
      _dirty = false;
    });
  }

  bool _validate() {
    final errors = <String, String>{};
    final nameExp = RegExp(r'^[A-Za-z\s\-]+$');

    if (_firstName.text.trim().isEmpty) {
      errors['firstName'] = 'First name is required.';
    } else if (!nameExp.hasMatch(_firstName.text.trim())) {
      errors['firstName'] = 'Only letters allowed.';
    }

    if (_lastName.text.trim().isEmpty) {
      errors['lastName'] = 'Last name is required.';
    } else if (!nameExp.hasMatch(_lastName.text.trim())) {
      errors['lastName'] = 'Only letters allowed.';
    }

    if (_middleInitial.text.trim().isNotEmpty && !RegExp(r'^[A-Za-z]$').hasMatch(_middleInitial.text.trim())) {
      errors['middleInitial'] = 'One letter only.';
    }

    if (_sex.isEmpty) errors['sex'] = 'Select your sex.';

    if (_birthday == null) {
      errors['birthday'] = 'Birthday is required.';
    } else if (_birthday!.isAfter(DateTime.now())) {
      errors['birthday'] = 'Birthday cannot be in the future.';
    }

    final contact = _contact.text.replaceAll(RegExp(r'[\s-]'), '');
    if (contact.isEmpty) {
      errors['contact'] = 'Contact number is required.';
    } else if (!RegExp(r'^09\d{9}$').hasMatch(contact)) {
      errors['contact'] = 'Use format 09XXXXXXXXX.';
    }

    if (_region.isEmpty) errors['region'] = 'Please select a region.';
    if (_provinceCode.isEmpty) errors['province'] = 'Please select a province.';
    if (_municipalityCode.isEmpty) errors['municipality'] = 'Please select a municipality/city.';
    if (_barangayName.isEmpty) errors['barangay'] = 'Please select a barangay.';
    if (_street.text.trim().isEmpty) errors['street'] = 'Street is required.';

    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    return errors.isEmpty;
  }

  /// Maps a Laravel validation field name (e.g. `contact_no`) to the key
  /// this screen's field-level error labels use (e.g. `contact`).
  String _mapBackendField(String key) {
    const map = {
      'first_name': 'firstName',
      'last_name': 'lastName',
      'middle_initial': 'middleInitial',
      'contact_no': 'contact',
      'region_name': 'region',
      'province_code': 'province',
      'municipality_code': 'municipality',
    };
    return map[key] ?? key;
  }

  Future<void> _save() async {
    if (!_validate()) {
      SettingsToast.error(context, 'Please fix the highlighted fields.');
      return;
    }

    setState(() => _saving = true);

    final payload = {
      'first_name': _firstName.text.trim(),
      'last_name': _lastName.text.trim(),
      'middle_initial': _middleInitial.text.trim().isEmpty ? null : _middleInitial.text.trim().toUpperCase(),
      'sex': _sex,
      'birthday': SettingsFormat.isoDate(_birthday!),
      'contact_no': _contact.text.replaceAll(RegExp(r'[\s-]'), ''),
      'region_name': _region,
      'province_code': _provinceCode,
      'province_name': _provinceName,
      'municipality_code': _municipalityCode,
      'municipality_name': _municipalityName,
      'barangay': _barangayName,
      'street': _street.text.trim(),
      'house_no': _houseNo.text.trim().isEmpty ? null : _houseNo.text.trim(),
    };

    try {
      final response = await _api.updateDriverProfile(accessToken: widget.accessToken, data: payload);
      final updated = DriverAccount.fromApi(response);
      if (!mounted) return;
      setState(() {
        widget.account.applyFrom(updated);
        _isEditing = false;
        _dirty = false;
        _saving = false;
        _errors.clear();
      });
      SettingsToast.success(context, (response['message'] as String?) ?? 'Your profile was updated successfully.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (e.errors != null) {
          e.errors!.forEach((key, value) {
            final message = value is List ? value.join(' ') : value.toString();
            _errors[_mapBackendField(key)] = message;
          });
        }
      });
      SettingsToast.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      SettingsToast.error(context, 'Could not save changes. Check your connection and try again.');
    }
  }

  /// Pull-to-refresh: re-reads `GET /api/driver/profile` and re-seeds the
  /// form from it. Skipped mid-edit — silently overwriting fields someone
  /// is typing into is worse than a refresh that politely declines.
  Future<void> _refresh() async {
    if (_isEditing) {
      SettingsToast.info(context, 'Finish or cancel your edits first.');
      return;
    }

    try {
      final response = await _api.getDriverProfile(accessToken: widget.accessToken);
      if (!mounted) return;
      widget.account.applyFrom(DriverAccount.fromApi(response));
      _pendingAvatar = null;
      _cancelEditing();
    } on ApiException catch (e) {
      if (!mounted) return;
      SettingsToast.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      SettingsToast.error(context, 'Could not refresh. Check your connection.');
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: 'Select birthday',
    );
    if (picked != null) {
      setState(() {
        _birthday = picked;
        _dirty = true;
      });
    }
  }

  /// Pick → crop/zoom → upload, mirroring the web account pages: the
  /// cropper (widgets/image_crop_sheet.dart) hands back an already-square
  /// image, so the server only ever stores what the rider framed.
  Future<void> _onPickPhoto() async {
    if (_uploadingAvatar) return;

    final cropped = await pickAndCropImage(context);
    if (cropped == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final response = await _api.uploadDriverAvatar(
        accessToken: widget.accessToken,
        bytes: cropped,
        fileName: 'avatar.png',
      );
      if (!mounted) return;
      final url = (response['avatar_url'] as String?) ?? widget.account.avatarUrl;
      // The avatar always lives at the same URL (one fixed path per
      // profile, overwritten in place), so Flutter's image cache would
      // keep serving the previous photo everywhere else in the app.
      if (url.isNotEmpty) {
        await NetworkImage(url).evict();
      }
      if (!mounted) return;
      setState(() {
        widget.account.avatarUrl = url;
        _pendingAvatar = cropped;
        _uploadingAvatar = false;
      });
      SettingsToast.success(
        context,
        (response['message'] as String?) ?? 'Profile picture updated.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      SettingsToast.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      SettingsToast.error(
          context, 'Could not upload your photo. Check your connection.');
    }
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    return PopScope(
      canPop: !_isEditing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackAttempt();
      },
      child: Scaffold(
        backgroundColor: DriverColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: DriverColors.textPrimary,
          title: const Text('Personal Information', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            if (!_isEditing)
              TextButton.icon(
                onPressed: _startEditing,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Edit'),
                style: TextButton.styleFrom(foregroundColor: DriverColors.primary),
              ),
          ],
        ),
        body: SafeArea(
          bottom: !_isEditing,
          child: DriverRefreshable(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                _headerRow(a),
                const SizedBox(height: 22),
                const SettingsSectionLabel('Personal Details'),
                const SizedBox(height: 8),
                _personalDetailsCard(a),
                const SizedBox(height: 22),
                SettingsSectionLabel('Home Address', key: _addressSectionKey),
                const SizedBox(height: 8),
                _addressCard(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _isEditing
            ? SettingsSaveBar(saving: _saving, onCancel: _handleBackAttempt, onSave: _save)
            : null,
      ),
    );
  }

  Widget _headerRow(DriverAccount a) {
    return Row(
      children: [
        SettingsAvatar(
          size: 56,
          showCameraBadge: true,
          onTap: _onPickPhoto,
          imageUrl: a.avatarUrl.isEmpty ? null : a.avatarUrl,
          imageBytes: _pendingAvatar,
          busy: _uploadingAvatar,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.name, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: DriverColors.textPrimary)),
              const SizedBox(height: 3),
              Text('${SettingsFormat.roleLabel(a.role)} · ${a.driverId}', style: DriverText.caption),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DriverColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _personalDetailsCard(DriverAccount a) {
    final age = SettingsFormat.ageFor(_isEditing ? _birthday : (a.birthday.year <= 1901 ? null : a.birthday));
    return _formCard(
      children: [
        Row(
          children: [
            Expanded(child: SettingsTextField(label: 'First Name *', controller: _firstName, enabled: _isEditing && !_saving, error: _errors['firstName'])),
            const SizedBox(width: 12),
            Expanded(child: SettingsTextField(label: 'Last Name *', controller: _lastName, enabled: _isEditing && !_saving, error: _errors['lastName'])),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: SettingsTextField(label: 'M.I.', controller: _middleInitial, enabled: _isEditing && !_saving, error: _errors['middleInitial'], maxLength: 1),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SettingsChoiceField(
                label: 'Sex *',
                value: _sex.isEmpty ? null : _sex,
                options: const ['Male', 'Female'],
                enabled: _isEditing && !_saving,
                error: _errors['sex'],
                onChanged: (v) => setState(() {
                  _sex = v ?? '';
                  _dirty = true;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SettingsDateField(label: 'Birthday *', value: _birthday, enabled: _isEditing && !_saving, error: _errors['birthday'], onTap: _pickBirthday),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SettingsReadOnlyField(label: 'Age', value: age != null ? '$age yrs old' : 'Not available', note: 'Calculated from birthday'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsTextField(
          label: 'Contact Number *',
          controller: _contact,
          enabled: _isEditing && !_saving,
          error: _errors['contact'],
          keyboardType: TextInputType.phone,
          hint: '09XXXXXXXXX',
        ),
        const SizedBox(height: 14),
        SettingsReadOnlyField(
          label: 'Email Address',
          value: a.email,
          note: 'Contact support to change the email on your account.',
          trailingIcon: Icons.lock_outline_rounded,
        ),
      ],
    );
  }

  Widget _addressCard() {
    return _formCard(
      children: [
        if (_addressLoadError.isNotEmpty) SettingsErrorBanner(message: _addressLoadError, onRetry: _loadProvinces),
        Row(
          children: [
            Expanded(
              child: SettingsDropdownField(
                label: 'Province *',
                value: _provinceCode.isEmpty ? null : _provinceCode,
                error: _errors['province'],
                loading: _loadingProvinces,
                enabled: _isEditing,
                hint: _loadingProvinces ? 'Loading…' : 'Select province',
                items: _provinces,
                onChanged: _onProvinceChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SettingsDropdownField(
                label: 'Municipality / City *',
                value: _municipalityCode.isEmpty ? null : _municipalityCode,
                error: _errors['municipality'],
                loading: _loadingMunicipalities,
                enabled: _isEditing && _provinceCode.isNotEmpty,
                hint: _loadingMunicipalities ? 'Loading…' : 'Select city',
                items: _municipalities,
                onChanged: _onMunicipalityChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SettingsDropdownField(
                label: 'Barangay *',
                value: _barangayName.isEmpty ? null : _barangayName,
                error: _errors['barangay'],
                loading: _loadingBarangays,
                enabled: _isEditing && _municipalityCode.isNotEmpty,
                hint: _loadingBarangays ? 'Loading…' : 'Select barangay',
                items: _barangays,
                valueField: 'name',
                onChanged: _onBarangayChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SettingsChoiceField(
                label: 'Region *',
                value: _region.isEmpty ? null : _region,
                options: const ['Luzon', 'Visayas', 'Mindanao'],
                enabled: _isEditing && !_saving,
                error: _errors['region'],
                onChanged: (v) => setState(() {
                  _region = v ?? '';
                  _errors.remove('region');
                  _dirty = true;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(flex: 1, child: SettingsTextField(label: 'House / Unit No.', controller: _houseNo, enabled: _isEditing && !_saving, hint: '123')),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: SettingsTextField(label: 'Street *', controller: _street, enabled: _isEditing && !_saving, error: _errors['street'], hint: 'Rizal St.')),
          ],
        ),
        if (!_isEditing) ...[
          const SizedBox(height: 14),
          const SettingsInfoNote('Tap "Edit" above to update your personal information or address.'),
        ],
      ],
    );
  }
}
