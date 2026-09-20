import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../driver/deliveries/qr_scan_screen.dart';
import '../../driver/driver_theme.dart';
import '../../driver/widgets/driver_shared_widgets.dart';
import '../logistics_models.dart';

/// Full detail for one parcel — reached from either Inventory tab.
///
/// For a "For Inventory" parcel (status == for_inventory), this is also
/// where the QR-gated scan happens: [QrScanScreen] (reused as-is from the
/// courier app) only ever pops with a code that matches this parcel's own
/// `confirmation_token` — a mismatch shows an inline correction and keeps
/// the camera running, so there is no path to marking a parcel scanned
/// without a successful, verified scan (spec requirement #4). Once
/// [ApiService.scanInventory] confirms it server-side too, this screen
/// pops back to the list, which reloads and moves the row into the
/// "Inventory" tab.
class InventoryDetailScreen extends StatefulWidget {
  final String parcelId;
  final String accessToken;

  const InventoryDetailScreen({super.key, required this.parcelId, required this.accessToken});

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  final ApiService _api = ApiService();

  InventoryParcel? _parcel;
  bool _loading = true;
  String? _error;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.getInventoryDetail(parcelAssignmentId: widget.parcelId, accessToken: widget.accessToken);
      final data = response['data'];
      if (data is! Map) throw ApiException(message: 'The server returned an invalid response.', statusCode: 500);
      if (!mounted) return;
      setState(() {
        _parcel = InventoryParcel.fromApi(Map<String, dynamic>.from(data));
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this parcel. Please try again.';
      });
    }
  }

  Future<void> _scanQr() async {
    final parcel = _parcel;
    if (parcel == null) return;

    if (kIsWeb) {
      _toast("Scanning isn't supported in this preview. Please use the mobile app.", isError: true);
      return;
    }

    final expectedToken = parcel.confirmationToken;
    if (expectedToken == null) {
      _toast("This parcel doesn't have a QR code on file.", isError: true);
      return;
    }

    final result = await Navigator.of(context).push<QrScanResult>(
      MaterialPageRoute(builder: (_) => QrScanScreen(title: 'Scan to confirm inventory', expectedToken: expectedToken)),
    );
    if (result == null || !mounted) return;

    setState(() => _scanning = true);
    try {
      final response = await _api.scanInventory(
        parcelAssignmentId: widget.parcelId,
        accessToken: widget.accessToken,
        confirmationToken: result.rawValue,
      );
      final data = response['data'];
      if (data is! Map) throw ApiException(message: 'The server returned an invalid response.', statusCode: 500);
      if (!mounted) return;
      setState(() {
        _parcel = InventoryParcel.fromApi(Map<String, dynamic>.from(data));
        _scanning = false;
      });
      DriverTopNotification.show(context, message: 'Parcel scanned into inventory.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      // A QR/status mismatch from the backend (e.g. "doesn't match this
      // parcel") lands here — surfaced inline rather than silently marking
      // anything scanned, same "prevent the scan from completing" rule
      // QrScanScreen already enforces client-side.
      _toast(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _scanning = false);
      _toast('Could not confirm this scan. Please try again.', isError: true);
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    DriverTopNotification.show(
      context,
      message: message,
      icon: isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
      accent: isError ? DriverColors.error : DriverColors.success,
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Unknown time';
    final local = d.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day} · $h:$m $period';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'for_inventory':
        return 'Awaiting inventory scan';
      case 'handed_off':
        return 'To be dispatched';
      case 'ready_to_transfer':
        return 'Ready to transfer';
      case 'transferred':
        return 'Transferred';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcel = _parcel;

    return Scaffold(
      backgroundColor: DriverColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DriverGradientHeader(
              title: parcel?.trackingNumber ?? parcel?.orderNumber ?? 'Parcel',
              subtitle: parcel == null ? '' : _statusLabel(parcel.status),
              onBack: () => Navigator.of(context).pop(),
              trailing: parcel != null
                  ? DriverStatusBadge(
                      label: parcel.isScanned ? 'Scanned' : 'Pending',
                      color: parcel.isScanned ? DriverColors.success : DriverColors.warning,
                      icon: parcel.isScanned ? Icons.check_circle_rounded : Icons.qr_code_scanner_rounded,
                    )
                  : null,
            ),
            Expanded(child: _buildBody(context)),
            if (parcel != null && parcel.isPending) _buildScanBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: DriverColors.primary));
    }

    final parcel = _parcel;
    if (parcel == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Could not load this parcel.', textAlign: TextAlign.center, style: DriverText.body),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: _load, style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white), child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    return DriverRefreshable(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (parcel.isPending) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: DriverColors.warningSurface, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, size: 18, color: DriverColors.warning),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Scan this parcel\'s QR code to move it into inventory before it can be delivered or transferred.',
                        style: DriverText.caption,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _sectionCard(
              icon: Icons.local_shipping_outlined,
              title: 'Tracking',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Tracking number', parcel.trackingNumber ?? 'Not on file'),
                  _infoRow('Order number', parcel.orderNumber ?? 'Not on file'),
                  if (parcel.transferToCompanyName != null) _infoRow('Transferring to', parcel.transferToCompanyName!),
                  if (parcel.hubName != null) _infoRow('Hub / company', parcel.hubName!),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              icon: Icons.person_outline_rounded,
              title: 'Buyer / recipient',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Name', parcel.buyer.name ?? 'Not on file'),
                  if (parcel.buyer.contactNo != null) _infoRow('Contact', parcel.buyer.contactNo!),
                  if (parcel.buyer.address != null) _infoRow('Address', parcel.buyer.address!),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              icon: Icons.storefront_outlined,
              title: 'Seller / sender',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Name', parcel.seller.shopName ?? parcel.seller.name ?? 'Not on file'),
                  if (parcel.seller.contactNo != null) _infoRow('Contact', parcel.seller.contactNo!),
                  if (parcel.seller.address != null) _infoRow('Address', parcel.seller.address!),
                ],
              ),
            ),
            if (parcel.courier != null) ...[
              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.moped_rounded,
                title: 'Courier who picked it up',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Name', parcel.courier!.fullName ?? 'Not on file'),
                    if (parcel.courier!.contactNo != null) _infoRow('Contact', parcel.courier!.contactNo!),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _sectionCard(
              icon: Icons.inventory_2_outlined,
              title: 'Parcel contents',
              child: parcel.items.isEmpty
                  ? const Text('No item details on file.', style: DriverText.body)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < parcel.items.length; i++) ...[
                          if (i > 0) const Divider(height: 20),
                          _itemRow(parcel.items[i]),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              icon: Icons.history_rounded,
              title: 'Inventory record',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Entered inventory', parcel.forInventoryAt != null ? _formatDate(parcel.forInventoryAt) : 'Not yet'),
                  _infoRow('Scanned', parcel.inventoryScannedAt != null ? _formatDate(parcel.inventoryScannedAt) : 'Not yet'),
                  if (parcel.inventoryScannedBy?.fullName != null) _infoRow('Scanned by', parcel.inventoryScannedBy!.fullName!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4))]),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _scanning ? null : _scanQr,
            icon: _scanning
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Icon(Icons.qr_code_scanner_rounded),
            label: Text(_scanning ? 'Confirming…' : 'Scan QR to confirm'),
            style: DriverButtonStyle.primary(DriverColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: DriverText.caption)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DriverColors.textPrimary))),
        ],
      ),
    );
  }

  Widget _itemRow(InventoryItem item) {
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
              Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: DriverColors.textPrimary)),
              if (meta.isNotEmpty) ...[const SizedBox(height: 2), Text(meta, style: DriverText.caption)],
              if (specs.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.straighten_rounded, size: 12, color: DriverColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(child: Text(specs, style: DriverText.caption)),
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
          child: Text('×${item.quantity}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: DriverColors.primaryDark)),
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
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, size: 15, color: DriverColors.primaryDark),
              ),
              const SizedBox(width: 10),
              Text(title, style: DriverText.sectionTitle),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
