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

  /// Background refresh can't reach the server: shows a small "Reconnecting…" hint.
  final bool reconnecting;

  /// A scan is open / finished (holds the shell's poll and invalidates in-flight ones).
  final ValueChanged<bool>? onScanActive;

  /// A scan was confirmed; the shell moves the parcel locally, then refreshes.
  final ValueChanged<InventoryParcel>? onScanned;

  const LogisticsInventoryScreen({
    super.key,
    required this.pending,
    required this.scanned,
    required this.loading,
    required this.error,
    required this.accessToken,
    required this.onRefresh,
    this.reconnecting = false,
    this.onScanActive,
    this.onScanned,
  });

  @override
  State<LogisticsInventoryScreen> createState() =>
      _LogisticsInventoryScreenState();
}

class _LogisticsInventoryScreenState extends State<LogisticsInventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openDetail(InventoryParcel parcel) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventoryDetailScreen(
          parcelId: parcel.id,
          accessToken: widget.accessToken,
          onScanActive: widget.onScanActive,
          onScanned: widget.onScanned,
        ),
      ),
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
            color: const Color(0xFFF5F6F1),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LOGISTICS / PARCELS',
                    style: TextStyle(
                        color: Color(0xFF184D3B),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5)),
                const SizedBox(height: 7),
                const Text('Parcel checkpoint',
                    style: TextStyle(
                        color: Color(0xFF172923),
                        fontWeight: FontWeight.w800,
                        fontSize: 27,
                        letterSpacing: -.8)),
                const SizedBox(height: 7),
                const Text('Receive and track parcels at your hub.',
                    style: TextStyle(color: Color(0xFF687970), fontSize: 13)),
                const SizedBox(height: 18),
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF184D3B),
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: const Color(0xFFE0E6DD),
                  labelColor: const Color(0xFF184D3B),
                  unselectedLabelColor: const Color(0xFF687970),
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13),
                  tabs: [
                    Tab(text: 'To scan (${widget.pending.length})'),
                    Tab(text: 'Scanned (${widget.scanned.length})'),
                  ],
                ),
              ],
            ),
          ),
          if (widget.reconnecting)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.8, color: DriverColors.textSecondary)),
                SizedBox(width: 8),
                Text('Reconnecting…', style: DriverText.caption),
              ]),
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
                  emptySubtitle:
                      'Parcels couriers hand over will show up here for scanning.',
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
                  emptySubtitle:
                      'Scanned parcels stay listed here permanently, even after they\'re dispatched.',
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

class _ParcelList extends StatefulWidget {
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
  State<_ParcelList> createState() => _ParcelListState();
}

class _ParcelListState extends State<_ParcelList> {
  final _scroll = ScrollController();

  /// What is on screen. Follows the shell's list while at the top; once the
  /// rider has scrolled down, parcels that join/leave are held back behind an
  /// "N new" pill so rows don't shift under the finger.
  List<InventoryParcel> _shown = const [];
  int _held = 0;
  int _heldNew = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _scrolled => _scroll.hasClients && _scroll.offset > 24;

  void _sync(List<InventoryParcel> fresh) {
    final sameShape = fresh.length == _shown.length &&
        [for (var i = 0; i < fresh.length; i++) fresh[i].id == _shown[i].id]
            .every((e) => e);
    if (sameShape || _shown.isEmpty || fresh.isEmpty || !_scrolled) {
      _shown = fresh;
      _held = 0;
      _heldNew = 0;
      return;
    }
    final byId = {for (final p in fresh) p.id: p};
    _shown = [for (final p in _shown) byId[p.id] ?? p]; // refresh rows in place
    final shownIds = {for (final p in _shown) p.id};
    _heldNew = fresh.where((p) => !shownIds.contains(p.id)).length;
    _held = _heldNew + _shown.where((p) => !byId.containsKey(p.id)).length;
    if (_held == 0) _held = 1; // pure reorder
  }

  void _applyHeld() {
    setState(() {
      _shown = widget.parcels;
      _held = 0;
      _heldNew = 0;
    });
    if (_scroll.hasClients)
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    _sync(widget.parcels);
    final parcels = _shown;
    final list = DriverRefreshable(
      onRefresh: widget.onRefresh,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          if (widget.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: DriverColors.errorSurface,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: DriverColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(widget.error!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: DriverColors.error,
                              fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (widget.loading) ...[
            const DriverCardSkeleton(),
            const DriverCardSkeleton(),
            const DriverCardSkeleton(),
          ] else if (parcels.isEmpty)
            DriverEmptyState(
                icon: widget.emptyIcon,
                title: widget.emptyTitle,
                subtitle: widget.emptySubtitle)
          else
            for (final parcel in parcels) ...[
              _ParcelCard(
                  key: ValueKey(parcel.id),
                  parcel: parcel,
                  pendingStyle: widget.pendingStyle,
                  onTap: () => widget.onTap(parcel)),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
    if (_held == 0) return list;
    return Stack(children: [
      list,
      Positioned(
        top: 10,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: DriverColors.primary,
            borderRadius: BorderRadius.circular(20),
            elevation: 3,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _applyHeld,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.arrow_upward_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(_heldNew > 0 ? '$_heldNew new' : '$_held updated',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _ParcelCard extends StatelessWidget {
  final InventoryParcel parcel;
  final bool pendingStyle;
  final VoidCallback onTap;

  const _ParcelCard(
      {super.key,
      required this.parcel,
      required this.pendingStyle,
      required this.onTap});

  String _originLabel(InventoryOrigin origin) {
    switch (origin) {
      case InventoryOrigin.pickup:
        // A return's first leg is collected from the buyer, not the seller.
        return parcel.isReturn
            ? 'Picked up from buyer'
            : 'Picked up from seller';
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
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day} · $h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor =
        pendingStyle ? DriverColors.warning : DriverColors.success;
    final badgeLabel = pendingStyle ? 'Awaiting scan' : 'In inventory';
    final badgeIcon = pendingStyle
        ? Icons.qr_code_scanner_rounded
        : Icons.check_circle_rounded;
    final timeLabel = pendingStyle
        ? _formatDate(parcel.forInventoryAt)
        : _formatDate(parcel.inventoryScannedAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: const Border(
                left: BorderSide(color: Color(0xFF184D3B), width: 3))),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: pendingStyle
                      ? const Color(0xFFF8EFE2)
                      : const Color(0xFFE7F0E9),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(
                  pendingStyle
                      ? Icons.qr_code_rounded
                      : Icons.inventory_2_outlined,
                  color: pendingStyle
                      ? const Color(0xFF9D6120)
                      : const Color(0xFF184D3B),
                  size: 20),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          parcel.trackingNumber ??
                              parcel.orderNumber ??
                              'Parcel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF172923)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DriverStatusBadge(
                              label: badgeLabel,
                              color: badgeColor,
                              icon: badgeIcon),
                          if (parcel.isReturn) ...[
                            const SizedBox(height: 4),
                            const DriverReturnChip(),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(parcel.buyer.name ?? 'Buyer',
                      style: DriverText.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined,
                          size: 12, color: DriverColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [
                            _originLabel(parcel.origin),
                            if (timeLabel.isNotEmpty) timeLabel
                          ].where((s) => s.isNotEmpty).join(' · '),
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
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: Color(0xFF687970)),
          ],
        ),
      ),
    );
  }
}
