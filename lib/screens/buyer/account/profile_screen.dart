import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/auth_screen.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../payments_util.dart';
import '../widgets/buyer_widgets.dart';

const _sexOptions = ['Male', 'Female', 'Prefer not to say'];

/// Personal info + profile photo, and the account "danger zone".
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final store = BuyerStore.instance;
  final _formKey = GlobalKey<FormState>();
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [first, middle, last, contact]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(BuyerProfile p) {
    first.text = p.firstName;
    middle.text = p.middleInitial ?? '';
    last.text = p.lastName;
    contact.text = p.contactNo ?? '';
    sex = _sexOptions.contains(p.sex) ? p.sex : null;
    birthday = p.birthday;
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

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birthday ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now.subtract(const Duration(days: 1)),
    );
    if (picked != null) setState(() => birthday = picked);
  }

  Future<void> _changeAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: BColors.surface,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from library'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => uploadingAvatar = true);
    try {
      final name = file.name.contains('.') ? file.name : '${file.name}.jpg';
      await store.api.uploadAvatar(await file.readAsBytes(), name);
      await store.loadProfile();
      if (mounted) showToast(context, 'Profile photo updated');
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await store.api.updateProfile({
        'first_name': first.text.trim(),
        'last_name': last.text.trim(),
        'middle_initial': middle.text.trim().isEmpty ? null : middle.text.trim().toUpperCase(),
        'sex': sex,
        'contact_no': contact.text.trim().isEmpty ? null : contact.text.trim(),
        'birthday': birthday == null
            ? null
            : '${birthday!.year}-${birthday!.month.toString().padLeft(2, '0')}-${birthday!.day.toString().padLeft(2, '0')}',
      });
      await store.loadProfile();
      if (mounted) showToast(context, 'Profile saved');
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _deactivate() async {
    final password = await showDialog<String>(context: context, builder: (_) => const _DeactivateDialog());
    if (password == null || !mounted) return;
    final nav = Navigator.of(context);
    try {
      await store.api.deactivateAccount(password);
      await store.signOut();
      nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: BColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BRadius.sm), borderSide: const BorderSide(color: BColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BRadius.sm), borderSide: const BorderSide(color: BColors.brand, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BColors.background,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        surfaceTintColor: BColors.surface,
        foregroundColor: BColors.ink,
        title: const Text('My Profile', style: BText.title),
      ),
      body: loading && store.profile == null
          ? const Center(child: CircularProgressIndicator(color: BColors.brand))
          : error != null && store.profile == null
              ? ErrorState(message: error!, onRetry: _load)
              : ListenableBuilder(
                  listenable: store,
                  builder: (context, _) => Form(
                    key: _formKey,
                    child: ListView(padding: const EdgeInsets.all(14), children: [
                      Center(
                        child: Semantics(
                          button: true,
                          label: 'Change profile photo',
                          child: GestureDetector(
                            onTap: uploadingAvatar ? null : _changeAvatar,
                            child: Stack(children: [
                              ClipOval(
                                child: SizedBox(
                                  width: 96,
                                  height: 96,
                                  child: store.avatarUrl != null
                                      ? NetImage(store.avatarUrl, fallbackIcon: Icons.person)
                                      : Container(color: BColors.brandSurface, child: const Icon(Icons.person, size: 48, color: BColors.brand)),
                                ),
                              ),
                              if (uploadingAvatar)
                                const Positioned.fill(
                                  child: ColoredBox(color: Colors.black38, child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))),
                                ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: BColors.brand, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                  child: const Icon(Icons.photo_camera, size: 16, color: Colors.white),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(child: Text(store.profile?.email ?? store.email, style: BText.small)),
                      const SizedBox(height: 20),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: TextFormField(
                            controller: first,
                            textCapitalization: TextCapitalization.words,
                            decoration: _dec('First name'),
                            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 64,
                          child: TextFormField(
                            controller: middle,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [LengthLimitingTextInputFormatter(1)],
                            decoration: _dec('M.I.'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: last,
                        textCapitalization: TextCapitalization.words,
                        decoration: _dec('Last name'),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: contact,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')), LengthLimitingTextInputFormatter(16)],
                        decoration: _dec('Mobile number', hint: '09XX XXX XXXX'),
                        validator: (v) => (v ?? '').trim().isEmpty || validPhPhone(v!) ? null : 'Enter a valid PH mobile number',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: sex,
                        decoration: _dec('Sex'),
                        items: _sexOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => sex = v),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickBirthday,
                        child: InputDecorator(
                          decoration: _dec('Birthday').copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
                          isEmpty: birthday == null,
                          child: Text(birthday == null ? '' : formatDate(birthday), style: const TextStyle(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: saving ? null : _save,
                        style: BButtons.brand(height: 48),
                        child: saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                            : const Text('Save Changes'),
                      ),
                      const SizedBox(height: 32),
                      const Divider(color: BColors.border),
                      const SizedBox(height: 8),
                      const Text('Danger zone', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: BColors.error)),
                      const SizedBox(height: 4),
                      const Text('Deactivating signs you out and hides your account. Contact support to restore it.', style: BText.small),
                      const SizedBox(height: 10),
                      OutlinedButton(onPressed: _deactivate, style: BButtons.outline(height: 44, color: BColors.error), child: const Text('Deactivate Account')),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
    );
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

  @override
  Widget build(BuildContext context) {
    final ready = phrase.text == 'DEACTIVATE' && password.text.isNotEmpty;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BRadius.md)),
      title: const Text('Deactivate account?', style: BText.title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Type DEACTIVATE and enter your password to confirm.', style: BText.body),
          const SizedBox(height: 12),
          TextField(
            controller: phrase,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Type DEACTIVATE', isDense: true, border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: password,
            onChanged: (_) => setState(() {}),
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: obscure ? 'Show password' : 'Hide password',
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => obscure = !obscure),
              ),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: BColors.muted))),
        TextButton(
          onPressed: ready ? () => Navigator.pop(context, password.text) : null,
          child: Text('Deactivate', style: TextStyle(color: ready ? BColors.error : BColors.faint, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
