import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../buyer_store.dart';
import '../buyer_theme.dart';

/// Issues a buyer can report on a delivered (not yet received) item — same
/// keys and photo rules as the web OrderDetails report form.
const _issues = [
  ('wrong_missing', 'Wrong or Missing Item'),
  ('damaged_defective', 'Damaged or Defective Item'),
  ('counterfeit_prohibited', 'Counterfeit or Prohibited Item'),
  ('not_as_described', 'Item Not As Described'),
  ('seller_refuses_return', 'Seller Refuses Return or Refund'),
  ('seller_overcharged_no_refund', 'Seller Overcharged or No Refund After Return'),
  ('item_not_delivered', 'Item Not Delivered'),
  ('others', 'Others'),
];

/// Report a delivered product. Pops `true` once submitted.
class ReportDeliveredSheet extends StatefulWidget {
  const ReportDeliveredSheet({super.key, required this.orderNumber, required this.productId, required this.productName});

  final String orderNumber;
  final String productId;
  final String productName;

  @override
  State<ReportDeliveredSheet> createState() => _ReportDeliveredSheetState();
}

typedef _Photo = (String, Uint8List);

class _ReportDeliveredSheetState extends State<ReportDeliveredSheet> {
  final store = BuyerStore.instance;
  final details = TextEditingController();
  String? issue;
  bool sending = false;
  String? error;

  _Photo? package;
  final List<_Photo> contents = [];
  final List<_Photo> evidence = [];

  static const _maxContents = 7;
  static const _maxEvidence = 8;

  bool get _wrongMissing => issue == 'wrong_missing';
  bool get _damaged => issue == 'damaged_defective';

  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  void _pickIssue(String? v) => setState(() {
        issue = v;
        package = null;
        contents.clear();
        evidence.clear();
        error = null;
      });

  Future<List<_Photo>> _pick(int room) async {
    if (room <= 0) return const [];
    final picker = ImagePicker();
    // pickMultiImage's limit must be at least 2.
    final files = room == 1
        ? [if (await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80) case final XFile one) one]
        : await picker.pickMultiImage(maxWidth: 1600, imageQuality: 80, limit: room);
    return [for (final f in files.take(room)) (f.name, await f.readAsBytes())];
  }

  Future<void> _add(List<_Photo> into, int max) async {
    final picked = await _pick(max - into.length);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      into.addAll(picked);
      error = null;
    });
  }

  Future<void> _addPackage() async {
    final picked = await _pick(1);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      package = picked.first;
      error = null;
    });
  }

  String? _validate() {
    if (issue == null) return 'Choose what happened.';
    if (details.text.trim().length < 5) return 'Tell us what happened (at least a few words).';
    if (_wrongMissing && (package == null || contents.isEmpty)) return 'Add a package photo and at least one contents photo.';
    if (!_wrongMissing && evidence.isEmpty) return 'Add at least one photo as evidence.';
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final api = store.api;
      final packagePath = package == null ? Future<String?>.value() : api.uploadReportEvidence(package!.$2, package!.$1);
      final results = await Future.wait([
        packagePath,
        Future.wait(contents.map((p) => api.uploadReportEvidence(p.$2, p.$1))),
        Future.wait(evidence.map((p) => api.uploadReportEvidence(p.$2, p.$1))),
      ]);
      await api.reportDeliveredOrder(
        widget.orderNumber,
        productId: widget.productId,
        issueType: issue!,
        details: details.text.trim(),
        packagePhoto: results[0] as String?,
        contentsPhotos: results[1] as List<String>,
        evidence: results[2] as List<String>,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          sending = false;
          error = store.handleError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: BColors.border, borderRadius: BorderRadius.circular(2))),
          SizedBox(
            height: 56,
            child: Row(children: [
              const SizedBox(width: 48),
              Expanded(
                child: Text('Report ${widget.productName}',
                    textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              IconButton(tooltip: 'Close', onPressed: sending ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              const SizedBox(width: 4),
            ]),
          ),
          const Divider(height: 1, color: BColors.border),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              children: [
                const Text('What happened?', style: BText.section),
                const SizedBox(height: 6),
                RadioGroup<String>(
                  groupValue: issue ?? '',
                  onChanged: _pickIssue,
                  child: Column(children: [
                    for (final (key, label) in _issues)
                      RadioListTile<String>(value: key, dense: true, contentPadding: EdgeInsets.zero, activeColor: BColors.brand, title: Text(label, style: const TextStyle(fontSize: 14))),
                  ]),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: details,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() => error = null),
                  decoration: InputDecoration(
                    hintText: 'Explain what happened so the reviewer can assess your report',
                    filled: true,
                    fillColor: BColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BColors.brand, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 4),
                if (_wrongMissing) ...[
                  _PhotoSection(
                    title: 'Package photo',
                    hint: 'The outside of the parcel as it arrived.',
                    required: true,
                    photos: [if (package != null) package!],
                    max: 1,
                    busy: sending,
                    onAdd: _addPackage,
                    onRemove: (_) => setState(() => package = null),
                  ),
                  _PhotoSection(
                    title: 'Contents photos',
                    hint: 'What was actually inside the box.',
                    required: true,
                    photos: contents,
                    max: _maxContents,
                    busy: sending,
                    onAdd: () => _add(contents, _maxContents),
                    onRemove: (i) => setState(() => contents.removeAt(i)),
                  ),
                ] else if (issue != null)
                  _PhotoSection(
                    title: 'Evidence',
                    hint: _damaged ? 'Clear photos that show the damage or defect.' : 'Screenshots or photos that show the problem.',
                    required: true,
                    photos: evidence,
                    max: _maxEvidence,
                    busy: sending,
                    onAdd: () => _add(evidence, _maxEvidence),
                    onRemove: (i) => setState(() => evidence.removeAt(i)),
                  ),
                const SizedBox(height: 4),
                const Text('Your report opens a case for admin review. No external documents are required.', style: BText.tiny),
                if (error != null)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: BColors.error))),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.paddingOf(context).bottom),
            child: FilledButton(
              onPressed: sending ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: BColors.error, minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
              child: sending
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Submit report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );
}

/// A titled row of photo tiles with an "Add photos" tile — the same look as
/// the shop / product report form's evidence picker.
class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.title,
    required this.hint,
    required this.required,
    required this.photos,
    required this.max,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final String hint;
  final bool required;
  final List<_Photo> photos;
  final int max;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 6),
        Row(children: [
          Text(title, style: BText.section),
          const SizedBox(width: 6),
          if (required) const Text('required', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BColors.error)),
          const Spacer(),
          Text('${photos.length}/$max', style: BText.tiny),
        ]),
        const SizedBox(height: 4),
        Text(hint, style: BText.tiny),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            if (photos.length < max)
              InkWell(
                onTap: busy ? null : onAdd,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 84,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: BColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: BColors.border)),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate_outlined, color: BColors.brand, size: 26),
                    SizedBox(height: 4),
                    Text('Add photos', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: BColors.brand)),
                  ]),
                ),
              ),
            for (var i = 0; i < photos.length; i++)
              Container(
                width: 84,
                margin: const EdgeInsets.only(right: 10),
                child: Stack(fit: StackFit.expand, children: [
                  ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(photos[i].$2, fit: BoxFit.cover, cacheWidth: 250)),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: busy ? null : () => onRemove(i),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Color(0xAA000000), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 8),
      ]);
}
