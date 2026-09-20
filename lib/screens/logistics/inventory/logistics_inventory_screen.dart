import 'package:flutter/material.dart';

import '../../driver/driver_theme.dart';
import '../../driver/widgets/driver_shared_widgets.dart';
import '../logistics_models.dart';
import 'inventory_detail_screen.dart';

/// The Inventory section's two tabs, per the spec:
///   - Tab 1 "Inventory" — every parcel this company has ever scanned in,
///     regardless of its current status (still shows once it's moved on
///     to delivery/transfer — see ParcelInventoryController::index).
///   - Tab 2 "For Inventory" — parcels a courier has physically handed
///     this company that haven't been scanned yet
///     (ParcelInventoryController::pending). Tapping one opens its detail
///     screen, where the QR scan actually happens.
class LogisticsInventoryScreen extends StatefulWidget {
  final List<InventoryParcel> pending;
  final List<InventoryParcel> scanned;
  final bool loading;
  final String? error;
  final String accessToken;
  final Future<void> Function() onRefresh;

  const LogisticsInventoryScreen({
    super.key,
    required this.pending,
    required this.scanned,
    required this.loading,
    required this.error,
    required this.accessToken,
    required this.onRefresh,
  });

  @override
  State<LogisticsInventoryScreen> createState() => _LogisticsInventoryScreenState();
}

class _LogisticsInventoryScreenState extends State<LogisticsInventoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this, initialIndex: 1);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openDetail(InventoryParcel parcel) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InventoryDetailScreen(parcelId: parcel.id, accessToken: widget.accessToken)),
    );
    if (mounted) await widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: DriverColors.heroGradient),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Inventory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 21)),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  tabs: [
                    Tab(text: 'For Inventory (${widget.pending.length})'),
                    Tab(text: 'Inventory (${widget.scanned.length})'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ParcelList(
                  parcels: widget.pending,
                  loading: widget.loading,
                  error: widget.error,
                  onRefresh: widget.onRefresh,
                  onTap: _openDetail,
                  emptyIcon: Icons.qr_code_scanner_rounded,
                  emptyTitle: 'Nothing awaiting a scan',
                  emptySubtitle: 'Parcels couriers hand over will show up here for scanning.',
                  pendingStyle: true,
                ),
                _ParcelList(
                  parcels: widget.scanned,
                  loading: widget.loading,
                  error: widget.error,
                  onRefresh: widget.onRefresh,
                  onTap: _openDetail,
                  emptyIcon: Icons.inventory_2_outlined,
                  emptyTitle: 'No inventory records yet',
                  emptySubtitle: 'Scanned parcels stay listed here permanently, even after they\'re dispatched.',
                  pendingStyle: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParcelList extends StatelessWidget {
  final List<InventoryParcel> parcels;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final void Function(InventoryParcel) onTap;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final bool pendingStyle;

  const _ParcelList({
    required this.parcels,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onTap,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.pendingStyle,
  });

  @override
  Widget build(BuildContext context) {
    return DriverRefreshable(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (error != null) ...[
            Container(
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
          if (loading) ...[
            const DriverCardSkeleton(),
            const DriverCardSkeleton(),
            const DriverCardSkeleton(),
          ] else if (parcels.isEmpty)
            DriverEmptyState(icon: emptyIcon, title: emptyTitle, subtitle: emptySubtitle)
          else
            for (final parcel in parcels) ...[
              _ParcelCard(parcel: parcel, pendingStyle: pendingStyle, onTap: () => onTap(parcel)),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ParcelCard extends StatelessWidget {
  final InventoryParcel parcel;
  final bool pendingStyle;
  final VoidCallback onTap;

  const _ParcelCard({required this.parcel, required this.pendingStyle, required this.onTap});

  String _originLabel(InventoryOrigin origin) {
    switch (origin) {
      case InventoryOrigin.pickup:
        return 'Picked up from seller';
      case InventoryOrigin.transferDeparture:
        return 'Outgoing transfer';
      case InventoryOrigin.transferReceipt:
        return 'Incoming transfer';
      case InventoryOrigin.unknown:
        return '';
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final local = d.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day} · $h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = pendingStyle ? DriverColors.warning : DriverColors.success;
    final badgeLabel = pendingStyle ? 'Awaiting scan' : 'In inventory';
    final badgeIcon = pendingStyle ? Icons.qr_code_scanner_rounded : Icons.check_circle_rounded;
    final timeLabel = pendingStyle ? _formatDate(parcel.forInventoryAt) : _formatDate(parcel.inventoryScannedAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          parcel.trackingNumber ?? parcel.orderNumber ?? 'Parcel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: DriverColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DriverStatusBadge(label: badgeLabel, color: badgeColor, icon: badgeIcon),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(parcel.buyer.name ?? 'Buyer', style: DriverText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 12, color: DriverColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [_originLabel(parcel.origin), if (timeLabel.isNotEmpty) timeLabel].where((s) => s.isNotEmpty).join(' · '),
                          style: DriverText.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
