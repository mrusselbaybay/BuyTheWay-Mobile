import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../driver_models.dart';
import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';

/// Pickup step of the delivery lifecycle: arrive at the seller, verify the
/// order, attach a photo of the parcel, then confirm pickup — the confirm
/// button is disabled until a photo is attached.
///
/// [delivery] is the same mutable object the shell owns — its callbacks
/// mutate it in place, so this widget re-reads `widget.delivery` after
/// calling them rather than needing a copy passed back.
class PickupOrderScreen extends StatefulWidget {
  final ActiveDelivery delivery;
  final VoidCallback onArrived;
  final VoidCallback onPhotoAttached;
  final VoidCallback onConfirmPickup;

  const PickupOrderScreen({
    super.key,
    required this.delivery,
    required this.onArrived,
    required this.onPhotoAttached,
    required this.onConfirmPickup,
  });

  @override
  State<PickupOrderScreen> createState() => _PickupOrderScreenState();
}

class _PickupOrderScreenState extends State<PickupOrderScreen> {
  bool get _arrived => widget.delivery.stage == DeliveryStage.atPickup;

  void _handleArrived() {
    widget.onArrived();
    setState(() {});
  }

  Future<void> _attachPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.isNotEmpty) {
        widget.onPhotoAttached();
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the photo picker.')));
      }
    }
  }

  /// Pull-to-refresh. This screen's data is the module's in-memory
  /// delivery object (no per-delivery endpoint behind it yet), so the pull
  /// re-reads it in place — the gesture stays consistent with the rest of
  /// the app and becomes a real fetch the moment an endpoint exists.
  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.delivery.request;
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: DriverColors.textPrimary, title: const Text('Pickup order', style: TextStyle(fontWeight: FontWeight.w800))),
      body: DriverRefreshable(
        onRefresh: _refresh,
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DeliveryStageStepper(stage: widget.delivery.stage),
            const SizedBox(height: 18),
            RouteSchematic(pickupLabel: request.pickupLabel, dropoffLabel: request.dropoffLabel, distanceKm: request.distanceKm, etaMinutes: request.etaMinutes),
            const SizedBox(height: 16),
            _sectionCard(
              icon: Icons.storefront_rounded,
              title: 'Seller',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.pickupLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(request.pickupAddress, style: DriverText.caption),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _contactStub(context, 'Calling'),
                          icon: const Icon(Icons.call_outlined, size: 16),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(foregroundColor: DriverColors.primaryDark, side: BorderSide(color: DriverColors.primary.withOpacity(0.3))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _contactStub(context, 'Opening chat with'),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                          label: const Text('Chat'),
                          style: OutlinedButton.styleFrom(foregroundColor: DriverColors.primaryDark, side: BorderSide(color: DriverColors.primary.withOpacity(0.3))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_arrived)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleArrived,
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('Arrived at seller'),
                  style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              )
            else ...[
              _sectionCard(
                icon: Icons.receipt_long_rounded,
                title: 'Order verification',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Order ID', '#${request.id.toUpperCase()}'),
                    _infoRow('Parcels', '${request.parcels}'),
                    _infoRow('Weight', '${request.weightKg} kg'),
                    if (request.specialInstructions != null) _infoRow('Notes', request.specialInstructions!),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _attachPhoto,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: widget.delivery.pickupPhotoAttached ? DriverColors.successSurface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: widget.delivery.pickupPhotoAttached ? DriverColors.success : DriverColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(widget.delivery.pickupPhotoAttached ? Icons.check_circle_rounded : Icons.camera_alt_outlined, color: widget.delivery.pickupPhotoAttached ? DriverColors.success : DriverColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.delivery.pickupPhotoAttached ? 'Photo attached' : 'Attach photo of items (required)',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Disabled — not just validated on tap — until a photo is
              // attached, so the driver can't confirm pickup without proof.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.delivery.pickupPhotoAttached ? widget.onConfirmPickup : null,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Confirm pickup'),
                  style: DriverButtonStyle.primary(DriverColors.primary),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  void _contactStub(BuildContext context, String verb) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$verb ${widget.delivery.request.customerName}...'), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _sectionCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 17, color: DriverColors.primary), const SizedBox(width: 8), Text(title, style: DriverText.sectionTitle)]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: DriverText.caption),
          const Spacer(),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: DriverColors.textPrimary), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
