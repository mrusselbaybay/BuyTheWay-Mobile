import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/auth_screen.dart';
import '../../driver/driver_theme.dart';
import '../../driver/settings/widgets/settings_widgets.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';
import 'settings_kit.dart';
import 'settings_screens.dart';

const _sexOptions = ['Male', 'Female', 'Prefer not to say'];

// Same photo rules as the web profile page.
const _photoTypes = {'jpg', 'jpeg', 'png', 'webp'};
const _photoMaxBytes = 2 * 1024 * 1024;
const _photoMinSize = 128;

/// "+639171234567" / "639171234567" / "9171234567" → "09171234567" (max 11 digits).
String toLocalMobile(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('63')) digits = '0${digits.substring(2)}';
  if (digits.startsWith('9')) digits = '0$digits';
  return digits.length > 11 ? digits.substring(0, 11) : digits;
}

bool isValidLocalMobile(String v) => RegExp(r'^09\d{9}$').hasMatch(v);

class _LocalMobileFormatter extends TextInputFormatter {
  const _LocalMobileFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = toLocalMobile(newValue.text);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Personal info + profile photo, and the account "danger zone".
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final store = BuyerStore.instance;
  final first = TextEditingController();
  final middle = TextEditingController();
  final last = TextEditingController();
  final contact = TextEditingController();
  String? sex;
  DateTime? birthday;
  bool loading = true;
  String? error;
  bool saving = false;
  bool uploadingAvatar = false;
  bool submitted = false;

  List<TextEditingController> get _controllers => [first, middle, last, contact];

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(_onEdit);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onEdit() {
    if (mounted) setState(() {});
  }

  void _fill(BuyerProfile p) {
    first.text = p.firstName;
    middle.text = p.middleInitial ?? '';
    last.text = p.lastName;
    contact.text = toLocalMobile(p.contactNo ?? '');
    sex = _sexOptions.contains(p.sex) ? p.sex : null;
    birthday = p.birthday;
  }

  bool get _dirty {
    final p = store.profile;
    if (p == null) return false;
    return first.text.trim() != p.firstName ||
        middle.text.trim() != (p.middleInitial ?? '') ||
        last.text.trim() != p.lastName ||
        contact.text.trim() != toLocalMobile(p.contactNo ?? '') ||
        sex != (_sexOptions.contains(p.sex) ? p.sex : null) ||
        birthday != p.birthday;
  }

  /// How much of the profile is filled in (photo + the five details).
  double get _completeness {
    final filled = [
      store.avatarUrl != null,
      first.text.trim().isNotEmpty,
      last.text.trim().isNotEmpty,
      contact.text.trim().isNotEmpty,
      sex != null,
      birthday != null,
    ].where((v) => v).length;
    return filled / 6;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final cached = store.profile;
    if (cached != null) _fill(cached);
    await store.loadProfile();
    if (store.profile != null) {
      _fill(store.profile!);
    } else {
      error = 'Couldn\'t load your profile. Check your connection.';
    }
    if (mounted) setState(() => loading = false);
  }

  String? get _firstError => submitted && first.text.trim().isEmpty ? 'Enter your first name.' : null;
  String? get _lastError => submitted && last.text.trim().isEmpty ? 'Enter your last name.' : null;
  String? get _middleError => submitted && middle.text.trim().isNotEmpty && !RegExp(r'^[A-Za-z]$').hasMatch(middle.text.trim()) ? 'One letter.' : null;
  String? get _phoneError => submitted && contact.text.trim().isNotEmpty && !isValidLocalMobile(contact.text.trim()) ? 'Enter an 11-digit mobile number, like 09171234567.' : null;

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birthday ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now.subtract(const Duration(days: 1)),
      helpText: 'Select your birthday',
    );
    if (picked != null) setState(() => birthday = picked);
  }

  /// Photo rules match the web: JPEG / PNG / WebP, up to 2 MB, at least 128 × 128.
  Future<String?> _photoProblem(XFile file, List<int> bytes) async {
    final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
    if (!_photoTypes.contains(ext)) return 'Use a JPEG, PNG or WebP image.';
    if (bytes.length > _photoMaxBytes) return 'The photo must be 2 MB or smaller.';
    try {
      final image = await decodeImageFromList(Uint8List.fromList(bytes));
      if (image.width < _photoMinSize || image.height < _photoMinSize) return 'Use a photo at least $_photoMinSize × $_photoMinSize pixels.';
    } catch (_) {
      return 'That image couldn\'t be read.';
    }
    return null;
  }

  Future<void> _changeAvatar() async {
    final source = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _SheetOption(icon: Icons.photo_camera_outlined, label: 'Take a photo', onTap: () => Navigator.pop(context, ImageSource.camera)),
            _SheetOption(icon: Icons.photo_library_outlined, label: 'Choose from library', onTap: () => Navigator.pop(context, ImageSource.gallery)),
            if (store.avatarUrl != null) _SheetOption(icon: Icons.delete_outline_rounded, label: 'Remove photo', color: DriverColors.error, onTap: () => Navigator.pop(context, 'remove')),
            const Padding(padding: EdgeInsets.fromLTRB(20, 4, 20, 8), child: Text('JPEG, PNG or WebP · up to 2 MB · at least 128 × 128 px', style: DriverText.caption)),
          ]),
        ),
      ),
    );
    if (source == null) return;
    if (!mounted) return;
    if (source == 'remove') {
      final ok = await confirmDialog(context, title: 'Remove your profile photo?', message: 'A generic avatar will show instead.', confirmLabel: 'Remove photo', destructive: true);
      if (!ok || !mounted) return;
      setState(() => uploadingAvatar = true);
      try {
        await store.api.removeAvatar();
        await store.loadProfile();
        if (mounted) showToast(context, 'Profile photo removed');
      } catch (e) {
        if (mounted) showToast(context, store.handleError(e), error: true);
      } finally {
        if (mounted) setState(() => uploadingAvatar = false);
      }
      return;
    }
    final file = await ImagePicker().pickImage(source: source as ImageSource, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final problem = await _photoProblem(file, bytes);
    if (problem != null) {
      if (mounted) showToast(context, problem, error: true);
      return;
    }
    if (!mounted) return;
    setState(() => uploadingAvatar = true);
    try {
      final name = file.name.contains('.') ? file.name : '${file.name}.jpg';
      await store.api.uploadAvatar(bytes, name);
      await store.loadProfile();
      if (mounted) showToast(context, 'Profile photo updated');
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    setState(() => submitted = true);
    if (_firstError != null || _lastError != null || _middleError != null || _phoneError != null) {
      showToast(context, 'Please fix the highlighted fields.', error: true);
      return;
    }
    setState(() => saving = true);
    try {
      await store.api.updateProfile({
        'first_name': first.text.trim(),
        'last_name': last.text.trim(),
        'middle_initial': middle.text.trim().isEmpty ? null : middle.text.trim().toUpperCase(),
        'sex': sex,
        'contact_no': contact.text.trim().isEmpty ? null : contact.text.trim(),
        'birthday': birthday == null ? null : SettingsFormat.isoDate(birthday!),
      });
      await store.loadProfile();
      if (store.profile != null) _fill(store.profile!);
      if (mounted) {
        FocusScope.of(context).unfocus();
        setState(() => submitted = false);
        showToast(context, 'Profile saved');
      }
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _discard() {
    if (store.profile != null) _fill(store.profile!);
    setState(() => submitted = false);
    FocusScope.of(context).unfocus();
  }

  Future<void> _deactivate() => startAccountDeactivation(context);

  // ---------------- UI ----------------

  Widget _avatar() => Semantics(
        button: true,
        label: 'Change profile photo',
        child: GestureDetector(
          onTap: uploadingAvatar ? null : _changeAvatar,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 104,
              height: 104,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(shape: BoxShape.circle, color: DriverColors.primarySurface, border: Border.all(color: Colors.white, width: 4), boxShadow: softShadow(0.2)),
              child: Stack(fit: StackFit.expand, children: [
                if (store.avatarUrl != null) NetImage(store.avatarUrl, fallbackIcon: Icons.person_rounded) else const Icon(Icons.person_rounded, size: 52, color: DriverColors.primary),
                if (uploadingAvatar) const ColoredBox(color: Colors.black38, child: Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)))),
              ]),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: softShadow(0.2)),
                child: const Icon(Icons.photo_camera_rounded, size: 16, color: DriverColors.primary),
              ),
            ),
          ]),
        ),
      );

  /// Teal hero: photo, name, email and a profile-completeness bar.
  Widget _hero() {
    final percent = (_completeness * 100).round();
    final since = store.profile?.memberSince;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: DriverColors.heroGradient),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(children: [
        _avatar(),
        const SizedBox(height: 14),
        Text(store.displayName.isEmpty ? 'Shopper' : store.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 2),
        Text(store.profile?.email ?? store.email, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
        if (since != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified_user_outlined, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text('Buyer · since ${SettingsFormat.dateShort(since)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ],
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text(percent == 100 ? 'Your profile is complete' : 'Complete your profile', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white))),
              Text('$percent%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: _completeness, minHeight: 7, backgroundColor: Colors.white.withValues(alpha: 0.25), valueColor: const AlwaysStoppedAnimation(Colors.white)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _section(IconData icon, String title, List<Widget> fields) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: DriverColors.border), boxShadow: softShadow(0.04)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconTile(icon, size: 32),
            const SizedBox(width: 10),
            Text(title, style: DriverText.sectionTitle),
          ]),
          const SizedBox(height: 16),
          for (var i = 0; i < fields.length; i++) ...[if (i > 0) const SizedBox(height: 14), fields[i]],
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (loading && store.profile == null) {
      return Scaffold(backgroundColor: DriverColors.background, appBar: settingsAppBar('Personal Information', centerTitle: true), body: const Padding(padding: EdgeInsets.all(16), child: RowsSkeleton(count: 4)));
    }
    if (error != null && store.profile == null) {
      return Scaffold(backgroundColor: DriverColors.background, appBar: settingsAppBar('Personal Information', centerTitle: true), body: ErrorState(message: error!, onRetry: _load));
    }
    return PopScope(
      canPop: !_dirty || saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmDialog(context, title: 'Discard changes?', message: 'You have unsaved changes to your profile.', confirmLabel: 'Discard', cancelLabel: 'Keep editing', destructive: true);
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: DriverColors.background,
        appBar: settingsAppBar('Personal Information', centerTitle: true, backgroundColor: DriverColors.primary, foregroundColor: Colors.white),
        bottomNavigationBar: _dirty ? SettingsSaveBar(saving: saving, onCancel: _discard, onSave: _save) : null,
        body: ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
            children: [
              _hero(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(children: [
                  _section(Icons.badge_outlined, 'Name', [
                    SettingsTextField(label: 'First name', controller: first, enabled: !saving, error: _firstError),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: SettingsTextField(label: 'Last name', controller: last, enabled: !saving, error: _lastError)),
                      const SizedBox(width: 12),
                      SizedBox(width: 78, child: SettingsTextField(label: 'M.I.', controller: middle, enabled: !saving, error: _middleError, maxLength: 1, textCapitalization: TextCapitalization.characters)),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  _section(Icons.contact_phone_outlined, 'Contact', [
                    InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BuyerSecurityScreen())),
                      borderRadius: BorderRadius.circular(12),
                      child: SettingsReadOnlyField(label: 'Sign-in email', value: store.profile?.email ?? store.email, trailingIcon: Icons.lock_outline_rounded, note: 'Managed in Login & Security — tap to open.'),
                    ),
                    _PhoneField(controller: contact, enabled: !saving, error: _phoneError),
                  ]),
                  const SizedBox(height: 16),
                  _section(Icons.person_outline_rounded, 'About you', [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SettingsFieldLabel('Sex'),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final option in _sexOptions)
                          ChoiceChip(
                            label: Text(option),
                            selected: sex == option,
                            showCheckmark: false,
                            onSelected: saving ? null : (v) => setState(() => sex = v ? option : null),
                            selectedColor: DriverColors.primary,
                            backgroundColor: DriverColors.background,
                            side: BorderSide.none,
                            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sex == option ? Colors.white : DriverColors.textPrimary),
                          ),
                      ]),
                    ]),
                    SettingsDateField(label: 'Birthday', value: birthday, enabled: !saving, onTap: _pickBirthday),
                  ]),
                  const SizedBox(height: 24),
                  SettingsGroupCard(children: [
                    SettingsNavTile(icon: Icons.person_off_outlined, title: 'Deactivate account', subtitle: 'Signs you out and hides your account', iconColor: DriverColors.error, titleColor: DriverColors.error, onTap: _deactivate),
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mobile-number field: digits only, normalised to the 11-digit local format.
class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.enabled, this.error});
  final TextEditingController controller;
  final bool enabled;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SettingsFieldLabel('Mobile number'),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          inputFormatters: const [_LocalMobileFormatter()],
          style: DriverText.body,
          decoration: InputDecoration(
            hintText: '09171234567',
            prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 19, color: DriverColors.primary),
            filled: true,
            fillColor: DriverColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: error != null ? DriverColors.error : Colors.transparent)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DriverColors.primary, width: 1.5)),
          ),
        ),
        SettingsFieldError(error),
        const Padding(padding: EdgeInsets.only(top: 4), child: Text('Shown to sellers on your orders. Not verified: BuyTheWay doesn\'t check phone numbers yet.', style: DriverText.caption)),
      ]);
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({required this.icon, required this.label, required this.onTap, this.color = DriverColors.primary});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: IconTile(icon, color: color, size: 38),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color == DriverColors.error ? color : DriverColors.textPrimary)),
        onTap: onTap,
      );
}

/// Asks for confirmation (type DEACTIVATE + password), deactivates the buyer
/// account, signs out and returns to the sign-in screen.
Future<void> startAccountDeactivation(BuildContext context) async {
  final store = BuyerStore.instance;
  final password = await showDialog<String>(context: context, builder: (_) => const _DeactivateDialog());
  if (password == null || !context.mounted) return;
  final nav = Navigator.of(context);
  try {
    await store.api.deactivateAccount(password);
    await store.signOut();
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  } catch (e) {
    if (context.mounted) showToast(context, store.handleError(e), error: true);
  }
}

class _DeactivateDialog extends StatefulWidget {
  const _DeactivateDialog();

  @override
  State<_DeactivateDialog> createState() => _DeactivateDialogState();
}

class _DeactivateDialogState extends State<_DeactivateDialog> {
  final phrase = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;

  @override
  void dispose() {
    phrase.dispose();
    password.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19),
        suffixIcon: suffix,
        isDense: true,
        filled: true,
        fillColor: DriverColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DriverColors.error, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    final ready = phrase.text == 'DEACTIVATE' && password.text.isNotEmpty;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      icon: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
        child: const Icon(Icons.warning_amber_rounded, size: 30, color: DriverColors.error),
      ),
      title: const Text('Deactivate your account?', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Consequence('You\'ll be signed out on every device.'),
          const _Consequence('Your account is hidden and you can\'t sign in.'),
          const _Consequence('Contact support to turn it back on.'),
          const SizedBox(height: 14),
          TextField(
            controller: phrase,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.characters,
            decoration: _dec('Type DEACTIVATE', Icons.keyboard_alt_outlined),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: password,
            onChanged: (_) => setState(() {}),
            obscureText: obscure,
            decoration: _dec(
              'Password',
              Icons.lock_outline_rounded,
              suffix: IconButton(tooltip: obscure ? 'Show password' : 'Hide password', icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19), onPressed: () => setState(() => obscure = !obscure)),
            ),
          ),
        ]),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), style: TextButton.styleFrom(minimumSize: const Size(0, 46)), child: const Text('Keep my account', style: TextStyle(color: DriverColors.textSecondary, fontWeight: FontWeight.w700))),
        FilledButton(
          onPressed: ready ? () => Navigator.pop(context, password.text) : null,
          style: FilledButton.styleFrom(backgroundColor: DriverColors.error, minimumSize: const Size(0, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Deactivate', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _Consequence extends StatelessWidget {
  const _Consequence(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.remove_circle_outline_rounded, size: 15, color: DriverColors.error)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: DriverText.body.copyWith(fontSize: 13, height: 1.35))),
        ]),
      );
}
