import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../driver_models.dart';
import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';

/// Full details for one available request, with a 30-second acceptance
/// window (first-come-first-served). Pops `true` on accept, `false` if the
/// driver declines or the timer runs out, `null` if they just navigate
/// back without deciding.
class DeliveryRequestDetailsScreen extends StatefulWidget {
  final DeliveryRequest request;
  const DeliveryRequestDetailsScreen({super.key, required this.request});

  @override
  State<DeliveryRequestDetailsScreen> createState() => _DeliveryRequestDetailsScreenState();
}

class _DeliveryRequestDetailsScreenState extends State<DeliveryRequestDetailsScreen> {
  static const _totalSeconds = 30;
  int _secondsLeft = _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        Navigator.of(context).pop(false);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _accept() {
    HapticFeedback.heavyImpact();
    _timer?.cancel();
    Navigator.of(context).pop(true);
  }

  void _decline() {
    _timer?.cancel();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: DriverColors.textPrimary,
        title: const Text('Delivery request', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [Padding(padding: const EdgeInsets.only(right: 14), child: Center(child: CountdownRing(progress: _secondsLeft / _totalSeconds, secondsLeft: _secondsLeft)))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RouteSchematic(pickupLabel: request.pickupLabel, dropoffLabel: request.dropoffLabel, distanceKm: request.distanceKm, etaMinutes: request.etaMinutes),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: DriverColors.primarySurface, shape: BoxShape.circle),
                        child: const Icon(Icons.person_rounded, color: DriverColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(request.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: DriverColors.textPrimary))),
                      Text('₱${request.estimatedFare.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: DriverColors.primaryDark)),
                    ],
                  ),
                  const Divider(height: 24),
                  _addressRow(Icons.storefront_rounded, 'Pickup', request.pickupLabel, request.pickupAddress),
                  const SizedBox(height: 12),
                  _addressRow(Icons.flag_rounded, 'Drop-off', request.dropoffLabel, request.dropoffAddress),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.inventory_2_outlined, size: 17, color: DriverColors.primary), SizedBox(width: 8), Text('Item details', style: DriverText.sectionTitle)]),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      DriverStatusBadge(label: '${request.parcels} parcel${request.parcels == 1 ? '' : 's'}', color: DriverColors.info, icon: Icons.inventory_2_rounded),
                      DriverStatusBadge(label: '${request.weightKg} kg', color: DriverColors.info, icon: Icons.scale_rounded),
                      DriverStatusBadge(label: '${request.distanceKm.toStringAsFixed(1)} km · ${request.etaMinutes} min', color: DriverColors.warning, icon: Icons.route_rounded),
                    ],
                  ),
                  if (request.specialInstructions != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: DriverColors.warningSurface, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 15, color: DriverColors.warning),
                          const SizedBox(width: 8),
                          Expanded(child: Text(request.specialInstructions!, style: const TextStyle(fontSize: 12, color: DriverColors.textPrimary, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _decline,
                style: OutlinedButton.styleFrom(foregroundColor: DriverColors.error, side: const BorderSide(color: DriverColors.error), padding: const EdgeInsets.symmetric(vertical: 15)),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _accept,
                style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 15)),
                child: const Text('Accept delivery', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressRow(IconData icon, String label, String title, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: DriverColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: DriverText.label),
              const SizedBox(height: 2),
              Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: DriverColors.textPrimary)),
              Text(address, style: DriverText.caption),
            ],
          ),
        ),
      ],
    );
  }
}
