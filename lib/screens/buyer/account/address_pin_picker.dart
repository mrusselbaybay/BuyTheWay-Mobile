import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../driver/driver_theme.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';

const _osmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgent = 'com.buytheway.app';

/// Generous box around the Philippines — mirrors the server's MapPin check.
final _phBounds = LatLngBounds(const LatLng(4.2, 116.0), const LatLng(21.5, 127.0));

bool inPhilippines(LatLng p) => p.latitude >= 4.2 && p.latitude <= 21.5 && p.longitude >= 116.0 && p.longitude <= 127.0;

const _precisionText = {
  'street': 'Map opened on your street.',
  'barangay': 'Map opened on your barangay.',
  'municipality': 'Map opened on your city / municipality.',
  'approximate': 'Map opened near your area.',
  'country': 'We couldn\'t find your area — zoom in to your location.',
};

/// Full-screen "fixed centre pin" picker: the map moves under the pin, which
/// is far easier on touch screens than dragging a tiny marker. Opens on the
/// typed address when there is no pin yet. Resolves the chosen point.
Future<LatLng?> showAddressPinPicker(
  BuildContext context, {
  LatLng? initial,
  String street = '',
  String barangay = '',
  String municipality = '',
  String province = '',
}) =>
    Navigator.of(context).push<LatLng>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PinPickerScreen(initial: initial, street: street, barangay: barangay, municipality: municipality, province: province),
    ));

class _PinPickerScreen extends StatefulWidget {
  const _PinPickerScreen({this.initial, required this.street, required this.barangay, required this.municipality, required this.province});

  final LatLng? initial;
  final String street;
  final String barangay;
  final String municipality;
  final String province;

  @override
  State<_PinPickerScreen> createState() => _PinPickerScreenState();
}

class _PinPickerScreenState extends State<_PinPickerScreen> {
  static const _fallbackCenter = LatLng(12.8797, 121.774);
  final controller = MapController();
  final store = BuyerStore.instance;
  LatLng? center;
  double zoom = 17;
  bool locating = true;
  String? note;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (widget.initial != null) {
      setState(() {
        center = widget.initial;
        locating = false;
      });
      return;
    }
    try {
      final hit = await store.api.locateAddress(street: widget.street, barangay: widget.barangay, municipality: widget.municipality, province: widget.province);
      if (!mounted) return;
      setState(() {
        center = hit.$1;
        zoom = hit.$2;
        note = _precisionText[hit.$3];
        locating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        center = _fallbackCenter;
        zoom = 6;
        note = _precisionText['country'];
        locating = false;
      });
    }
  }

  void _zoomBy(double delta) {
    final camera = controller.camera;
    controller.move(camera.center, (camera.zoom + delta).clamp(5, 19));
  }

  void _confirm() {
    final point = controller.camera.center;
    if (!inPhilippines(point)) {
      showToast(context, 'The pin must be within the Philippines.', error: true);
      return;
    }
    Navigator.pop(context, point);
  }

  @override
  Widget build(BuildContext context) {
    final start = center;
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: DriverColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text('Pin your location', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: start == null
          ? const Center(child: CircularProgressIndicator(color: DriverColors.primary))
          : Stack(children: [
              FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: start,
                  initialZoom: zoom,
                  minZoom: 5,
                  maxZoom: 19,
                  cameraConstraint: CameraConstraint.contain(bounds: _phBounds),
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                ),
                children: [
                  TileLayer(urlTemplate: _osmTiles, userAgentPackageName: _userAgent),
                  const RichAttributionWidget(alignment: AttributionAlignment.bottomLeft, attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
                ],
              ),
              // Fixed centre pin: its tip sits exactly on the map centre.
              const IgnorePointer(
                child: Center(
                  child: Padding(padding: EdgeInsets.only(bottom: 44), child: Icon(Icons.location_on_rounded, size: 48, color: DriverColors.primary, shadows: [Shadow(color: Colors.black38, blurRadius: 8)])),
                ),
              ),
              if (note != null)
                Positioned(
                  left: 16,
                  right: 16,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: softShadow(0.14)),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: DriverColors.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(note!, style: DriverText.body.copyWith(fontSize: 12.5))),
                    ]),
                  ),
                ),
              Positioned(
                right: 16,
                bottom: 168 + MediaQuery.paddingOf(context).bottom,
                child: Column(children: [
                  _MapButton(icon: Icons.add_rounded, tooltip: 'Zoom in', onTap: () => _zoomBy(1)),
                  const SizedBox(height: 8),
                  _MapButton(icon: Icons.remove_rounded, tooltip: 'Zoom out', onTap: () => _zoomBy(-1)),
                ]),
              ),
              if (locating) const ColoredBox(color: Colors.black26, child: Center(child: CircularProgressIndicator(color: Colors.white))),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), boxShadow: softShadow(0.14)),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.open_with_rounded, size: 18, color: DriverColors.primary),
                      SizedBox(width: 8),
                      Expanded(child: Text('Move the map so the pin sits on your door', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DriverColors.textPrimary))),
                    ]),
                    const SizedBox(height: 4),
                    const Padding(padding: EdgeInsets.only(left: 26), child: Text('Riders use this pin to find you without calling.', style: DriverText.caption)),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: locating ? null : _confirm,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Confirm pin', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      style: FilledButton.styleFrom(backgroundColor: DriverColors.primary, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: SizedBox(width: 44, height: 44, child: Icon(icon, color: DriverColors.textPrimary))),
        ),
      );
}

/// Static map thumbnail of a saved pin (tap to change it).
class AddressPinPreview extends StatelessWidget {
  const AddressPinPreview({super.key, required this.pin, required this.onTap});
  final LatLng pin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 150,
          child: Stack(children: [
            IgnorePointer(
              child: FlutterMap(
                options: MapOptions(initialCenter: pin, initialZoom: 16.5, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
                children: [TileLayer(urlTemplate: _osmTiles, userAgentPackageName: _userAgent)],
              ),
            ),
            const IgnorePointer(child: Center(child: Padding(padding: EdgeInsets.only(bottom: 34), child: Icon(Icons.location_on_rounded, size: 40, color: DriverColors.primary)))),
            Positioned.fill(child: Material(color: Colors.transparent, child: InkWell(onTap: onTap))),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: softShadow(0.14)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_location_alt_outlined, size: 15, color: DriverColors.primary),
                  SizedBox(width: 5),
                  Text('Change pin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: DriverColors.primary)),
                ]),
              ),
            ),
          ]),
        ),
      );
}
