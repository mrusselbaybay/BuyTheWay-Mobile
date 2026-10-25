import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/remittance_api_service.dart';
import '../../widgets/image_crop_sheet.dart';
import '../driver/driver_theme.dart';

/// Where a courier manages the GCash QR code their logistics company scans
/// to pay their earnings. Picking an image always goes through the square
/// cropper first — nothing is uploaded until the crop is confirmed.
class PaymentQrScreen extends StatefulWidget {
  const PaymentQrScreen(
      {super.key,
      required this.accessToken,
      this.role = RemittanceRole.courier});
  final String accessToken;
  final RemittanceRole role;

  @override
  State<PaymentQrScreen> createState() => _PaymentQrScreenState();
}

class _PaymentQrScreenState extends State<PaymentQrScreen> {
  late final RemittanceApiService _api = RemittanceApiService(
      accessToken: widget.accessToken, role: widget.role);
  String? _url;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await _api.paymentQrUrl();
      if (!mounted) return;
      setState(() {
        _url = url;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _change() async {
    final Uint8List? png = await pickAndCropImage(context, qr: true);
    if (png == null || !mounted) return;
    await _run(
        () async => _url = await _api.uploadPaymentQr(png), 'QR code saved.');
  }

  Future<void> _remove() => _run(() async {
        await _api.removePaymentQr();
        _url = null;
      }, 'QR code removed.');

  Future<void> _run(Future<void> Function() job, String done) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await job();
      if (!mounted) return;
      setState(() => _notice = done);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(title: const Text('Payment QR')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFF1F8F4), Color(0xFFE6F2EC)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCFE3D8))),
            child: Column(children: [
              const Text('Get paid faster',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                  widget.role == RemittanceRole.logistics
                      ? 'Sellers scan this QR code with GCash to pay your delivery fees. Your couriers can also use it for COD offsets.'
                      : 'Your logistics company scans this QR code with GCash to pay your earnings.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DriverColors.textSecondary)),
              const SizedBox(height: 16),
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCFE3D8))),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _url == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Icon(Icons.qr_code_2_rounded,
                                    size: 56, color: Color(0xFF7B998B)),
                                SizedBox(height: 6),
                                Text('No QR yet',
                                    style: TextStyle(
                                        color: DriverColors.textSecondary)),
                              ])
                        : Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.network(_url!,
                                fit: BoxFit.contain,
                                webHtmlElementStrategy:
                                    WebHtmlElementStrategy.fallback,
                                semanticLabel: 'Your payment QR code',
                                errorBuilder: (_, __, ___) => const Center(
                                    child: Text('QR could not load.')))),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: const TextStyle(color: DriverColors.error))),
          if (_notice != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_notice!,
                    style: const TextStyle(color: DriverColors.success))),
          FilledButton.icon(
              onPressed: _busy || _loading ? null : _change,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_rounded),
              label: Text(_url == null ? 'Upload QR code' : 'Replace QR code')),
          if (_url != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
                onPressed: _busy ? null : _remove,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                child: const Text('Remove')),
          ],
          const SizedBox(height: 14),
          const Text(
              'Tip: use the QR screenshot from your GCash app (Receive Money → QR). You will be able to crop it before it is saved.',
              style:
                  TextStyle(color: DriverColors.textSecondary, fontSize: 12.5)),
        ]),
      ),
    );
  }
}
