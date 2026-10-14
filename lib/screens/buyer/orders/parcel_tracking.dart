import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';

const _osmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgent = 'com.buytheway.app';
const _pollEvery = Duration(seconds: 20);

/// Loads the parcel journey once and keeps it fresh while the parcel is
/// still moving. Shared by the collapsed card and the expanded screen so
/// opening the map never triggers a second request.
class ParcelJourneyController extends ChangeNotifier {
  ParcelJourneyController(this.orderNumber) {
    _load();
  }

  final String orderNumber;
  ParcelJourney? journey;
  bool loading = true;
  bool failed = false;
  Timer? _timer;
  bool _disposed = false;

  Future<void> _load() async {
    try {
      final j = await BuyerStore.instance.api.orderTracking(orderNumber);
      if (_disposed) return;
      journey = j;
      failed = false;
      _timer?.cancel();
      if (j.active) _timer = Timer(_pollEvery, _load);
    } catch (_) {
      if (_disposed) return;
      failed = journey == null;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> retry() {
    loading = true;
    failed = false;
    notifyListeners();
    return _load();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

// ============================================================
// Collapsed card (sits under the progress stepper)
// ============================================================

class ParcelMapCard extends StatefulWidget {
  const ParcelMapCard({super.key, required this.orderNumber, required this.history});

  final String orderNumber;
  final List<StatusEvent> history;

  @override
  State<ParcelMapCard> createState() => _ParcelMapCardState();
}

class _ParcelMapCardState extends State<ParcelMapCard> {
  late final _ctrl = ParcelJourneyController(widget.orderNumber);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _expand() => Navigator.of(context).push(PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => ParcelTrackingScreen(controller: _ctrl, history: widget.history),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) {
          final j = _ctrl.journey;
          if (_ctrl.loading && j == null) return const _MapSkeleton();
          if (j == null || !j.mappable) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 124,
                child: Stack(fit: StackFit.expand, children: [
                  JourneyMap(journey: j, interactive: false),
                  Positioned.fill(child: Material(color: Colors.transparent, child: InkWell(onTap: _expand))),
                  Positioned(left: 8, bottom: 8, right: 56, child: IgnorePointer(child: _StatusChip(journey: j))),
                  Positioned(right: 8, top: 8, child: _RoundButton(icon: Icons.open_in_full_rounded, onTap: _expand)),
                ]),
              ),
            ),
          );
        },
      );
}

class _MapSkeleton extends StatelessWidget {
  const _MapSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(height: 124, decoration: BoxDecoration(color: BColors.divider, borderRadius: BorderRadius.circular(16))),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.journey});

  final ParcelJourney journey;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(journey.live ? Icons.sensors_rounded : Icons.local_shipping_rounded, size: 14, color: BColors.brand),
            const SizedBox(width: 6),
            Flexible(
              child: Text(journey.statusLabel,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BColors.ink)),
            ),
          ]),
        ),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: BColors.ink)),
        ),
      );
}

// ============================================================
// Map
// ============================================================

class JourneyMap extends StatelessWidget {
  const JourneyMap({super.key, required this.journey, required this.interactive});

  final ParcelJourney journey;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final stops = journey.stops;
    final points = [for (final s in stops) LatLng(s.lat, s.lng)];
    final parcel = journey.parcel == null ? null : LatLng(journey.parcel!.lat, journey.parcel!.lng);
    final reachedPoints = [for (final s in stops) if (s.reached) LatLng(s.lat, s.lng)];

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: [...points, if (parcel != null) parcel],
          padding: EdgeInsets.all(interactive ? 48 : 28),
          maxZoom: 15,
        ),
        interactionOptions: InteractionOptions(flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none),
      ),
      children: [
        TileLayer(urlTemplate: _osmTiles, userAgentPackageName: _userAgent),
        PolylineLayer(polylines: [
          Polyline(points: points, strokeWidth: 3, color: BColors.border),
          if (reachedPoints.length > 1) Polyline(points: reachedPoints, strokeWidth: 4, color: BColors.brand),
          if (journey.trail.length > 1) Polyline(points: [for (final t in journey.trail) LatLng(t.lat, t.lng)], strokeWidth: 4, color: BColors.brand),
        ]),
        MarkerLayer(markers: [
          for (final s in stops) _stopMarker(s),
          if (parcel != null)
            Marker(
              point: parcel,
              width: 36,
              height: 36,
              child: Container(
                decoration: BoxDecoration(
                  color: BColors.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [BoxShadow(color: BColors.brand.withValues(alpha: 0.35), blurRadius: 8)],
                ),
                child: const Icon(Icons.local_shipping_rounded, size: 18, color: Colors.white),
              ),
            ),
        ]),
        if (interactive) const RichAttributionWidget(alignment: AttributionAlignment.bottomLeft, attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
      ],
    );
  }

  static Marker _stopMarker(JourneyStop s) {
    final color = s.reached ? BColors.brand : BColors.faint;
    final icon = switch (s.role) {
      'origin' => Icons.storefront_rounded,
      'destination' => Icons.home_rounded,
      _ => Icons.warehouse_rounded,
    };
    return Marker(
      point: LatLng(s.lat, s.lng),
      width: 28,
      height: 28,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

// ============================================================
// Expanded: 40% map / 60% order timeline
// ============================================================

class ParcelTrackingScreen extends StatelessWidget {
  const ParcelTrackingScreen({super.key, required this.controller, required this.history});

  final ParcelJourneyController controller;
  final List<StatusEvent> history;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BColors.surface,
      body: Column(children: [
        Expanded(
          flex: 4,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final j = controller.journey;
              return Stack(fit: StackFit.expand, children: [
                if (j != null) JourneyMap(journey: j, interactive: true) else const ColoredBox(color: BColors.divider),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  left: 12,
                  child: _RoundButton(icon: Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
                ),
                if (j != null)
                  Positioned(top: MediaQuery.paddingOf(context).top + 8, left: 64, right: 12, child: IgnorePointer(child: _StatusChip(journey: j))),
              ]);
            },
          ),
        ),
        Expanded(
          flex: 6,
          child: Container(
            decoration: const BoxDecoration(
              color: BColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: BColors.border, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Row(children: [
                  const Icon(Icons.timeline_rounded, size: 20, color: BColors.brand),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Order timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BColors.ink))),
                  Text('${history.length} updates', style: BText.tiny),
                ]),
              ),
              const Divider(height: 1, color: BColors.divider),
              const SizedBox(height: 12),
              Expanded(child: OrderTimelineList(events: history)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ============================================================
// Timeline list (shared with the order detail bottom sheet)
// ============================================================

class OrderTimelineList extends StatelessWidget {
  const OrderTimelineList({super.key, required this.events, this.controller});

  final List<StatusEvent> events;
  final ScrollController? controller;

  static IconData _iconFor(String status) {
    final s = status.toLowerCase();
    if (s.contains('cancel')) return Icons.cancel_rounded;
    if (s.contains('return')) return Icons.assignment_return_rounded;
    if (s.contains('deliver')) return Icons.home_rounded;
    if (s.contains('transit') || s.contains('ship') || s.contains('out for')) return Icons.local_shipping_rounded;
    if (s.contains('pack') || s.contains('process') || s.contains('ready')) return Icons.inventory_2_rounded;
    if (s.contains('confirm')) return Icons.check_circle_rounded;
    return Icons.receipt_long_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final list = [...events]..sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.paddingOf(context).bottom + 20),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final ev = list[i];
        final first = i == 0;
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 34,
              child: Column(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: first ? BColors.brand : BColors.brand.withValues(alpha: 0.10),
                    boxShadow: first ? [BoxShadow(color: BColors.brand.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 3))] : null,
                  ),
                  child: Icon(_iconFor(ev.status), size: 17, color: first ? Colors.white : BColors.brand),
                ),
                if (i < list.length - 1) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: BColors.brand.withValues(alpha: 0.25))),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(ev.status, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: first ? BColors.brand : BColors.ink)),
                    ),
                    if (first) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: BColors.brand.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Latest', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: BColors.brand)),
                      ),
                    ],
                  ]),
                  if (ev.note != null && ev.note!.isNotEmpty) ...[const SizedBox(height: 3), Text(ev.note!, style: BText.small)],
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.schedule_rounded, size: 13, color: BColors.faint),
                    const SizedBox(width: 4),
                    Text(formatDate(ev.at, withTime: true), style: BText.tiny),
                  ]),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}
