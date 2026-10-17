import 'package:flutter/material.dart';

import '../../../widgets/image_crop_sheet.dart';
import '../buyer_store.dart';
import 'buyer_widgets.dart';

/// The GCash QR a buyer keeps on their account so a seller can pay a manual
/// refund. Picking an image always opens the square cropper first; nothing
/// is uploaded until the crop is confirmed.
class BuyerPaymentQrCard extends StatefulWidget {
  const BuyerPaymentQrCard({super.key, this.onChanged});

  /// Called with true/false whenever the account gains or loses a QR.
  final ValueChanged<bool>? onChanged;

  @override
  State<BuyerPaymentQrCard> createState() => _BuyerPaymentQrCardState();
}

class _BuyerPaymentQrCardState extends State<BuyerPaymentQrCard> {
  final store = BuyerStore.instance;
  String? _url;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await store.api.paymentQr();
      if (!mounted) return;
      setState(() {
        _url = url;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = store.handleError(e);
        _loading = false;
      });
    }
  }

  Future<void> _change() async {
    final png = await pickAndCropImage(context, qr: true);
    if (png == null || !mounted) return;
    await _run(() async => _url = await store.api.uploadPaymentQr(png));
  }

  Future<void> _remove() => _run(() async {
        await store.api.removePaymentQr();
        _url = null;
      });

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await job();
      widget.onChanged?.call(_url != null);
    } catch (e) {
      if (mounted) setState(() => _error = store.handleError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFF1F8F4), Color(0xFFE6F2EC)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCFE3D8))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCFE3D8))),
          child: _loading
              ? const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : _url == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Icon(Icons.qr_code_2_rounded,
                              size: 40, color: Color(0xFF7B998B)),
                          SizedBox(height: 4),
                          Text('No QR yet',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF64776F))),
                        ])
                  : Padding(
                      padding: const EdgeInsets.all(6),
                      child: NetImage(_url, fit: BoxFit.contain)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Your GCash QR code',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
                'Sellers scan this to pay your refunds. Take a screenshot of your QR in GCash → Receive Money.',
                style: TextStyle(
                    fontSize: 12, color: Color(0xFF64776F), height: 1.4)),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF9A4236))),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              FilledButton(
                  onPressed: _busy || _loading ? null : _change,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: const Color(0xFF176450)),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_url == null ? 'Upload QR' : 'Replace')),
              if (_url != null)
                OutlinedButton(
                    onPressed: _busy ? null : _remove,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44)),
                    child: const Text('Remove')),
            ]),
          ]),
        ),
      ]),
    );
  }
}
