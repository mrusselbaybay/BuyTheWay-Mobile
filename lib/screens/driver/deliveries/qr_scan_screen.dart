import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../driver_theme.dart';

/// Pulls the bare token out of a scanned string the same way
/// `Order::normalizeScannedToken` does server-side (trim, then drop a
/// leading "NXP:" QR-payload prefix if present) — shared by both capture
/// paths that decode a parcel code (this screen's live scan, and
/// AssignedDeliveryDetailScreen's "attach a picture" fallback) so a code
/// compares the same way no matter which one produced it.
String normalizeScannedToken(String scanned) {
  final trimmed = scanned.trim();
  const prefix = 'NXP:';
  final idx = trimmed.indexOf(prefix);
  return idx == -1 ? trimmed : trimmed.substring(idx + prefix.length);
}

/// What a completed scan hands back to [AssignedDeliveryDetailScreen]: the
/// decoded QR payload plus a snapshot of the exact camera frame it was read
/// from. The frame doubles as the required pickup/delivery proof photo, so
/// the rider never has to scan the code and then separately photograph the
/// parcel — one scan satisfies both.
class QrScanResult {
  final String rawValue;
  final Uint8List photoBytes;
  const QrScanResult({required this.rawValue, required this.photoBytes});
}

enum _ScanFeedback { none, wrongParcel, unreadable }

/// Full-screen live QR scanner for the parcel confirmation code printed on
/// Prepare Orders (see ParcelQrCode.vue / Order::confirmationQrPayload on
/// the Laravel side — a plain "NXP:<token>" string). Pops with a
/// [QrScanResult] the instant *this parcel's* code is read, or `null` if
/// the rider backs out without scanning anything.
///
/// Camera configuration, in order of how much each one actually matters
/// for real-world scan reliability:
///
/// 1. [MobileScannerController.cameraResolution] is set explicitly to
///    1280x720. Left unset, the underlying CameraX `ImageAnalysis` stream
///    defaults to roughly 480x640 — the mobile_scanner plugin's own
///    Android source literally comments that this "is too low for ML
///    Kit". At that resolution a code has to be large, flat-on, and
///    dead-centre to carry enough resolvable pixels per module; anything
///    less — a slight rotation, a moderate viewing angle, a bit more
///    distance, or dimmer light — and there just isn't enough raw detail
///    left to decode. Requesting 720p is the change that does the most
///    for every scenario this screen needs to handle, while staying
///    small enough that the detected frame — captured losslessly as PNG
///    by the plugin's native side, since [returnImage] doubles it as the
///    pickup/delivery proof photo — comfortably clears the backend's
///    upload size limit (see DriverDeliveryController::pickup/deliver).
///    1080p decodes just as reliably but produces a noticeably larger
///    PNG for the same reason.
/// 2. [MobileScannerController.detectionSpeed] is [DetectionSpeed.normal],
///    which throttles analysis to one frame roughly every
///    [MobileScannerController.detectionTimeoutMs] instead of every single
///    camera frame. [DetectionSpeed.noDuplicates] disables that throttle
///    entirely (it forces the timeout to 0), which — combined with
///    [returnImage] PNG-encoding each analyzed frame — pegged the camera
///    pipeline and made the preview visibly lag. 250ms between analyses is
///    still fast enough that scanning feels instant, but leaves the UI
///    thread room to breathe.
/// 3. No `scanWindow` is set on [MobileScanner] below, so ML Kit gets the
///    full camera frame to search, not a cropped region — the visual
///    guide frame in [build] is just that, a visual guide; it doesn't
///    constrain what the decoder actually reads. A code held anywhere in
///    view, of any size, still gets detected.
/// 4. Autofocus is left to the platform default (continuous AF on both
///    Android's CameraX pipeline and iOS's AVCaptureDevice
///    `.continuousAutoFocus`, per mobile_scanner's own platform code) —
///    there's no plugin API to override this further without vendoring
///    the plugin, and the default is already the right behaviour for a
///    handheld scanner where distance keeps changing.
///
/// Validation against *this* parcel's code (see [expectedToken]) happens
/// right here, per detected frame, rather than after this screen has
/// already closed: a code that decodes fine but belongs to a different
/// parcel shows a brief inline correction and keeps the camera running,
/// instead of kicking the rider back to the details screen just to show
/// them an error toast and make them reopen the scanner.
class QrScanScreen extends StatefulWidget {
  final String title;

  /// The bare, already-normalized token this parcel's own QR should
  /// decode to (see `AssignedDelivery.confirmationToken`). Required：this
  /// screen is only ever pushed for an order that has one (see
  /// `AssignedDeliveryDetailScreen._qrProofSection`).
  final String expectedToken;

  const QrScanScreen({super.key, this.title = 'Scan parcel QR code', required this.expectedToken});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 250,
    cameraResolution: const Size(1280, 720),
    returnImage: true,
  );

  // Guards against the detector firing again (a duplicate frame, or one
  // that arrives after a decode already popped this screen) before the
  // Navigator has actually finished popping.
  bool _handled = false;

  _ScanFeedback _feedback = _ScanFeedback.none;
  bool _success = false;
  Timer? _feedbackTimer;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) return;

    // A moving hand or an angled shot can briefly put more than one code
    // in frame (a neighbouring parcel's label, say) — check all of them
    // for *this* parcel's token rather than only ever looking at
    // capture.barcodes.first, so the right code still wins even when it
    // isn't the one ML Kit happened to list first.
    String? matchedRaw;
    String? firstDecodable;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      firstDecodable ??= raw;
      if (normalizeScannedToken(raw) == widget.expectedToken) {
        matchedRaw = raw;
        break;
      }
    }

    if (matchedRaw == null) {
      // Something decoded, just not the parcel this screen is confirming
      // — a genuine wrong-code scan, not a "detection failed" situation.
      // The camera stays running; this is not a failure the scanner
      // should stop for.
      if (firstDecodable != null) _flashFeedback(_ScanFeedback.wrongParcel);
      return;
    }

    final image = capture.image;
    if (image == null) {
      // The right code decoded but this particular frame carried no
      // photo (shouldn't normally happen with returnImage on) — wait for
      // the next matching detection rather than accept a scan with
      // nothing to submit as proof.
      return;
    }

    _handled = true;
    _feedbackTimer?.cancel();
    HapticFeedback.mediumImpact();
    setState(() {
      _success = true;
      _feedback = _ScanFeedback.none;
    });

    // A short beat so the success state is actually visible before this
    // screen closes — popping the instant a frame decodes reads as no
    // feedback at all, which is exactly what this screen is meant to fix.
    Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      Navigator.of(context).pop(QrScanResult(rawValue: matchedRaw!, photoBytes: image));
    });
  }

  void _flashFeedback(_ScanFeedback feedback) {
    HapticFeedback.selectionClick();
    _feedbackTimer?.cancel();
    setState(() => _feedback = feedback);
    // Self-clears rather than sticking until the next detection — a
    // temporary miss (or a wrong code passing briefly through frame)
    // shouldn't leave a stale warning up once the right code is in view.
    _feedbackTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _feedback = _ScanFeedback.none);
    });
  }

  Color get _frameColor {
    if (_success) return DriverColors.success;
    switch (_feedback) {
      case _ScanFeedback.wrongParcel:
      case _ScanFeedback.unreadable:
        return DriverColors.warning;
      case _ScanFeedback.none:
        return DriverColors.primaryLight;
    }
  }

  String get _caption {
    if (_success) return 'Parcel confirmed!';
    switch (_feedback) {
      case _ScanFeedback.wrongParcel:
        return "That's a different parcel's code — scan the one for this delivery.";
      case _ScanFeedback.unreadable:
        return "Couldn't read that code clearly. Keep it in view — no need to line it up perfectly.";
      case _ScanFeedback.none:
        return 'Position the QR code within the camera view.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final unavailable = state.torchState == TorchState.unavailable;
              final on = state.torchState == TorchState.on;
              return IconButton(
                onPressed: unavailable ? null : () => _controller.toggleTorch(),
                icon: Icon(on ? Icons.flash_on_rounded : Icons.flash_off_rounded),
                tooltip: on ? 'Turn off flashlight' : 'Turn on flashlight (helps in low light)',
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => _PermissionError(onBack: () => Navigator.of(context).pop()),
          ),
          // A dimmed cutout frames roughly where to hold the code — purely
          // visual guidance (its color reflects detection state), it
          // doesn't constrain what the detector actually reads: ML Kit
          // gets the full camera frame every time, not just this box.
          IgnorePointer(
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: _frameColor, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _success
                    ? Center(
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.elasticOut,
                          scale: 1,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(color: DriverColors.success, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _caption,
                key: ValueKey(_caption),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _feedback == _ScanFeedback.none && !_success ? Colors.white.withOpacity(0.9) : _frameColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionError extends StatelessWidget {
  final VoidCallback onBack;
  const _PermissionError({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_rounded, color: Colors.white70, size: 40),
          const SizedBox(height: 14),
          const Text(
            "Couldn't access the camera. Please allow camera access for this app in your device settings, then try again.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }
}
