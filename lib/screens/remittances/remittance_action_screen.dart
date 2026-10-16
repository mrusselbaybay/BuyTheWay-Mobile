import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/remittance_api_service.dart';
import '../driver/driver_theme.dart';
import 'remittance_format.dart';

class RemittanceActionScreen extends StatefulWidget {
  const RemittanceActionScreen(
      {super.key,
      required this.api,
      required this.action,
      required this.tab,
      required this.row,
      this.recipient,
      this.obligationIds,
      this.maxCents});
  final RemittanceApiService api;
  final String action;
  final String tab;
  final Map<String, dynamic> row;
  final Map<String, dynamic>? recipient;
  final List<String>? obligationIds;
  final int? maxCents;
  @override
  State<RemittanceActionScreen> createState() => _RemittanceActionScreenState();
}

class _RemittanceActionScreenState extends State<RemittanceActionScreen> {
  final _form = GlobalKey<FormState>();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  late final _amount =
      TextEditingController(text: (_maximum / 100).toStringAsFixed(2));
  bool _busy = false;
  bool _confirmed = false;
  String? _error;
  Uint8List? _bytes;
  String? _filename;
  String? _proofPath;
  bool get _transfer => ['cod', 'payment'].contains(widget.action);
  int get _maximum =>
      widget.maxCents ??
      (widget.action == 'cod'
          ? remittanceCents(widget.row['remaining_cents'])
          : remittanceCents(widget.row['amount_cents']) -
              remittanceCents(widget.row['paid_cents']));
  String get _title => switch (widget.action) {
        'cod' => 'Remit to seller',
        'payment' => 'Submit fee payment',
        'verify' => 'Confirm receipt',
        'reject' => 'Reject receipt',
        'codDispute' => 'Dispute receipt',
        _ => 'Dispute charge'
      };

  @override
  void dispose() {
    _reference.dispose();
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
          withData: true);
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.size == 0 || file.size > 5 * 1024 * 1024 || file.bytes == null) {
        setState(
            () => _error = 'Choose a JPG, PNG, WebP or PDF smaller than 5 MB.');
        return;
      }
      setState(() {
        _bytes = file.bytes;
        _filename = file.name;
        _proofPath = null;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not open this file. Try choosing it again.');
      }
    }
  }

  Future<void> _openProof() async {
    final uri = Uri.tryParse('${widget.row['proof_url']}');
    if (uri == null || !['http', 'https'].contains(uri.scheme)) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
        throw StateError('Could not open');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not open this proof. Return to the list and refresh for a new link.');
      }
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if ((_transfer || widget.action == 'verify') && !_confirmed) {
      setState(() => _error = widget.action == 'verify'
          ? 'Confirm that you checked your account and received the payment.'
          : 'Confirm that you have already transferred the payment.');
      return;
    }
    if (_transfer && _bytes == null) {
      setState(() => _error = 'Attach your Proof of Payment.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if ((_transfer || widget.action == 'dispute') && _bytes != null) {
        _proofPath ??= await widget.api.uploadProof(_bytes!, _filename!);
      }
      switch (widget.action) {
        case 'cod':
          await widget.api.submitCod(
              collectionId: '${widget.row['id']}',
              reference: _reference.text.trim(),
              proofPath: _proofPath!);
        case 'payment':
          await widget.api.submitPayment(
              obligationIds: widget.obligationIds ?? ['${widget.row['id']}'],
              cents: parseRemittancePesos(_amount.text)!,
              reference: _reference.text.trim(),
              proofPath: _proofPath!);
        case 'dispute':
          await widget.api
              .dispute('${widget.row['id']}', _note.text.trim(), _proofPath);
        default:
          await widget.api.review(
              widget.tab,
              '${widget.row['id']}',
              widget.action == 'codDispute' ? 'dispute' : widget.action,
              _note.text.trim());
      }
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is ApiException
              ? e.message
              : 'Could not complete the request. Return to the list and refresh before retrying.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.recipient?['account'] as Map?;
    final qr = widget.row['seller_qr_url'];
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          backgroundColor: DriverColors.background,
          appBar: AppBar(title: Text(_title)),
          body: SafeArea(
              child: Form(
                  key: _form,
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    Text(remittanceOrder(widget.row),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (widget.action == 'cod') ...[
                      Text(
                          'Send ${remittanceMoney(_maximum)} directly to ${widget.row['seller_name'] ?? 'this order’s seller'}.',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text(
                          'Make the transfer in GCash, then submit its reference and receipt below. Your seller must confirm receipt. Logistics pays your earnings separately.'),
                      const SizedBox(height: 16),
                      if (qr != null)
                        InteractiveViewer(
                            child: Image.network('$qr',
                                height: 240,
                                semanticLabel: 'Seller GCash QR code',
                                loadingBuilder: (context, child, progress) =>
                                    progress == null
                                        ? child
                                        : const SizedBox(
                                            height: 240,
                                            child: Center(
                                                child:
                                                    CircularProgressIndicator())),
                                errorBuilder: (_, __, ___) => const Text(
                                    'QR could not load. Refresh the remittance list and try again.')))
                      else
                        const Text(
                            'The seller has not added a QR code. Confirm their GCash account directly before transferring.',
                            style: TextStyle(color: DriverColors.warning)),
                    ],
                    if (widget.action == 'payment') ...[
                      Text(
                          'Recipient: ${widget.recipient?['name'] ?? remittanceName(widget.row['company'])}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (account != null) ...[
                        Text('${account['account_name'] ?? ''}'),
                        SelectableText('GCash: ${account['number'] ?? ''}')
                      ] else
                        const Text(
                            'Payment account is not configured. Confirm the recipient’s account before transferring.',
                            style: TextStyle(color: DriverColors.warning)),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: _amount,
                          enabled: !_busy,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                              labelText: 'Amount in pesos',
                              helperText:
                                  'Up to ${remittanceMoney(_maximum)}. Partial payments are supported.',
                              border: const OutlineInputBorder()),
                          validator: (text) {
                            final cents = parseRemittancePesos(text ?? '');
                            return cents == null ||
                                    cents <= 0 ||
                                    cents > _maximum
                                ? 'Enter a positive amount up to ${remittanceMoney(_maximum)}.'
                                : null;
                          }),
                    ],
                    if (widget.action == 'verify') ...[
                      Text(
                          'Confirm only after you personally received ${remittanceMoney(widget.row['amount_cents'])} in your account. A reference or screenshot alone does not confirm payment.'),
                      const SizedBox(height: 10),
                      SelectableText(
                          'Transaction: ${widget.row['reference'] ?? ''}'),
                    ],
                    if (widget.row['proof_url'] != null && !_transfer)
                      Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                              onPressed: _openProof,
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('View submitted proof'))),
                    if (widget.action == 'dispute')
                      const Text(
                          'Explain the incorrect charge. The disputed obligation stays visible while an administrator reviews it.'),
                    if (_transfer) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                          controller: _reference,
                          enabled: !_busy,
                          maxLength: 100,
                          decoration: const InputDecoration(
                              labelText: 'Transaction number',
                              border: OutlineInputBorder()),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Enter the GCash transaction number.'
                              : null),
                    ],
                    if (_transfer || widget.action == 'dispute') ...[
                      const SizedBox(height: 12),
                      Text(
                          _transfer
                              ? 'Proof of Payment'
                              : 'Supporting evidence (optional)',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                          onPressed: _busy ? null : _pickProof,
                          icon: const Icon(Icons.attach_file),
                          label: Text(_filename ?? 'Choose screenshot or PDF',
                              overflow: TextOverflow.ellipsis)),
                      const Text('JPG, PNG, WebP or PDF. Maximum 5 MB.',
                          style: TextStyle(
                              color: DriverColors.textSecondary, fontSize: 12)),
                    ],
                    if (!_transfer) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: _note,
                          enabled: !_busy,
                          minLines: 3,
                          maxLines: 6,
                          maxLength: widget.action == 'dispute' ? 4000 : 2000,
                          decoration: InputDecoration(
                              labelText: widget.action == 'verify'
                                  ? 'Verification note (optional)'
                                  : 'Reason',
                              border: const OutlineInputBorder()),
                          validator: (value) {
                            final text = (value ?? '').trim();
                            return widget.action == 'verify'
                                ? null
                                : text.length <
                                        (widget.action == 'dispute' ? 10 : 1)
                                    ? 'Explain your reason${widget.action == 'dispute' ? ' in at least 10 characters' : ''}.'
                                    : null;
                          }),
                    ],
                    if (_transfer || widget.action == 'verify')
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _confirmed,
                          onChanged: _busy
                              ? null
                              : (value) =>
                                  setState(() => _confirmed = value ?? false),
                          title: Text(widget.action == 'verify'
                              ? 'I checked my account and received this payment.'
                              : 'I already transferred this payment to the correct recipient.'),
                          controlAffinity: ListTileControlAffinity.leading),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Semantics(
                              liveRegion: true,
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: DriverColors.error)))),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: _busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Text(_transfer
                                    ? 'Submit Proof of Payment'
                                    : _title))),
                  ]))),
        ));
  }
}
