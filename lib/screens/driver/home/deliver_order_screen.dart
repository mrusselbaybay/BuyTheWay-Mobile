import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../driver_models.dart';
import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';

/// Dropoff step of the delivery lifecycle: travel to the customer, arrive,
/// then capture proof of delivery (photo + optional notes) and complete —
/// the complete button is disabled until a photo is attached.
class DeliverOrderScreen extends StatefulWidget {
  final ActiveDelivery delivery;
  final VoidCallback onArrived;
  final VoidCallback onPhotoAttached;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onMarkDelivered;

  const DeliverOrderScreen({
    super.key,
    required this.delivery,
    required this.onArrived,
    required this.onPhotoAttached,
    required this.onNotesChanged,
    required this.onMarkDelivered,
  });

  @override
  State<DeliverOrderScreen> createState() => _DeliverOrderScreenState();
}

class _DeliverOrderScreenState extends State<DeliverOrderScreen> {
  late final TextEditingController _notesController = TextEditingController(text: widget.delivery.deliveryNotes);

  bool get _arrived => widget.delivery.stage == DeliveryStage.atDropoff;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

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
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: DriverColors.textPrimary, title: const Text('Deliver order', style: TextStyle(fontWeight: FontWeight.w800))),
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
              icon: Icons.person_rounded,
              title: 'Customer',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(request.dropoffAddress, style: DriverText.caption),
                  const SizedBox(height: 4),
                  Text(_arrived ? 'You have arrived' : 'ETA ${request.etaMinutes} min', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: DriverColors.primaryDark)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _contactStub('Calling'),
                          icon: const Icon(Icons.call_outlined, size: 16),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(foregroundColor: DriverColors.primaryDark, side: BorderSide(color: DriverColors.primary.withOpacity(0.3))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _contactStub('Opening chat with'),
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
                  label: const Text('Arrived at customer'),
                  style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              )
            else ...[
              _sectionCard(
                icon: Icons.camera_alt_outlined,
                title: 'Proof of delivery',
                child: InkWell(
                  onTap: _attachPhoto,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: widget.delivery.deliveryPhotoAttached ? DriverColors.successSurface : DriverColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: widget.delivery.deliveryPhotoAttached ? DriverColors.success : DriverColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(widget.delivery.deliveryPhotoAttached ? Icons.check_circle_rounded : Icons.add_a_photo_outlined, color: widget.delivery.deliveryPhotoAttached ? DriverColors.success : DriverColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.delivery.deliveryPhotoAttached ? 'Delivery photo attached' : 'Attach delivery photo (required)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.edit_note_rounded,
                title: 'Delivery notes (optional)',
                child: TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: widget.onNotesChanged,
                  decoration: InputDecoration(
                    hintText: 'e.g. Left with the receptionist.',
                    filled: true,
                    fillColor: DriverColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Disabled — not just validated on tap — until a photo is
              // attached, so the driver can't complete delivery without
              // proof.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.delivery.deliveryPhotoAttached ? widget.onMarkDelivered : null,
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text('Mark as delivered'),
                  style: DriverButtonStyle.primary(DriverColors.success),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  void _contactStub(String verb) {
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
}
