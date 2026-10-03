import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';

/// Return / refund request for one order item. Photos are compressed on
/// device and sent inline (data URLs), which ReturnController accepts —
/// the same fallback the web uses when storage upload isn't available.
class ReturnRequestScreen extends StatefulWidget {
  const ReturnRequestScreen({super.key, required this.order, required this.item});

  final Order order;
  final OrderItem item;

  @override
  State<ReturnRequestScreen> createState() => _ReturnRequestScreenState();
}

class _ReturnRequestScreenState extends State<ReturnRequestScreen> {
  final store = BuyerStore.instance;
  String requestType = 'return_and_refund';
  String? reason;
  final otherReason = TextEditingController();
  final details = TextEditingController();
  late int quantity = widget.item.quantity;
  final List<Uint8List> photos = [];
  bool submitting = false;
  bool showErrors = false;

  @override
  void initState() {
    super.initState();
    details.addListener(() => setState(() {}));
    otherReason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    otherReason.dispose();
    details.dispose();
    super.dispose();
  }

  double get refundEstimate => widget.item.unitPrice * quantity;

  String? get problem {
    if (reason == null) return 'Choose a reason.';
    if (reason == 'other' && otherReason.text.trim().length < 3) return 'Describe the reason.';
    if (details.text.trim().length < 10) return 'Add a few more details (at least 10 characters).';
    if (photos.isEmpty) return 'Add at least one photo.';
    return null;
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: BColors.surface,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1280, imageQuality: 70);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    // Server limit is 2MB of text per photo; base64 adds ~33%.
    if (bytes.lengthInBytes > 1400 * 1024) {
      if (mounted) showToast(context, 'That photo is too large. Try another one.', error: true);
      return;
    }
    if (mounted) setState(() => photos.add(bytes));
  }

  Future<void> _submit() async {
    setState(() => showErrors = true);
    if (problem != null) {
      showToast(context, problem!, error: true);
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Submit request?',
      message: 'The seller will review your ${requestType == 'refund_only' ? 'refund' : 'return'} request for '
          '$quantity × ${widget.item.name}. You\'ll be notified of their decision.',
      confirmLabel: 'Submit',
    );
    if (!ok || !mounted) return;
    setState(() => submitting = true);
    try {
      await store.api.requestReturn(
        orderItemId: widget.item.id,
        requestType: requestType,
        reason: reason!,
        otherReason: reason == 'other' ? otherReason.text.trim() : null,
        details: details.text.trim(),
        quantity: quantity,
        evidence: photos.map((b) => 'data:image/jpeg;base64,${base64Encode(b)}').toList(),
      );
      if (!mounted) return;
      showToast(context, 'Request submitted');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => submitting = false);
      showToast(context, store.handleError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: BColors.background,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        surfaceTintColor: BColors.surface,
        foregroundColor: BColors.ink,
        title: const Text('Return / Refund', style: BText.title),
      ),
      body: ListView(children: [
        Panel(
          child: Row(children: [
            CategoryThumb(category: item.category, size: 56),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                if (item.variation != null) Text(item.variation!, style: BText.tiny),
                Text('${peso(item.unitPrice)} × ${item.quantity}', style: BText.small),
              ]),
            ),
          ]),
        ),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('What do you need?', style: BText.section),
            const SizedBox(height: 6),
            RadioGroup<String>(
              groupValue: requestType,
              onChanged: (v) => setState(() => requestType = v!),
              child: const Column(children: [
                RadioListTile<String>(
                  value: 'return_and_refund',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: BColors.brand,
                  title: Text('Return & refund', style: TextStyle(fontSize: 14)),
                  subtitle: Text('Send the item back, then get your money back.', style: BText.tiny),
                ),
                RadioListTile<String>(
                  value: 'refund_only',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: BColors.brand,
                  title: Text('Refund only', style: TextStyle(fontSize: 14)),
                  subtitle: Text('Keep the item (e.g. missing or unusable).', style: BText.tiny),
                ),
              ]),
            ),
          ]),
        ),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Reason', style: BText.section),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kReturnReasons.map((r) {
                final (value, label) = r;
                final active = reason == value;
                return ChoiceChip(
                  label: Text(label),
                  selected: active,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => reason = value),
                  backgroundColor: BColors.background,
                  selectedColor: BColors.brandSurface,
                  side: BorderSide(color: active ? BColors.brand : (showErrors && reason == null ? BColors.error : Colors.transparent)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
                  labelStyle: TextStyle(fontSize: 13, color: active ? BColors.brand : BColors.ink),
                );
              }).toList(),
            ),
            if (reason == 'other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: otherReason,
                maxLength: 255,
                decoration: InputDecoration(
                  labelText: 'Your reason',
                  isDense: true,
                  errorText: showErrors && otherReason.text.trim().length < 3 ? 'Required' : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
                ),
              ),
            ],
          ]),
        ),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Quantity', style: BText.section)),
              QtyStepper(value: quantity, max: item.quantity, onChanged: (q) => setState(() => quantity = q)),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: details,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Describe the problem',
                alignLabelWithHint: true,
                hintText: 'e.g. The screen was cracked when I opened the box.',
                errorText: showErrors && details.text.trim().length < 10 ? 'At least 10 characters' : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              const Text('Photos', style: BText.section),
              const SizedBox(width: 6),
              Text('${photos.length}/3 · required', style: TextStyle(fontSize: 12, color: showErrors && photos.isEmpty ? BColors.error : BColors.muted)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < photos.length; i++)
                Stack(clipBehavior: Clip.none, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(BRadius.sm),
                    child: Image.memory(photos[i], width: 76, height: 76, fit: BoxFit.cover, cacheWidth: 228),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: IconButton.filled(
                      tooltip: 'Remove photo',
                      iconSize: 14,
                      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(backgroundColor: BColors.ink),
                      onPressed: () => setState(() => photos.removeAt(i)),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ]),
              if (photos.length < 3)
                InkWell(
                  onTap: _addPhoto,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      border: Border.all(color: showErrors && photos.isEmpty ? BColors.error : BColors.border),
                      borderRadius: BorderRadius.circular(BRadius.sm),
                    ),
                    child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo_outlined, color: BColors.brand),
                      SizedBox(height: 2),
                      Text('Add', style: TextStyle(fontSize: 11.5, color: BColors.brand)),
                    ]),
                  ),
                ),
            ]),
          ]),
        ),
        Panel(
          child: Row(children: [
            const Expanded(child: Text('Estimated refund', style: BText.small)),
            Text(peso(refundEstimate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: BColors.cta)),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 14, 16),
          child: Text('Final amount is confirmed by the seller and may exclude vouchers applied to this item.', style: BText.tiny),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton(
            onPressed: submitting ? null : _submit,
            style: BButtons.cta(height: 48),
            child: submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Submit Request'),
          ),
        ),
      ),
    );
  }
}
