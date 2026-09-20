import 'package:flutter/material.dart';

import '../../driver/driver_theme.dart';
import '../../driver/widgets/driver_shared_widgets.dart';
import '../logistics_models.dart';

/// Landing tab of the Logistics mobile app — a compact summary of the
/// inventory pipeline (parcels awaiting a scan vs. already scanned in,
/// split further by which of the three "a courier just handed us a
/// parcel" moments produced them) plus a shortcut into the Inventory tab.
/// No separate stats endpoint exists on the backend — every count here is
/// derived client-side from the same `pending`/`index` inventory lists the
/// Inventory tab itself loads (see LogisticsShell).
class LogisticsDashboardScreen extends StatelessWidget {
  final LogisticsAccount account;
  final List<InventoryParcel> pending;
  final List<InventoryParcel> scanned;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenInventory;

  const LogisticsDashboardScreen({
    super.key,
    required this.account,
    required this.pending,
    required this.scanned,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onOpenInventory,
  });

  int get _fromPickup => pending.where((p) => p.origin == InventoryOrigin.pickup).length;
  int get _fromTransferDeparture => pending.where((p) => p.origin == InventoryOrigin.transferDeparture).length;
  int get _fromTransferReceipt => pending.where((p) => p.origin == InventoryOrigin.transferReceipt).length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          DriverGradientHeader(
            title: account.companyName,
            subtitle: '${account.ownerName} · Logistics',
          ),
          Expanded(
            child: DriverRefreshable(
              onRefresh: onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: DriverColors.errorSurface, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 16, color: DriverColors.error),
                            const SizedBox(width: 8),
                            Expanded(child: Text(error!, style: const TextStyle(fontSize: 12, color: DriverColors.error, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const DriverSectionHeader(title: 'Inventory pipeline'),
                    const SizedBox(height: 12),
                    if (loading)
                      const Row(
                        children: [
                          Expanded(child: DriverCardSkeleton()),
                          SizedBox(width: 12),
                          Expanded(child: DriverCardSkeleton()),
                        ],
                      )
                    else
                      GestureDetector(
                        onTap: onOpenInventory,
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.qr_code_scanner_rounded,
                                label: 'Awaiting scan',
                                value: '${pending.length}',
                                color: DriverColors.warning,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.inventory_2_rounded,
                                label: 'In inventory',
                                value: '${scanned.length}',
                                color: DriverColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    const DriverSectionHeader(title: 'Awaiting scan, by source'),
                    const SizedBox(height: 12),
                    _sourceRow(
                      icon: Icons.storefront_rounded,
                      label: 'Picked up from sellers',
                      count: _fromPickup,
                    ),
                    const SizedBox(height: 8),
                    _sourceRow(
                      icon: Icons.compare_arrows_rounded,
                      label: 'Outgoing transfers',
                      count: _fromTransferDeparture,
                    ),
                    const SizedBox(height: 8),
                    _sourceRow(
                      icon: Icons.call_received_rounded,
                      label: 'Incoming transfers',
                      count: _fromTransferReceipt,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: DriverColors.primaryDark),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'A parcel can\'t be dispatched for delivery or transfer until its QR code is scanned here.',
                              style: DriverText.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceRow({required IconData icon, required String label, required int count}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: DriverColors.border)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: DriverColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: DriverText.body)),
          Text('$count', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DriverColors.textPrimary)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: DriverColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: DriverText.caption),
        ],
      ),
    );
  }
}
