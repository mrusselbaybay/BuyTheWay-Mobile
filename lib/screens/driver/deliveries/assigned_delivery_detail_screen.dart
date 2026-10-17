import 'dart:typed_data';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/api_service.dart';
import '../../../services/remittance_api_service.dart';
import '../../remittances/remittances_screen.dart';
import '../chat/driver_chat_controller.dart';
import '../chat/driver_delivery_message_screen.dart';
import '../driver_models.dart';
import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';
import 'qr_scan_screen.dart';
import 'failed_attempt_sheet.dart';

/// Pushed when the driver taps an assigned delivery — shows the full
/// details and, depending on status, the one rider-initiated action this
/// screen offers: confirm the parcel's QR code, then mark it picked up
/// (status == assigned) or delivered (status == pickedUp). Neither "Mark
/// as..." button is tappable until that confirmation exists — the driver
/// must prove the actual parcel (not just any snapshot) is in front of
/// them before either step will go through.
///
/// The confirmation is the parcel's printed QR code (see ParcelQrCode.vue /
/// Order::confirmationQrPayload on the Laravel side), captured one of two
/// ways — matching the parcel's own `confirmation_token` before either is
/// accepted (see [_applyScannedProof]):
///   - live-scanned with the camera ([_scanQr], via [QrScanScreen]) — the
///     frame the code was read from doubles as the required proof photo;
///   - or a still picture of the code, taken with the camera or chosen
///     from the gallery ([_attachPicture]), decoded locally with
///     [MobileScannerController.analyzeImage].
/// An order dispatched before `confirmation_token` existed
/// ([AssignedDelivery.hasConfirmationQr] false) has no code to scan, so
/// this falls back to the original "attach any photo of the parcel" flow
/// ([_legacyPhotoAttachTile]) rather than demanding one that was never
/// printed. Wired to the real `POST /api/driver/deliveries/{id}/pickup`
/// and `.../deliver` endpoints, which log the scanned token as an extra
/// audit trail alongside the required photo (see
/// DriverDeliveryController::guardScannedToken).
///
/// The "Mark as..." button lives in a bar pinned to the bottom of the
/// screen (outside the scrollable body) rather than at the end of the
/// scroll content — it's the one action this whole screen exists for, so
/// it stays reachable without scrolling no matter how long the rest of the
/// details run.
///
/// [delivery] is the same mutable object DriverShell's list holds — a
/// successful pickup or delivery updates it in place (see
/// [AssignedDelivery.applyFrom]) so the Deliveries list reflects the new
/// status the moment this screen is popped, without a full re-fetch.
class AssignedDeliveryDetailScreen extends StatefulWidget {
  final AssignedDelivery delivery;
  final String accessToken;
  final DriverChatController controller;

  const AssignedDeliveryDetailScreen({super.key, required this.delivery, required this.accessToken, required this.controller});

  @override
  State<AssignedDeliveryDetailScreen> createState() => _AssignedDeliveryDetailScreenState();
}

class _AssignedDeliveryDetailScreenState extends State<AssignedDeliveryDetailScreen> with WidgetsBindingObserver {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleEligibilityRefresh();
  }

  void _scheduleEligibilityRefresh() {
    _midnightTimer?.cancel();
    final attempt = widget.delivery.deliveryAttempt;
    final retryAt = attempt.retryAt;
    if (widget.delivery.status != AssignedDeliveryStatus.failedAttempt || retryAt == null || attempt.eligible) return;
    final wait = retryAt.difference(DateTime.now().toUtc());
    if (wait.isNegative) return;
    _midnightTimer = Timer(wait + const Duration(seconds: 1), _refresh);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_submitting) _refresh();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _failAttempt() async {
    final reason = await showModalBottomSheet<(String, String?)>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (_) => const FailedAttemptSheet(),
    );
    if (reason == null || !mounted || _submitting) return;
    final source = await _pickImageSource();
    if (source == null || !mounted) return;
    XFile? proof;
    try {
      proof = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    } catch (_) {
      _showProofError('Could not capture proof. Please try again.');
      return;
    }
    if (proof == null || !mounted) return;
    final bytes = await proof.readAsBytes();
    if (!mounted) return;
    await _submitAttemptAction(() => _api.markDeliveryFailed(
      parcelAssignmentId: widget.delivery.id, accessToken: widget.accessToken,
      reasonCode: reason.$1, description: reason.$2, photoBytes: bytes, photoFileName: proof!.name,
    ), 'Failed delivery attempt recorded.');
  }

  Future<void> _reattempt() => _submitAttemptAction(() => _api.startDeliveryReattempt(
    parcelAssignmentId: widget.delivery.id, accessToken: widget.accessToken,
  ), 'Delivery re-attempt started.');

  Future<void> _submitAttemptAction(Future<Map<String, dynamic>> Function() action, String message) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final response = await action();
      final data = response['data'];
      if (data is! Map) throw ApiException(message: 'Invalid delivery response. Refresh and try again.', statusCode: 500);
      if (!mounted) return;
      setState(() {
        widget.delivery.applyFrom(AssignedDelivery.fromApi(Map<String, dynamic>.from(data)));
        _photoBytes = null;
        _photoFilePath = null;
        _photoFileName = null;
        _scannedToken = null;
      });
      _scheduleEligibilityRefresh();
      DriverTopNotification.show(context, message: message);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update this delivery. Check your connection and refresh before retrying.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  final ApiService _api = ApiService();

  String? _photoFileName;
  Uint8List? _photoBytes;
  String? _photoFilePath;
  bool _submitting = false;
  bool _openingPhoto = false;

  /// Set only once a scanned/decoded QR value has been checked against
  /// this delivery's [AssignedDelivery.confirmationToken] (see
  /// [_applyScannedProof]) — null for the legacy "any photo" fallback,
  /// where there's no code to check against.
  String? _scannedToken;

  /// True while picking + decoding an attached picture ([_attachPicture])
  /// — disables both capture buttons so a second tap can't race the first.
  bool _capturing = false;

  bool get _hasPhoto => _photoBytes != null || _photoFilePath != null;

  /// Legacy path only: attaches any photo of the parcel with no QR
  /// decode/verification — used when this order predates
  /// `confirmation_token` (see [AssignedDelivery.hasConfirmationQr]).
  Future<void> _pickLegacyPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: kIsWeb);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.single;
      setState(() {
        _photoFileName = f.name;
        _photoBytes = kIsWeb ? f.bytes : null;
        _photoFilePath = kIsWeb ? null : f.path;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the photo picker. Please try again.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  /// Pushes the live scanner ([QrScanScreen]) and, on a successful read,
  /// runs the decoded value through the same [_applyScannedProof] check an
  /// attached picture goes through — the camera frame the code was read
  /// from doubles as the proof photo (see [QrScanResult]'s docblock).
  ///
  /// Guarded the same way [_attachPicture] already is: mobile_scanner's
  /// web implementation (Flutter Web, e.g. `flutter run -d chrome`) never
  /// attaches an image to a detection — `returnImage` has no effect there
  /// at all, only on Android/iOS — so a scan that matches would otherwise
  /// wait forever for a proof photo that can never arrive. Rather than let
  /// that read as "the scanner just doesn't work," this is refused up
  /// front with the same explanation the picture-attach path already
  /// gives on web.
  Future<void> _scanQr() async {
    if (kIsWeb) {
      _showProofError("Scanning isn't supported in this preview. Please use the mobile app.");
      return;
    }

    final expectedToken = widget.delivery.confirmationToken;
    if (expectedToken == null) {
      _showProofError("This parcel doesn't have a QR code on file.");
      return;
    }

    final isPickup = widget.delivery.status == AssignedDeliveryStatus.assigned ||
        widget.delivery.status == AssignedDeliveryStatus.transferAssigned;
    final isTransfer = widget.delivery.status == AssignedDeliveryStatus.readyToTransfer;
    final scanTitle = isPickup
        ? 'Scan to confirm pickup'
        : (isTransfer ? 'Scan to confirm transfer' : 'Scan to confirm delivery');
    final result = await Navigator.of(context).push<QrScanResult>(
      MaterialPageRoute(
        builder: (_) => QrScanScreen(
          title: scanTitle,
          expectedToken: expectedToken,
        ),
      ),
    );
    if (result == null || !mounted) return;
    _applyScannedProof(rawValue: result.rawValue, photoBytes: result.photoBytes, photoFilePath: null, fileNameHint: 'qr-scan');
  }

  /// Lets the driver choose Camera or Gallery, then decodes any QR code
  /// found in the resulting still with [MobileScannerController.analyzeImage]
  /// — a plain still photo (no live camera feed) is all that's needed, so a
  /// short-lived controller is created just for the decode and disposed
  /// right after. Only supported on Android/iOS; not available on web.
  Future<void> _attachPicture() async {
    final source = await _pickImageSource();
    if (source == null || !mounted) return;

    setState(() => _capturing = true);
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 90);
      if (file == null) {
        setState(() => _capturing = false);
        return;
      }

      if (kIsWeb) {
        setState(() => _capturing = false);
        _showProofError("Attaching a QR picture isn't supported in this preview. Please use the mobile app.");
        return;
      }

      final scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
      BarcodeCapture? capture;
      try {
        capture = await scanner.analyzeImage(file.path);
      } finally {
        scanner.dispose();
      }

      final raw = (capture?.barcodes.isNotEmpty ?? false) ? capture!.barcodes.first.rawValue : null;
      if (!mounted) return;
      if (raw == null || raw.trim().isEmpty) {
        setState(() => _capturing = false);
        _showProofError("No QR code found in that photo. Please retake a clear photo of the parcel's QR code.");
        return;
      }

      setState(() => _capturing = false);
      _applyScannedProof(rawValue: raw, photoBytes: null, photoFilePath: file.path, fileNameHint: 'qr-photo');
    } catch (_) {
      if (!mounted) return;
      setState(() => _capturing = false);
      _showProofError('Could not read that photo. Please try again.');
    }
  }

  /// Bottom sheet offering Camera vs Gallery for [_attachPicture] — returns
  /// null if the driver dismisses it without choosing either.
  Future<ImageSource?> _pickImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Align(alignment: Alignment.centerLeft, child: Text('Attach a picture of the QR code', style: DriverText.sectionTitle)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Make sure the parcel's QR code is clear and in frame.", style: DriverText.caption),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: DriverColors.primary),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: DriverColors.primary),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Common landing point for both capture paths: normalizes the scanned
  /// value the same way `Order::normalizeScannedToken` does server-side
  /// (trim, then drop a leading "NXP:" if present), checks it against this
  /// delivery's own code when one exists, and only then accepts the photo
  /// as this screen's proof. A mismatch or unreadable value leaves the
  /// proof tile empty so the "Mark as..." button stays disabled.
  void _applyScannedProof({
    required String rawValue,
    Uint8List? photoBytes,
    String? photoFilePath,
    required String fileNameHint,
  }) {
    final token = normalizeScannedToken(rawValue);
    if (token.isEmpty) {
      _showProofError('That code could not be read. Please try again.');
      return;
    }

    if (widget.delivery.hasConfirmationQr && widget.delivery.confirmationToken != token) {
      _showProofError("This QR code doesn't belong to this parcel. Make sure you're scanning the right package.");
      return;
    }

    setState(() {
      _photoBytes = photoBytes;
      _photoFilePath = photoFilePath;
      _photoFileName = '$fileNameHint-${DateTime.now().millisecondsSinceEpoch}.jpg';
      _scannedToken = token;
    });
  }

  void _showProofError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: DriverColors.error),
    );
  }

  /// Clears the picked-but-not-yet-submitted photo so the driver can
  /// attach a different one — the X badge on the attach tile calls this.
  void _removePhoto() {
    setState(() {
      _photoFileName = null;
      _photoBytes = null;
      _photoFilePath = null;
      _scannedToken = null;
    });
  }

  /// Confirms pickup for an 'assigned' delivery, or the equivalent
  /// "I have it" step for a 'transferAssigned' transfer leg — same
  /// endpoint, same photo/QR proof, just a different resulting status (see
  /// DriverDeliveryController::pickup's docblock). The button that calls
  /// this is disabled until [_hasPhoto] is true (see [_buildActionBar]),
  /// so by the time this runs a photo is already attached.
  Future<void> _confirmPickup() async {
    final wasTransfer = widget.delivery.status == AssignedDeliveryStatus.transferAssigned;
    setState(() => _submitting = true);
    try {
      final response = await _api.markDeliveryPickedUp(
        parcelAssignmentId: widget.delivery.id,
        accessToken: widget.accessToken,
        photoFileName: _photoFileName!,
        photoBytes: _photoBytes,
        photoFilePath: _photoFilePath,
        confirmationToken: _scannedToken,
      );
      final data = response['data'];
      if (data is! Map) {
        throw ApiException(message: 'The server returned an invalid response.', statusCode: 500);
      }

      if (!mounted) return;
      widget.delivery.applyFrom(AssignedDelivery.fromApi(Map<String, dynamic>.from(data)));
      setState(() => _submitting = false);
      DriverTopNotification.show(
        context,
        message: wasTransfer
            ? 'Pickup confirmed — head to ${widget.delivery.dropoffLabel} to complete the transfer.'
            : 'Pickup confirmed — parcel handed back to logistics for delivery.',
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not confirm this pickup. Please try again.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  /// Marks a 'pickedUp' delivery delivered — the button that calls this is
  /// disabled until [_hasPhoto] is true (see [_buildActionBar]), so by the
  /// time this runs a photo is already attached.
  Future<void> _markDelivered() async {
    setState(() => _submitting = true);
    try {
      final response = await _api.markDeliveryDelivered(
        parcelAssignmentId: widget.delivery.id,
        accessToken: widget.accessToken,
        photoFileName: _photoFileName!,
        photoBytes: _photoBytes,
        photoFilePath: _photoFilePath,
        confirmationToken: _scannedToken,
      );
      final data = response['data'];
      if (data is! Map) {
        throw ApiException(message: 'The server returned an invalid response.', statusCode: 500);
      }

      if (!mounted) return;
      widget.delivery.applyFrom(AssignedDelivery.fromApi(Map<String, dynamic>.from(data)));
      setState(() => _submitting = false);
      DriverTopNotification.show(context, message: 'Delivery completed!');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark this delivered. Please try again.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  /// The cross-region-transfer counterpart to [_markDelivered]: confirms
  /// this rider has reached the target company's hub instead of a
  /// buyer's doorstep. Same photo-gated flow, posts to
  /// `/driver/deliveries/{id}/confirm-transfer` instead.
  Future<void> _confirmTransfer() async {
    setState(() => _submitting = true);
    try {
      final response = await _api.confirmParcelTransfer(
        parcelAssignmentId: widget.delivery.id,
        accessToken: widget.accessToken,
        photoFileName: _photoFileName!,
        photoBytes: _photoBytes,
        photoFilePath: _photoFilePath,
        confirmationToken: _scannedToken,
      );
      final data = response['data'];
      if (data is! Map) {
        throw ApiException(message: 'The server returned an invalid response.', statusCode: 500);
      }

      if (!mounted) return;
      widget.delivery.applyFrom(AssignedDelivery.fromApi(Map<String, dynamic>.from(data)));
      setState(() => _submitting = false);
      DriverTopNotification.show(context, message: 'Transfer confirmed!');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not confirm this transfer. Please try again.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _viewDeliveryPhoto() async {
    setState(() => _openingPhoto = true);
    try {
      final response = await _api.getDeliveryPhoto(parcelAssignmentId: widget.delivery.id, accessToken: widget.accessToken);
      final url = response['url'] as String?;
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch delivery photo URL.');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the delivery photo. Please try again.'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _openingPhoto = false);
    }
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    try {
      if (!await launchUrl(Uri(scheme: 'tel', path: phone.trim()))) throw Exception('launch failed');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start a call. Please dial manually.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  bool _navigatingToMessage = false;

  /// The "Message" button on a Buyer/Seller contact row — opens straight
  /// into this rider's direct thread with that contact (a new conversation
  /// type the courier's own inbox now also carries alongside their
  /// employer's 'roster' thread). [contact] is 'buyer' or 'seller'.
  ///
  /// Navigates immediately, before the conversation is even resolved —
  /// [DriverDeliveryMessageScreen] does the actual find-or-create call and
  /// shows a skeleton while it's in flight, rather than this screen
  /// blocking the tap on a network round trip before the user sees
  /// anything happen. `_navigatingToMessage` only guards against a rapid
  /// double-tap pushing the route twice; it's cleared as soon as that
  /// screen is popped, not tied to the network call's own completion.
  void _messageContact(String contact) {
    if (_navigatingToMessage) return;
    setState(() => _navigatingToMessage = true);
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => DriverDeliveryMessageScreen(
            controller: widget.controller,
            parcelAssignmentId: widget.delivery.id,
            contact: contact,
          ),
        ))
        .whenComplete(() {
      if (mounted) setState(() => _navigatingToMessage = false);
    });
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Unknown time';
    final local = d.toUtc().add(const Duration(hours: 8));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year} - $h:$m $period PHT';
  }

  (String, Color, IconData) _actionTag(AssignedDeliveryStatus status) {
    switch (status) {
      case AssignedDeliveryStatus.failedAttempt:
        return ('Failed Attempt', DriverColors.warning, Icons.warning_amber_rounded);
      case AssignedDeliveryStatus.needsDispatcherReview:
        return ('Needs Dispatcher Review', DriverColors.error, Icons.support_agent_rounded);
      case AssignedDeliveryStatus.assigned:
        return ('To pick up', DriverColors.warning, Icons.storefront_rounded);
      case AssignedDeliveryStatus.pickedUp:
        return ('To deliver', DriverColors.info, Icons.local_shipping_rounded);
      case AssignedDeliveryStatus.delivered:
        return ('Delivered', DriverColors.success, Icons.check_circle_rounded);
      case AssignedDeliveryStatus.handedOver:
        return ('Handed over', DriverColors.textSecondary, Icons.assignment_turned_in_rounded);
      case AssignedDeliveryStatus.awaitingInventory:
        return ('Picked up', DriverColors.success, Icons.check_circle_rounded);
      // Cross-region transfer leg — see AssignedDeliveryStatus's docblock.
      // Only reached when dispatch had to hand this leg to a courier who
      // didn't already have the parcel — same "To pick up" framing as a
      // local pickup for that reason. The common case — the same courier
      // who collected it carries it straight on — skips this status
      // entirely and starts at readyToTransfer instead.
      case AssignedDeliveryStatus.transferAssigned:
        return ('To pick up', DriverColors.warning, Icons.storefront_rounded);
      case AssignedDeliveryStatus.readyToTransfer:
        return ('To deliver', DriverColors.info, Icons.compare_arrows_rounded);
      case AssignedDeliveryStatus.transferred:
        return ('Delivered', DriverColors.success, Icons.check_circle_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.delivery;
    final (tagLabel, tagColor, tagIcon) = _actionTag(d.status);

    return Scaffold(
      backgroundColor: DriverColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DriverGradientHeader(
              title: d.customerName,
              subtitle: '#${d.orderNumber}${d.trackingNumber != null ? ' · Tracking ${d.trackingNumber}' : ''}',
              onBack: () => Navigator.of(context).pop(),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DriverStatusBadge(label: tagLabel, color: tagColor, icon: tagIcon),
                  if (d.isReturn) ...[
                    const SizedBox(height: 4),
                    DriverReturnChip(returned: d.isReturned),
                  ],
                ],
              ),
            ),
            if (d.financialFlow == 'manual' && d.paymentMethod == 'cod' && d.status == AssignedDeliveryStatus.delivered && !d.isReturn && !d.isTransfer)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(width: double.infinity, child: FilledButton.icon(
                  icon: const Icon(Icons.currency_exchange_rounded),
                  label: const Text('Remit COD to seller'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RemittancesScreen(accessToken: widget.accessToken, role: RemittanceRole.courier, orderNumber: d.orderNumber))),
                )),
              ),
            Expanded(child: _buildBody(context, d)),
            _buildActionBar(context, d),
          ],
        ),
      ),
    );
  }

  /// Pull-to-refresh: re-reads this rider's deliveries and folds the
  /// matching row back into the shared [AssignedDelivery] instance, so a
  /// status change made elsewhere (dispatch reassigning, the parcel being
  /// handed over) shows up here and on the Deliveries list at once.
  Future<void> _refresh() async {
    try {
      final response = await _api.getDriverDeliveries(accessToken: widget.accessToken);
      final rows = (response['data'] as List? ?? [])
          .map((row) => AssignedDelivery.fromApi(Map<String, dynamic>.from(row as Map)));
      final match = rows.where((row) => row.id == widget.delivery.id).firstOrNull;
      if (!mounted || match == null) return;
      setState(() => widget.delivery.applyFrom(match));
      _scheduleEligibilityRefresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not refresh this delivery. Check your connection.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: DriverColors.error,
        ),
      );
    }
  }

  Widget _buildBody(BuildContext context, AssignedDelivery d) {
    return DriverRefreshable(
      onRefresh: _refresh,
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.deliveryAttempt.reason != null) ...[
            _sectionCard(
              icon: Icons.warning_amber_rounded,
              title: 'Failed attempt ${d.deliveryAttempt.count}',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.deliveryAttempt.reason!, style: DriverText.body),
                if (d.deliveryAttempt.description != null) Text(d.deliveryAttempt.description!, style: DriverText.body),
                Text(_formatDate(d.deliveryAttempt.failedAt), style: DriverText.caption),
                if (d.status == AssignedDeliveryStatus.needsDispatcherReview)
                  Text(d.deliveryAttempt.returnFlaggedAt != null ? 'Flagged for the separate return process. Courier re-attempts are blocked.' : 'Waiting for dispatcher review. You cannot start another attempt yet.', style: DriverText.caption)
                else if (d.status == AssignedDeliveryStatus.failedAttempt)
                  Text('Re-attempt available from ${_formatDate(d.deliveryAttempt.retryAt)}.', style: DriverText.caption),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          DriverDispatchChip(label: d.dispatchedByLabel),
          const SizedBox(height: 16),
          if (d.isReturn) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DriverColors.warningSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.assignment_return_outlined, size: 18, color: DriverColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Return to seller', style: TextStyle(fontWeight: FontWeight.w800, color: DriverColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          'Reason: ${d.returnReason ?? 'Not specified'}',
                          style: DriverText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _sectionCard(
            icon: Icons.contacts_rounded,
            title: 'Contacts',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _contactRow(role: 'Buyer', contact: 'buyer', name: d.customerName, phone: d.customerContactNo),
                const Divider(height: 24),
                _contactRow(role: 'Seller', contact: 'seller', name: d.sellerName ?? 'Not on file', phone: d.sellerContactNo),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            icon: Icons.route_rounded,
            title: 'Route',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.storefront_rounded, size: 15, color: DriverColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(d.returnPickupAddress ?? d.pickupLabel, style: DriverText.body)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.flag_rounded, size: 15, color: DriverColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(d.dropoffLabel, style: DriverText.body)),
                ]),
                if (d.deliveryArea != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.map_outlined, size: 15, color: DriverColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(d.deliveryArea!, style: DriverText.body),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            icon: Icons.inventory_2_outlined,
            title: 'Parcel contents',
            child: _parcelContents(d),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            icon: Icons.schedule_rounded,
            title: 'Timeline',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _timelineRow('Assigned to you', d.assignedAt),
                if (d.handedOffAt != null) _timelineRow('Handed to you', d.handedOffAt),
                if (d.deliveredAt != null) _timelineRow('Delivered', d.deliveredAt),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (d.status == AssignedDeliveryStatus.assigned || d.status == AssignedDeliveryStatus.transferAssigned) ...[
            _sectionCard(
              icon: d.hasConfirmationQr ? Icons.qr_code_scanner_rounded : Icons.camera_alt_outlined,
              title: 'Proof of pickup',
              child: d.hasConfirmationQr
                  ? _qrProofSection("Scan the parcel's QR code, or attach a picture of it, to confirm pickup (required)")
                  : _legacyPhotoAttachTile('Attach a photo of the parcel at pickup (required)'),
            ),
            const SizedBox(height: 8),
            Text(
              d.status == AssignedDeliveryStatus.transferAssigned
                  ? "Scan or attach the parcel's QR code once you have it in hand to confirm pickup and start the transfer run to ${d.dropoffLabel}."
                  : "Waiting to be handed to you at the sorting hub? Scan or attach the parcel's QR code once you have it in hand to confirm pickup yourself.",
              style: DriverText.caption,
            ),
          ] else if (d.status == AssignedDeliveryStatus.pickedUp) ...[
            _sectionCard(
              icon: d.hasConfirmationQr ? Icons.qr_code_scanner_rounded : Icons.camera_alt_outlined,
              title: 'Proof of delivery',
              child: d.hasConfirmationQr
                  ? _qrProofSection("Scan the parcel's QR code, or attach a picture of it, to confirm delivery (required)")
                  : _legacyPhotoAttachTile('Attach a photo of the parcel (required)'),
            ),
          ] else if (d.status == AssignedDeliveryStatus.awaitingInventory) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: DriverColors.primaryDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Picked up ${_formatDate(d.handedOffAt)}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: DriverColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        const Text('Awaiting logistics inventory scan.', style: DriverText.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (d.status == AssignedDeliveryStatus.handedOver) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.assignment_turned_in_rounded, size: 18, color: DriverColors.primaryDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Picked up ${_formatDate(d.handedOffAt)}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: DriverColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Handed back to logistics — a delivery rider will be assigned to complete this drop-off.',
                          style: DriverText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (d.status == AssignedDeliveryStatus.readyToTransfer) ...[
            _sectionCard(
              icon: d.hasConfirmationQr ? Icons.qr_code_scanner_rounded : Icons.camera_alt_outlined,
              title: 'Proof of transfer',
              child: d.hasConfirmationQr
                  ? _qrProofSection("Scan the parcel's QR code, or attach a picture of it, to confirm it reached ${d.dropoffLabel} (required)")
                  : _legacyPhotoAttachTile('Attach a photo of the parcel at ${d.dropoffLabel} (required)'),
            ),
          ] else if (d.status == AssignedDeliveryStatus.transferred) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: DriverColors.successSurface, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: DriverColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Delivered ${_formatDate(d.transferredAt)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: DriverColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: DriverColors.successSurface, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: DriverColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Delivered ${_formatDate(d.deliveredAt)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: DriverColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            if (d.hasDeliveryPhoto) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openingPhoto ? null : _viewDeliveryPhoto,
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: Text(_openingPhoto ? 'Opening…' : 'View delivery photo'),
                  style: OutlinedButton.styleFrom(foregroundColor: DriverColors.primaryDark, side: BorderSide(color: DriverColors.primary.withOpacity(0.4))),
                ),
              ),
            ],
          ],
        ],
      ),
      ),
    );
  }

  /// Legacy path only (see [AssignedDelivery.hasConfirmationQr]) — attaches
  /// any photo of the parcel with no QR decode/verification, exactly as
  /// this screen worked before the QR-gated flow existed. Once a photo is
  /// picked, a small X badge appears on the tile's top-right edge so the
  /// driver can clear it and pick a different one.
  Widget _legacyPhotoAttachTile(String requiredHint) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: _submitting ? null : _pickLegacyPhoto,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _hasPhoto ? DriverColors.successSurface : DriverColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _hasPhoto ? DriverColors.success : DriverColors.border),
            ),
            child: Row(
              children: [
                Icon(_hasPhoto ? Icons.check_circle_rounded : Icons.add_a_photo_outlined, color: _hasPhoto ? DriverColors.success : DriverColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _hasPhoto ? (_photoFileName ?? 'Photo attached') : requiredHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_hasPhoto && !_submitting) _removeBadge(),
      ],
    );
  }

  /// The QR-gated proof control (see this screen's class docblock) — two
  /// capture buttons, "Scan QR code" and "Attach a picture", until a valid
  /// proof exists, then the same confirmed tile the legacy path uses.
  Widget _qrProofSection(String requiredHint) {
    if (_hasPhoto) {
      return _proofConfirmedTile(confirmedLabel: 'QR code confirmed');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _capturing || _submitting ? null : _scanQr,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Scan QR code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DriverColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _capturing || _submitting ? null : _attachPicture,
                icon: const Icon(Icons.photo_camera_back_outlined, size: 18),
                label: const Text('Attach a picture'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DriverColors.primaryDark,
                  side: BorderSide(color: DriverColors.primary.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_capturing)
          const Row(
            children: [
              SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('Reading the QR code…', style: DriverText.caption),
            ],
          )
        else
          Text(requiredHint, style: DriverText.caption),
      ],
    );
  }

  /// The confirmed-proof tile shared by both capture paths once
  /// [_hasPhoto] is true — [confirmedLabel] reads "QR code confirmed" when
  /// a scan/decode produced this proof, or the legacy path's file name
  /// otherwise.
  Widget _proofConfirmedTile({required String confirmedLabel}) {
    final label = _scannedToken != null ? confirmedLabel : (_photoFileName ?? 'Photo attached');
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DriverColors.successSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DriverColors.success),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: DriverColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        if (!_submitting) _removeBadge(),
      ],
    );
  }

  /// The small X badge on the top-right edge of a confirmed proof tile —
  /// shared by both the legacy and QR-gated tiles.
  Widget _removeBadge() {
    return Positioned(
      top: -8,
      right: -8,
      child: GestureDetector(
        onTap: _removePhoto,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DriverColors.error,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
        ),
      ),
    );
  }

  /// The "Mark as..." action, pinned to the bottom of the screen so it's
  /// always visible without scrolling — nothing renders here once the
  /// delivery is already marked delivered, since there's no further action
  /// to take.
  Widget _buildActionBar(BuildContext context, AssignedDelivery d) {
    if (d.status == AssignedDeliveryStatus.failedAttempt || d.status == AssignedDeliveryStatus.needsDispatcherReview) {
      final allowed = d.status == AssignedDeliveryStatus.failedAttempt && d.deliveryAttempt.eligible;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!allowed) Text(d.deliveryAttempt.needsReview
                ? 'Dispatcher approval required'
                : 'Available from ${_formatDate(d.deliveryAttempt.retryAt)}. Pull down to refresh.', style: DriverText.caption),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: allowed && !_submitting ? _reattempt : null,
              icon: Icon(allowed ? Icons.replay_rounded : Icons.lock_rounded),
              label: Text(_submitting ? 'Submitting...' : 'Re-attempt Delivery'),
              style: DriverButtonStyle.primary(DriverColors.primary),
            )),
          ]),
        ),
      );
    }
    // Nothing to do from here once it's delivered/transferred, or once this
    // rider has handed it back to logistics (a different rider delivers
    // it) — every other status has a rider-facing action.
    if (d.status == AssignedDeliveryStatus.delivered ||
        d.status == AssignedDeliveryStatus.handedOver ||
        d.status == AssignedDeliveryStatus.transferred) {
      return const SizedBox.shrink();
    }
    // Already picked up — show the action locked so it can't be resubmitted.
    if (d.status == AssignedDeliveryStatus.awaitingInventory) {
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4))],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.lock_rounded),
              label: const Text('Picked up'),
              style: DriverButtonStyle.primary(DriverColors.success),
            ),
          ),
        ),
      );
    }
    final isTransfer = d.status == AssignedDeliveryStatus.readyToTransfer;
    final isPickup = d.status == AssignedDeliveryStatus.assigned || d.status == AssignedDeliveryStatus.transferAssigned;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (d.canMarkFailed)
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _submitting || _capturing ? null : _failAttempt,
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('Failed Attempt'),
                style: OutlinedButton.styleFrom(foregroundColor: DriverColors.warning, minimumSize: const Size.fromHeight(48)),
              )),
            if (d.canMarkFailed) const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_hasPhoto && !_submitting)
                    ? (isPickup ? _confirmPickup : (isTransfer ? _confirmTransfer : _markDelivered))
                    : null,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Icon(Icons.task_alt_rounded),
                label: Text(_submitting
                    ? 'Submitting…'
                    : (isPickup ? 'Mark as picked up' : (isTransfer ? 'Confirm transfer' : 'Mark as delivered'))),
                style: DriverButtonStyle.primary(isPickup ? DriverColors.primary : DriverColors.success),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One row of the "Contacts" card — a role label ("Buyer"/"Seller"),
  /// name, and phone number, with a Message button (left) and a call
  /// button (right, when a number is on file). [name] is a plain string
  /// rather than nullable so a missing seller (an order predating some
  /// data migration, say) reads as "Not on file" instead of silently
  /// rendering nothing. [contact] is 'buyer'/'seller' — passed straight
  /// through to [DriverChatController.startDeliveryConversation].
  Widget _contactRow({required String role, required String contact, required String name, String? phone}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: DriverText.label),
              const SizedBox(height: 2),
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: DriverColors.textPrimary)),
              if (phone != null) ...[
                const SizedBox(height: 2),
                Text(phone, style: DriverText.caption),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        DriverMessageFab(onTap: () => _messageContact(contact), size: 36),
        if (phone != null) ...[
          const SizedBox(width: 10),
          DriverCallFab(onTap: () => _call(phone), size: 36),
        ],
      ],
    );
  }

  Widget _timelineRow(String label, DateTime? at) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: DriverColors.textSecondary, fontWeight: FontWeight.w500))),
          Text(_formatDate(at), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: DriverColors.textPrimary)),
        ],
      ),
    );
  }

  /// The "Parcel contents" card body — the shop name once at the top, then
  /// one row per line item (name, variant/SKU, size + weight, quantity),
  /// mirroring the web seller's order-details item list. Falls back to the
  /// plain parcel count for an order with no items on file.
  Widget _parcelContents(AssignedDelivery d) {
    final shop = d.sellerShopName ?? d.sellerName;
    if (d.items.isEmpty) {
      return Text('${d.parcels} parcel${d.parcels == 1 ? '' : 's'}', style: DriverText.body);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shop != null && shop.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 13, color: DriverColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text(shop, style: DriverText.label)),
            ],
          ),
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < d.items.length; i++) ...[
          if (i > 0) const Divider(height: 20),
          _productRow(d.items[i]),
        ],
        const SizedBox(height: 10),
        Text(
          '${d.parcels} item${d.parcels == 1 ? '' : 's'} total',
          style: DriverText.caption,
        ),
      ],
    );
  }

  Widget _productRow(AssignedDeliveryItem item) {
    final meta = <String>[
      if (item.variant != null) item.variant!,
      if (item.sku != null && item.sku != item.variant) 'SKU ${item.sku}',
    ].join(' · ');
    final specs = <String>[
      if (item.dimensionsLabel != null) item.dimensionsLabel!,
      if (item.weightLabel != null) item.weightLabel!,
    ].join('  ·  ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: DriverColors.textPrimary),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(meta, style: DriverText.caption),
              ],
              if (specs.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.straighten_rounded, size: 12, color: DriverColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(specs, style: DriverText.caption),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(8)),
          child: Text(
            '×${item.quantity}',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: DriverColors.primaryDark),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 15, color: DriverColors.primaryDark),
            ),
            const SizedBox(width: 10),
            Text(title, style: DriverText.sectionTitle),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
