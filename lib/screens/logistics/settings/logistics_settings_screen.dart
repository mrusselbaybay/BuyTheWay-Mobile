import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../services/remittance_api_service.dart';
import '../../../widgets/sign_in_methods_section.dart';
import '../../driver/driver_theme.dart';
import '../logistics_theme.dart';
import '../../driver/settings/widgets/settings_widgets.dart';
import '../../driver/widgets/driver_shared_widgets.dart';
import '../../remittances/payment_qr_screen.dart';
import '../logistics_models.dart';
import '../../../utils/profile_field_validators.dart';

/// Mobile counterpart of the web logistics Account Settings page. Both use
/// `/api/logistics/account`, keeping profile and company data in sync.
class LogisticsSettingsScreen extends StatefulWidget {
  const LogisticsSettingsScreen(
      {super.key,
      required this.account,
      required this.accessToken,
      required this.onSignOut,
      required this.onRefresh});
  final LogisticsAccount account;
  final String accessToken;
  final VoidCallback onSignOut;
  final Future<void> Function() onRefresh;

  @override
  State<LogisticsSettingsScreen> createState() =>
      _LogisticsSettingsScreenState();
}

class _LogisticsSettingsScreenState extends State<LogisticsSettingsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  Map<String, dynamic> _map(String key) =>
      Map<String, dynamic>.from(_data?[key] as Map? ?? const {});
  Map<String, dynamic> get _profile => _map('profile');
  Map<String, dynamic> get _company => _map('company');
  Map<String, dynamic> get _address => _map('address');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final response =
          await _api.getLogisticsAccount(accessToken: widget.accessToken);
      if (!mounted) return;
      setState(() {
        final value = response['data'];
        _data = value is Map ? Map<String, dynamic>.from(value) : {};
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.message;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Could not load your settings. Pull down to retry.';
        });
    }
  }

  Future<void> _refresh() async => Future.wait([_load(), widget.onRefresh()]);

  Future<void> _edit(_Section section) async {
    final result = await Navigator.of(context)
        .push<Map<String, dynamic>>(MaterialPageRoute(
      builder: (_) => _SettingsEditor(
          section: section,
          accessToken: widget.accessToken,
          data: Map<String, dynamic>.from(_data ?? const {})),
    ));
    if (result != null && mounted) setState(() => _data = result);
  }

  Future<void> _signOut() async {
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
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded,
                    size: 30, color: DriverColors.error),
              ),
              const SizedBox(height: 16),
              const Text('Sign out?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'You will need to sign in again to access your logistics account.',
                textAlign: TextAlign.center,
                style: DriverText.body,
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
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
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign out'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) widget.onSignOut();
  }

  String _joinAddress() {
    final parts = [
      _address['barangay'],
      _address['municipality_name'],
      _address['province_name']
    ].map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty);
    return parts.isEmpty ? 'Add your company hub address' : parts.join(', ');
  }

  int get _completedProfileItems {
    final values = [
      _profile['first_name'],
      _profile['last_name'],
      _profile['contact_no'],
      _company['company_name'],
      _company['company_email'],
      _address['province_name'],
      _address['municipality_name'],
      _address['barangay'],
    ];
    return values
        .where((value) => value?.toString().trim().isNotEmpty == true)
        .length;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: LogisticsTheme.canvas,
        body: SafeArea(
            child: DriverRefreshable(
          onRefresh: _refresh,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
              children: [
                const _SettingsHeader(),
                const SizedBox(height: 18),
                _AccountPanel(
                    account: widget.account,
                    profile: _profile,
                    companyName: _company['company_name']?.toString()),
                if (_loading) ...[
                  const SizedBox(height: 30),
                  const Center(
                      child: CircularProgressIndicator(
                          color: DriverColors.primary))
                ] else if (_error != null) ...[
                  const SizedBox(height: 20),
                  _ErrorCard(message: _error!, retry: _load)
                ] else ...[
                  const SizedBox(height: 12),
                  _ProfileProgress(
                      completed: _completedProfileItems,
                      onTap: () => _edit(_Section.profile)),
                  const SizedBox(height: 24),
                  const _SettingsSectionHeader(
                      title: 'Your account', caption: 'IDENTITY & ACCESS'),
                  const SizedBox(height: 10),
                  SettingsGroupCard(children: [
                    SettingsNavTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Profile',
                        subtitle: _profile['contact_no']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ==
                                true
                            ? _profile['contact_no'].toString()
                            : 'Name and contact details',
                        onTap: () => _edit(_Section.profile)),
                    SettingsNavTile(
                        icon: Icons.lock_outline_rounded,
                        title: 'Security',
                        subtitle: 'Password and sign-in methods',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const _SecurityScreen()))),
                  ]),
                  if (_company.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _SettingsSectionHeader(
                        title: 'Company', caption: 'OPERATIONS'),
                    const SizedBox(height: 10),
                    SettingsGroupCard(children: [
                      SettingsNavTile(
                          icon: Icons.storefront_outlined,
                          title: 'Company profile',
                          subtitle: _company['company_email']?.toString() ??
                              'Public company details',
                          onTap: () => _edit(_Section.company)),
                      SettingsNavTile(
                          icon: Icons.location_on_outlined,
                          title: 'Hub location',
                          subtitle: _joinAddress(),
                          onTap: () => _edit(_Section.hub)),
                      SettingsNavTile(
                          icon: Icons.delivery_dining_outlined,
                          title: 'Rider hiring',
                          subtitle: _company['is_hiring'] == true
                              ? 'Visible in Find Work'
                              : 'Hidden from Find Work',
                          onTap: () => _edit(_Section.hiring)),
                      SettingsNavTile(
                          icon: Icons.qr_code_2_rounded,
                          title: 'Payment QR',
                          subtitle:
                              'Let sellers pay your delivery fees by GCash',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PaymentQrScreen(
                                      accessToken: widget.accessToken,
                                      role: RemittanceRole.logistics)))),
                    ]),
                  ],
                  const SizedBox(height: 24),
                  const _SettingsSectionHeader(
                      title: 'Portal', caption: 'PREFERENCES'),
                  const SizedBox(height: 10),
                  SettingsGroupCard(children: [
                    SettingsNavTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifications',
                        subtitle: 'Push notifications and sound alerts',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => _NotificationsScreen(
                                    accessToken: widget.accessToken)))),
                  ]),
                ],
                const SizedBox(height: 30),
                OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Sign out',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: DriverColors.textPrimary,
                        side: const BorderSide(color: DriverColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size.fromHeight(48))),
              ]),
        )),
      );
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings', style: LogisticsTheme.pageTitle),
          const SizedBox(height: 7),
          const Text('Manage your team identity, hub and portal preferences.',
              style: TextStyle(
                  color: DriverColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4)),
        ],
      );
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({required this.title, required this.caption});
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(title,
            style: const TextStyle(
                color: DriverColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        const Spacer(),
        Text(caption,
            style: const TextStyle(
                color: DriverColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .9)),
      ]);
}

class _ProfileProgress extends StatelessWidget {
  const _ProfileProgress({required this.completed, required this.onTap});
  final int completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = completed / 8;
    final complete = completed == 8;
    return Material(
      color: complete ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: complete ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            SizedBox(
              width: 38,
              height: 38,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    backgroundColor: Colors.white,
                    color:
                        complete ? DriverColors.success : DriverColors.warning),
                Text('${(progress * 100).round()}',
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(complete ? 'Account ready' : 'Finish account setup',
                      style: const TextStyle(
                          color: DriverColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                      complete
                          ? 'Your logistics profile and hub details are complete.'
                          : '$completed of 8 essential details completed',
                      style: const TextStyle(
                          color: DriverColors.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
            if (!complete)
              const Icon(Icons.arrow_forward_rounded,
                  size: 18, color: DriverColors.warning),
          ]),
        ),
      ),
    );
  }
}

enum _Section { profile, company, hub, hiring }

class _SettingsEditor extends StatefulWidget {
  const _SettingsEditor(
      {required this.section, required this.accessToken, required this.data});
  final _Section section;
  final String accessToken;
  final Map<String, dynamic> data;
  @override
  State<_SettingsEditor> createState() => _SettingsEditorState();
}

class _SettingsEditorState extends State<_SettingsEditor> {
  final _api = ApiService();
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _hiring = false, _saving = false;
  String? _error;

  Map<String, dynamic> _source(String key) =>
      Map<String, dynamic>.from(widget.data[key] as Map? ?? const {});
  static const fields = {
    _Section.profile: [
      'first_name',
      'middle_initial',
      'last_name',
      'contact_no',
      'sex',
      'birthday'
    ],
    _Section.company: ['company_name', 'company_email', 'company_contact_no'],
    _Section.hub: [
      'region',
      'province_name',
      'municipality_name',
      'barangay',
      'street',
      'house_no',
      'postal_code'
    ],
    _Section.hiring: ['monthly_salary', 'description'],
  };
  static const labels = {
    'first_name': 'First name',
    'middle_initial': 'Middle initial',
    'last_name': 'Last name',
    'contact_no': 'Contact number',
    'sex': 'Sex',
    'birthday': 'Birthday (YYYY-MM-DD)',
    'company_name': 'Company name',
    'company_email': 'Company email',
    'company_contact_no': 'Company contact number',
    'region': 'Island group',
    'province_name': 'Province',
    'municipality_name': 'City / municipality',
    'barangay': 'Barangay',
    'street': 'Street',
    'house_no': 'House / unit no. (optional)',
    'postal_code': 'Postal code',
    'monthly_salary': 'Monthly salary (optional)',
    'description': 'About this role',
  };

  @override
  void initState() {
    super.initState();
    final values = {
      ..._source('profile'),
      ..._source('company'),
      ..._source('address')
    };
    for (final name in fields[widget.section]!) {
      _controllers[name] =
          TextEditingController(text: values[name]?.toString() ?? '');
    }
    _hiring = _source('company')['is_hiring'] == true;
  }

  @override
  void dispose() {
    for (final item in _controllers.values) {
      item.dispose();
    }
    super.dispose();
  }

  String get _title => const {
        _Section.profile: 'Profile',
        _Section.company: 'Company profile',
        _Section.hub: 'Hub location',
        _Section.hiring: 'Rider hiring'
      }[widget.section]!;

  Map<String, dynamic> _payload() {
    final profile = _source('profile'),
        company = _source('company'),
        address = _source('address');
    dynamic read(Map<String, dynamic> map, String key,
            [dynamic fallback = '']) =>
        map.containsKey(key) ? map[key] : fallback;
    final payload = <String, dynamic>{
      'first_name': read(profile, 'first_name'),
      'middle_initial': read(profile, 'middle_initial'),
      'last_name': read(profile, 'last_name'),
      'contact_no': read(profile, 'contact_no'),
      'sex': read(profile, 'sex'),
      'birthday': read(profile, 'birthday', null),
      'company_name': read(company, 'company_name'),
      'company_email': read(company, 'company_email'),
      'company_contact_no': read(company, 'company_contact_no'),
      'region': read(company, 'region'),
      'description': read(company, 'description'),
      'monthly_salary': read(company, 'monthly_salary', null),
      'is_hiring': read(company, 'is_hiring', false),
      'province_code': read(address, 'province_code'),
      'province_name': read(address, 'province_name'),
      'municipality_code': read(address, 'municipality_code'),
      'municipality_name': read(address, 'municipality_name'),
      'barangay': read(address, 'barangay'),
      'street': read(address, 'street'),
      'house_no': read(address, 'house_no'),
      'postal_code': read(address, 'postal_code'),
      'latitude': read(address, 'latitude', null),
      'longitude': read(address, 'longitude', null),
    };
    for (final item in _controllers.entries) {
      payload[item.key] = item.value.text.trim();
    }
    if (widget.section == _Section.hiring) {
      payload['is_hiring'] = _hiring;
      payload['monthly_salary'] = payload['monthly_salary'].toString().isEmpty
          ? null
          : num.tryParse(payload['monthly_salary'].toString());
    }
    if (payload['birthday']?.toString().isEmpty == true)
      payload['birthday'] = null;
    return payload;
  }

  String? _validate(String name, String? raw) {
    final value = raw?.trim() ?? '';
    if (name == 'first_name' || name == 'last_name') {
      return ProfileFieldValidators.personName(value,
          label: name == 'first_name' ? 'First name' : 'Last name');
    }
    if (name == 'middle_initial')
      return ProfileFieldValidators.middleInitial(value);
    if (name == 'contact_no' || name == 'company_contact_no') {
      return ProfileFieldValidators.philippinesMobile(value);
    }
    if ([
          'company_name',
          'company_email',
          'province_name',
          'municipality_name',
          'barangay',
          'street'
        ].contains(name) &&
        value.isEmpty) return 'This field is required.';
    if (name == 'sex' && !const ['Male', 'Female'].contains(value)) {
      return 'Select Male or Female.';
    }
    if (name == 'birthday') {
      if (value.isEmpty) return 'Birthday is required.';
      final date = DateTime.tryParse(value);
      if (date == null ||
          value.length < 10 ||
          SettingsFormat.isoDate(date) != value.substring(0, 10))
        return 'Choose a valid birthday.';
      return ProfileFieldValidators.adultBirthday(date);
    }
    if (name == 'company_email' &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.com$', caseSensitive: false)
            .hasMatch(value)) return 'Enter a valid .com email address.';
    if (name == 'postal_code' &&
        value.isNotEmpty &&
        !RegExp(r'^\d{4}$').hasMatch(value))
      return 'Enter a 4-digit postal code.';
    if (name == 'monthly_salary' &&
        value.isNotEmpty &&
        (num.tryParse(value) == null || num.parse(value) < 0))
      return 'Enter an amount of 0 or more.';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await _api.updateLogisticsAccount(
          accessToken: widget.accessToken, data: _payload());
      if (!mounted) return;
      final value = response['data'];
      Navigator.pop(context,
          value is Map ? Map<String, dynamic>.from(value) : widget.data);
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = e.message;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Could not save changes. Please try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: LogisticsTheme.canvas,
        appBar: AppBar(
            title: Text(_title,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0.5),
        body: Form(
            key: _form,
            child: ListView(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, MediaQuery.paddingOf(context).bottom + 28),
                children: [
                  _EditorIntro(section: widget.section, data: widget.data),
                  const SizedBox(height: 20),
                  if (widget.section == _Section.hiring)
                    _HiringStatusCard(
                        value: _hiring,
                        enabled: !_saving,
                        onChanged: (value) => setState(() => _hiring = value)),
                  for (final group in _fieldGroups(widget.section)) ...[
                    if (widget.section == _Section.hiring ||
                        widget.section == _Section.hub)
                      const SizedBox(height: 20),
                    if (group.$1.isNotEmpty) ...[
                      SettingsSectionLabel(group.$1),
                      const SizedBox(height: 8),
                    ],
                    SettingsGroupCard(
                      children: [
                        for (var i = 0; i < group.$2.length; i++)
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, i == 0 ? 16 : 10,
                                16, i == group.$2.length - 1 ? 16 : 10),
                            child: _editorField(group.$2[i]),
                          ),
                      ],
                    ),
                  ],
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _ErrorCard(message: _error!, retry: _save)),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                          backgroundColor: DriverColors.primary,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save changes')),
                ])),
      );

  List<(String, List<String>)> _fieldGroups(_Section section) =>
      switch (section) {
        _Section.profile => [('Personal details', fields[section]!)],
        _Section.company => [('Company details', fields[section]!)],
        _Section.hub => [
            (
              'Area',
              ['region', 'province_name', 'municipality_name', 'barangay']
            ),
            ('Street address', ['street', 'house_no', 'postal_code']),
          ],
        _Section.hiring => [
            ('Job posting', ['monthly_salary', 'description']),
          ],
      };

  Future<void> _pickBirthday() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final cutoff = DateTime(now.year - 18, now.month, now.day);
    final current = DateTime.tryParse(_controllers['birthday']!.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isAfter(cutoff)
          ? current
          : DateTime(cutoff.year - 7, cutoff.month, cutoff.day),
      firstDate: DateTime(1900),
      lastDate: cutoff,
      helpText: 'Select birthday',
    );
    if (picked != null)
      _controllers['birthday']!.text = SettingsFormat.isoDate(picked);
  }

  Widget _editorField(String name) {
    if (name == 'sex') {
      return DropdownButtonFormField<String>(
        initialValue:
            const ['Male', 'Female'].contains(_controllers[name]!.text)
                ? _controllers[name]!.text
                : null,
        decoration: InputDecoration(
          labelText: labels[name],
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: DriverColors.border)),
        ),
        items: const [
          DropdownMenuItem(value: 'Male', child: Text('Male')),
          DropdownMenuItem(value: 'Female', child: Text('Female'))
        ],
        onChanged:
            _saving ? null : (value) => _controllers[name]!.text = value ?? '',
        validator: (value) => value == null ? 'Select Male or Female.' : null,
      );
    }
    return TextFormField(
      controller: _controllers[name],
      enabled: !_saving,
      readOnly: name == 'birthday',
      onTap: name == 'birthday' ? _pickBirthday : null,
      maxLines: name == 'description' ? 5 : 1,
      maxLength: name == 'description' ? 2000 : null,
      keyboardType: [
        'contact_no',
        'company_contact_no',
        'postal_code',
        'monthly_salary'
      ].contains(name)
          ? TextInputType.number
          : name == 'company_email'
              ? TextInputType.emailAddress
              : TextInputType.text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: DriverColors.textPrimary),
      decoration: InputDecoration(
        labelText: labels[name],
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        suffixIcon: name == 'birthday'
            ? const Icon(Icons.calendar_month_rounded)
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: DriverColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: DriverColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: DriverColors.primary, width: 1.5)),
      ),
      validator: (value) => _validate(name, value),
    );
  }
}

class _EditorIntro extends StatelessWidget {
  const _EditorIntro({required this.section, required this.data});
  final _Section section;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final details = switch (section) {
      _Section.profile => (
          Icons.badge_outlined,
          'Keep your contact details current so your team and partners can reach you.'
        ),
      _Section.company => (
          Icons.business_outlined,
          'These details identify your logistics company across BuyTheWay.'
        ),
      _Section.hub => (
          Icons.location_on_outlined,
          'Set the correct dispatch hub so nearby riders can find your operations.'
        ),
      _Section.hiring => (
          Icons.delivery_dining_rounded,
          'Tell riders what the role offers and when applications are open.'
        ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DriverColors.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: DriverColors.primarySurface,
                borderRadius: BorderRadius.circular(14)),
            child: Icon(details.$1, color: DriverColors.primary, size: 23)),
        const SizedBox(width: 13),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              section == _Section.hiring &&
                      (data['company'] as Map?)?['is_hiring'] == true
                  ? 'Hiring is open'
                  : 'Manage ${section == _Section.hiring ? 'rider hiring' : section == _Section.hub ? 'your hub' : section == _Section.profile ? 'your profile' : 'company details'}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: DriverColors.textPrimary)),
          const SizedBox(height: 5),
          Text(details.$2,
              style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: DriverColors.textSecondary)),
        ])),
      ]),
    );
  }
}

class _HiringStatusCard extends StatelessWidget {
  const _HiringStatusCard(
      {required this.value, required this.enabled, required this.onChanged});
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
            color: value ? const Color(0xFFECFDF5) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: value ? const Color(0xFFBBF7D0) : DriverColors.border)),
        child: Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: value ? Colors.white : DriverColors.primarySurface,
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(
                  value
                      ? Icons.campaign_rounded
                      : Icons.pause_circle_outline_rounded,
                  color: value
                      ? DriverColors.success
                      : DriverColors.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(value ? 'Applications are open' : 'Hiring is paused',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: DriverColors.textPrimary)),
                const SizedBox(height: 3),
                Text(
                    value
                        ? 'Your listing appears in Find Work.'
                        : 'Your listing is hidden from riders.',
                    style: const TextStyle(
                        fontSize: 11.5, color: DriverColors.textSecondary)),
              ])),
          Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: DriverColors.primary),
        ]),
      );
}

class _SecurityScreen extends StatelessWidget {
  const _SecurityScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: LogisticsTheme.canvas,
      appBar: AppBar(
          title: const Text('Security'),
          backgroundColor: LogisticsTheme.canvas,
          surfaceTintColor: Colors.transparent),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
          children: [
            Text('Manage your password and sign-in methods.',
                style: DriverText.body),
            const SizedBox(height: 22),
            const SignInMethodsSection()
          ]));
}

class _NotificationsScreen extends StatefulWidget {
  const _NotificationsScreen({required this.accessToken});
  final String accessToken;

  @override
  State<_NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<_NotificationsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _preferences;
  final Set<String> _busy = {};
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final response = await _api.getLogisticsNotificationPreferences(
          accessToken: widget.accessToken);
      if (!mounted) return;
      final data = response['data'];
      setState(() {
        _preferences = data is Map ? Map<String, dynamic>.from(data) : {};
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted)
        setState(() {
          _error = error.message;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _error = 'Could not load notification preferences.';
          _loading = false;
        });
    }
  }

  Future<void> _toggle(String key, bool value) async {
    final previous = _preferences;
    setState(() {
      _busy.add(key);
      _preferences = {...?previous, key: value};
    });
    try {
      final response = await _api.updateLogisticsNotificationPreferences(
        accessToken: widget.accessToken,
        pushEnabled: key == 'push_enabled' ? value : null,
        soundEnabled: key == 'sound_enabled' ? value : null,
      );
      if (!mounted) return;
      final data = response['data'];
      setState(() => _preferences = data is Map
          ? Map<String, dynamic>.from(data)
          : {...?previous, key: value});
    } catch (_) {
      if (!mounted) return;
      setState(() => _preferences = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not save notification setting. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Widget _switch(String key, IconData icon, String title, String subtitle) =>
      Opacity(
        opacity: _busy.contains(key) ? 0.6 : 1,
        child: IgnorePointer(
          ignoring: _busy.contains(key),
          child: SettingsSwitchTile(
            icon: icon,
            title: title,
            subtitle: subtitle,
            value: _preferences?[key] == true,
            onChanged: (value) => _toggle(key, value),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: LogisticsTheme.canvas,
        appBar: AppBar(
          title: const Text('Notifications',
              style: TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0.5,
        ),
        body: _loading && _preferences == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _preferences == null
                ? Center(
                    child: TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: Text(_error!)))
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                        16, 20, 16, MediaQuery.paddingOf(context).bottom + 28),
                    children: [
                      const SettingsSectionLabel('Preferences'),
                      SettingsGroupCard(children: [
                        _switch(
                            'push_enabled',
                            Icons.notifications_outlined,
                            'Push notifications',
                            'Turn operational alerts on or off.'),
                        _switch(
                            'sound_enabled',
                            Icons.volume_up_outlined,
                            'Sound alerts',
                            'Choose whether push alerts play a sound.'),
                      ]),
                      const SizedBox(height: 12),
                      const Text(
                          'Your in-app notification inbox remains available when push alerts are off.',
                          style: TextStyle(
                              color: DriverColors.textSecondary,
                              fontSize: 12,
                              height: 1.4)),
                    ],
                  ),
      );
}

class _GuideGroup extends StatelessWidget {
  const _GuideGroup(
      {required this.title, required this.icon, required this.items});
  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DriverColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 8),
              child: Row(children: [
                Icon(icon, size: 18, color: DriverColors.primary),
                const SizedBox(width: 9),
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: DriverColors.textPrimary)),
              ])),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  15, 9, 15, i == items.length - 1 ? 14 : 9),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: DriverColors.primary, shape: BoxShape.circle)),
                const SizedBox(width: 11),
                Expanded(
                    child: Text(items[i],
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: DriverColors.textPrimary))),
              ]),
            ),
        ]),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF3ED),
          borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFA5452C)),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
        TextButton(onPressed: retry, child: const Text('Retry'))
      ]));
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel(
      {required this.account, required this.profile, this.companyName});
  final LogisticsAccount account;
  final Map<String, dynamic> profile;
  final String? companyName;
  @override
  Widget build(BuildContext context) {
    final first = profile['first_name']?.toString().trim() ?? account.firstName;
    final last = profile['last_name']?.toString().trim() ?? account.lastName;
    final name = '$first $last'.trim().isEmpty
        ? account.ownerName
        : '$first $last'.trim();
    final initials = name
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();
    final joined = account.memberSince.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: DriverColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: DriverColors.primarySurface,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(initials.isEmpty ? '—' : initials,
                    style: const TextStyle(
                        color: DriverColors.primaryDark,
                        fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: DriverColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(account.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: DriverColors.textSecondary, fontSize: 11))
                ])),
            Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: account.status.toLowerCase() == 'active'
                        ? DriverColors.success
                        : DriverColors.warning,
                    shape: BoxShape.circle))
          ]),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: DriverColors.border)),
          Text(
              companyName?.trim().isNotEmpty == true
                  ? companyName!
                  : account.companyName,
              style: const TextStyle(
                  color: DriverColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text('Partner since ${months[joined.month - 1]} ${joined.year}',
              style: const TextStyle(
                  color: DriverColors.textSecondary, fontSize: 10)),
        ]));
  }
}
