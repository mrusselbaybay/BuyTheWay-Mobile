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
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Sign out?'),
              content: const Text(
                  'You will need to sign in again to access the Logistics app.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sign out'))
              ],
            ));
    if (yes == true) widget.onSignOut();
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
                        title: 'Notification guide',
                        subtitle: 'Alerts and automatic company emails',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const _NotificationsScreen()))),
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
    if ([
          'first_name',
          'last_name',
          'company_name',
          'company_email',
          'company_contact_no',
          'province_name',
          'municipality_name',
          'barangay',
          'street',
          'postal_code'
        ].contains(name) &&
        value.isEmpty) return 'This field is required.';
    if (name == 'company_email' &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value))
      return 'Enter a valid email address.';
    if (['contact_no', 'company_contact_no'].contains(name) &&
        value.isNotEmpty &&
        !RegExp(r'^09\d{9}$').hasMatch(value))
      return 'Use 11 digits starting with 09.';
    if (name == 'postal_code' && !RegExp(r'^\d{4}$').hasMatch(value))
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
            title: Text(_title),
            backgroundColor: LogisticsTheme.canvas,
            surfaceTintColor: Colors.transparent),
        body: Form(
            key: _form,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
                children: [
                  if (widget.section == _Section.hiring)
                    SwitchListTile.adaptive(
                        value: _hiring,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _hiring = value),
                        title: const Text('Currently hiring',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(_hiring
                            ? 'Visible in Find Work'
                            : 'Hidden from Find Work'),
                        contentPadding: EdgeInsets.zero,
                        activeColor: DriverColors.primary),
                  for (final name in fields[widget.section]!) ...[
                    TextFormField(
                        controller: _controllers[name],
                        enabled: !_saving,
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
                        decoration: InputDecoration(
                            labelText: labels[name],
                            border: const OutlineInputBorder()),
                        validator: (value) => _validate(name, value)),
                    const SizedBox(height: 14),
                  ],
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.redAccent))),
                  FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                          backgroundColor: DriverColors.primary,
                          minimumSize: const Size.fromHeight(50)),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save changes')),
                ])),
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

class _NotificationsScreen extends StatelessWidget {
  const _NotificationsScreen();
  static const attention = [
    'Failed delivery attempts',
    'Parcels needing dispatcher review',
    'Transfer requests awaiting a reply',
    'Parcels waiting for a delivery rider',
    'Pickups without a rider',
    'Parcels needing a transfer decision',
    'Barangays without an appointed rider',
    'Pending rider applications',
    'Rider resignation requests'
  ];
  static const emails = [
    'Application accepted, rejected or interview',
    'Removed from your team',
    'Team invitation',
    'Invitation renewal request'
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: LogisticsTheme.canvas,
      appBar: AppBar(
          title: const Text('Notification guide'),
          backgroundColor: LogisticsTheme.canvas,
          surfaceTintColor: Colors.transparent),
      body: ListView(padding: const EdgeInsets.all(22), children: [
        const SettingsSectionLabel('Needs attention'),
        const SizedBox(height: 8),
        SettingsGroupCard(children: [
          for (final item in attention)
            ListTile(
                dense: true,
                leading: const Icon(Icons.circle,
                    size: 7, color: DriverColors.primary),
                title: Text(item))
        ]),
        const SizedBox(height: 22),
        const SettingsSectionLabel('Emails sent for your company'),
        const SizedBox(height: 8),
        SettingsGroupCard(children: [
          for (final item in emails)
            ListTile(
                dense: true,
                leading: const Icon(Icons.mail_outline_rounded, size: 19),
                title: Text(item))
        ]),
        const SizedBox(height: 16),
        const Text(
            'Company emails are automatic and cannot currently be turned off individually. Personal alerts appear in the app.',
            style: TextStyle(color: DriverColors.textSecondary, fontSize: 12)),
      ]));
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
