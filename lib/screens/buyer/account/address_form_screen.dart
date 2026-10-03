import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/api_service.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';

const _regions = ['Luzon', 'Visayas', 'Mindanao'];
const _labels = ['Home', 'Work', 'Other'];

/// A PSGC place (province / city / barangay).
class _Place {
  final String code;
  final String name;
  final String? islandGroup;

  const _Place(this.code, this.name, [this.islandGroup]);

  factory _Place.from(dynamic raw) {
    final m = raw is Map ? raw : const {};
    return _Place('${m['code'] ?? ''}', '${m['name'] ?? ''}', m['islandGroupCode']?.toString());
  }
}

/// Add / edit an address with the same island-group → province → city →
/// barangay cascade (PSGC) the web form uses, so checkout can route it.
class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key, this.initial});

  final Address? initial;

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _api = ApiService();
  final store = BuyerStore.instance;
  final _formKey = GlobalKey<FormState>();

  late final name = TextEditingController(text: widget.initial?.fullName);
  late final phone = TextEditingController(text: widget.initial?.phone);
  late final houseNo = TextEditingController(text: widget.initial?.houseNo);
  late final street = TextEditingController(text: widget.initial?.line1);
  late final postal = TextEditingController(text: widget.initial?.postalCode);

  late String region = _regions.contains(widget.initial?.region) ? widget.initial!.region : '';
  _Place? province;
  _Place? city;
  String barangay = '';
  late String label = _labels.contains(widget.initial?.label) ? widget.initial!.label : 'Home';
  late bool makeDefault = widget.initial?.isDefault ?? store.addresses.isEmpty;

  List<_Place> provinces = [];
  bool saving = false;
  bool showErrors = false;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    if (a != null && a.provinceCode.isNotEmpty) province = _Place(a.provinceCode, a.province);
    if (a != null && a.municipalityCode.isNotEmpty) city = _Place(a.municipalityCode, a.city);
    barangay = a?.barangay ?? '';
    _api.getProvinces().then((list) {
      if (mounted) setState(() => provinces = list.map(_Place.from).where((p) => p.code.isNotEmpty).toList()..sort((x, y) => x.name.compareTo(y.name)));
    }).catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [name, phone, houseNo, street, postal]) {
      c.dispose();
    }
    super.dispose();
  }

  List<_Place> get _provincesForRegion {
    final group = region.toLowerCase();
    if (group.isEmpty || !provinces.any((p) => p.islandGroup != null)) return provinces;
    return provinces.where((p) => p.islandGroup == null || p.islandGroup == group).toList();
  }

  Future<void> _pickProvince() async {
    final picked = await _pickPlace('Province', () async => _provincesForRegion);
    if (picked == null) return;
    setState(() {
      if (picked.code != province?.code) {
        city = null;
        barangay = '';
      }
      province = picked;
      final group = picked.islandGroup;
      if (region.isEmpty && group != null && group.isNotEmpty) region = group[0].toUpperCase() + group.substring(1);
    });
  }

  Future<void> _pickCity() async {
    final p = province;
    if (p == null) return;
    final picked = await _pickPlace('City / Municipality', () async => (await _api.getMunicipalities(provinceCode: p.code)).map(_Place.from).toList());
    if (picked == null) return;
    setState(() {
      if (picked.code != city?.code) barangay = '';
      city = picked;
    });
  }

  Future<void> _pickBarangay() async {
    final c = city;
    if (c == null) return;
    final picked = await _pickPlace('Barangay', () async => (await _api.getBarangays(municipalityCode: c.code)).map(_Place.from).toList());
    if (picked != null) setState(() => barangay = picked.name);
  }

  Future<_Place?> _pickPlace(String title, Future<List<_Place>> Function() load) {
    return showModalBottomSheet<_Place>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BRadius.md))),
      builder: (_) => _PlacePicker(title: title, load: load),
    );
  }

  Future<void> _save() async {
    setState(() => showErrors = true);
    final valid = _formKey.currentState!.validate();
    if (!valid || region.isEmpty || province == null || city == null || barangay.isEmpty) {
      showToast(context, 'Please complete the highlighted fields.', error: true);
      return;
    }
    setState(() => saving = true);
    try {
      final saved = await store.saveAddress({
        'recipient_name': name.text.trim(),
        'contact_no': phone.text.trim(),
        'house_no': houseNo.text.trim().isEmpty ? null : houseNo.text.trim(),
        'line1': street.text.trim(),
        'region_name': region,
        'province_code': province!.code,
        'province': province!.name,
        'municipality_code': city!.code,
        'city': city!.name,
        'barangay': barangay,
        'postal_code': postal.text.trim().isEmpty ? null : postal.text.trim(),
        'label': label,
        'is_default': makeDefault,
      }, id: widget.initial?.id);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        showToast(context, store.handleError(e), error: true);
      }
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

  Widget _selectField(String label, String? value, VoidCallback? onTap, {String? disabledHint}) {
    final missing = showErrors && (value == null || value.isEmpty);
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: _dec(label).copyWith(
          errorText: missing ? (onTap == null && disabledHint != null ? disabledHint : 'Required') : null,
          suffixIcon: const Icon(Icons.expand_more),
          enabled: onTap != null,
        ),
        isEmpty: value == null || value.isEmpty,
        child: Text(value ?? '', style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Scaffold(
      backgroundColor: BColors.background,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        surfaceTintColor: BColors.surface,
        foregroundColor: BColors.ink,
        title: Text(editing ? 'Edit Address' : 'New Address', style: BText.title),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: showErrors ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        child: ListView(padding: const EdgeInsets.all(14), children: [
          const Text('Contact', style: BText.section),
          const SizedBox(height: 10),
          TextFormField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: _dec('Full name'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')), LengthLimitingTextInputFormatter(16)],
            decoration: _dec('Phone number', hint: '09XX XXX XXXX'),
            validator: (v) => RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch((v ?? '').replaceAll(' ', '')) ? null : 'Enter a valid PH mobile number',
          ),
          const SizedBox(height: 20),
          const Text('Address', style: BText.section),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: region.isEmpty ? null : region,
            decoration: _dec('Region'),
            items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            validator: (v) => v == null ? 'Required' : null,
            onChanged: (v) => setState(() {
              region = v ?? '';
              if (province?.islandGroup != null && province!.islandGroup != region.toLowerCase()) {
                province = null;
                city = null;
                barangay = '';
              }
            }),
          ),
          const SizedBox(height: 12),
          _selectField('Province', province?.name, _pickProvince),
          const SizedBox(height: 12),
          _selectField('City / Municipality', city?.name, province == null ? null : _pickCity, disabledHint: 'Choose a province first'),
          const SizedBox(height: 12),
          _selectField('Barangay', barangay, city == null ? null : _pickBarangay, disabledHint: 'Choose a city first'),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: TextFormField(controller: houseNo, decoration: _dec('House no.'))),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: street,
                decoration: _dec('Street, building'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: postal,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: _dec('Postal code (optional)'),
          ),
          const SizedBox(height: 20),
          const Text('Label as', style: BText.section),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _labels
                .map((l) => ChoiceChip(
                      label: Text(l),
                      selected: label == l,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => label = l),
                      selectedColor: BColors.brandSurface,
                      backgroundColor: BColors.surface,
                      side: BorderSide(color: label == l ? BColors.brand : BColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
                      labelStyle: TextStyle(color: label == l ? BColors.brand : BColors.ink),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: makeDefault,
            onChanged: (widget.initial?.isDefault ?? false) ? null : (v) => setState(() => makeDefault = v),
            activeTrackColor: BColors.brand,
            contentPadding: EdgeInsets.zero,
            title: const Text('Set as default address', style: TextStyle(fontSize: 14)),
          ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton(
            onPressed: saving ? null : _save,
            style: BButtons.brand(height: 48),
            child: saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Save Address'),
          ),
        ),
      ),
    );
  }
}

class _PlacePicker extends StatefulWidget {
  const _PlacePicker({required this.title, required this.load});

  final String title;
  final Future<List<_Place>> Function() load;

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  List<_Place>? places;
  String? error;
  String query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final list = await widget.load();
      if (mounted) setState(() => places = list);
    } catch (e) {
      if (mounted) setState(() => error = 'Couldn\'t load the list. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = (places ?? const <_Place>[]).where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Select ${widget.title}', style: BText.title),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: places == null
                ? (error != null
                    ? ErrorState(message: error!, onRetry: _load)
                    : const Center(child: CircularProgressIndicator(color: BColors.brand)))
                : filtered.isEmpty
                    ? const Center(child: Text('No matches', style: BText.small))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          title: Text(filtered[i].name, style: const TextStyle(fontSize: 14)),
                          onTap: () => Navigator.pop(context, filtered[i]),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}
