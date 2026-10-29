import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../driver/driver_theme.dart';
import '../../driver/widgets/driver_shared_widgets.dart';
import '../logistics_models.dart';
import '../logistics_theme.dart';
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
  final InventoryOrigin? initialOrigin;
  final int viewVersion;
  final List<InventoryParcel> scanned;
  final bool loading;
  final String? error;
  final String accessToken;
  final Future<void> Function() onRefresh;
  final int unreadNotifications;
  final VoidCallback onOpenNotifications;

  /// Background refresh can't reach the server: shows a small "Reconnecting…" hint.
  final bool reconnecting;

  /// A scan is open / finished (holds the shell's poll and invalidates in-flight ones).
  final ValueChanged<bool>? onScanActive;

  /// A scan was confirmed; the shell moves the parcel locally, then refreshes.
  final ValueChanged<InventoryParcel>? onScanned;

  const LogisticsInventoryScreen({
    super.key,
    required this.pending,
    this.initialOrigin,
    this.viewVersion = 0,
    required this.scanned,
    required this.loading,
    required this.error,
    required this.accessToken,
    required this.onRefresh,
    required this.unreadNotifications,
    required this.onOpenNotifications,
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
  void didUpdateWidget(covariant LogisticsInventoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewVersion != oldWidget.viewVersion) {
      _tabController.animateTo(0);
    }
  }

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

  InventoryParcel? get _nextPending {
    if (widget.pending.isEmpty) return null;
    final ordered = [...widget.pending]..sort((a, b) {
        final aTime = a.forInventoryAt;
        final bTime = b.forInventoryAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });
    return ordered.first;
  }

  String get _queueSummary {
    if (widget.loading) return 'Loading parcel queue';
    if (widget.pending.isEmpty) return 'No parcels awaiting verification';
    final oldest = _nextPending?.forInventoryAt;
    if (oldest == null) return '${widget.pending.length} awaiting verification';
    final elapsed = DateTime.now().difference(oldest.toLocal());
    final age = elapsed.inMinutes < 60
        ? '${elapsed.inMinutes.clamp(0, 59)} min'
        : elapsed.inHours < 24
            ? '${elapsed.inHours} hr'
            : '${elapsed.inDays} d';
    return '${widget.pending.length} awaiting verification · oldest $age';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ColoredBox(
        color: LogisticsTheme.canvas,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('BUYTHEWAY',
                    style: TextStyle(
                        color: Color(0xFF567060),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.65)),
                const SizedBox(width: 7),
                Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                        color: Color(0xFF9AA69C), shape: BoxShape.circle)),
                const SizedBox(width: 7),
                const Text('LOGISTICS',
                    style: TextStyle(
                        color: Color(0xFF879389),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3)),
                const Spacer(),
                if (widget.reconnecting)
                  const Row(children: [
                    SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: Color(0xFF9A6A38))),
                    SizedBox(width: 6),
                    Text('Reconnecting',
                        style: TextStyle(
                            color: Color(0xFF7B674E),
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ])
                else
                  const Row(children: [
                    Icon(Icons.sync_rounded,
                        size: 13, color: Color(0xFF78917D)),
                    SizedBox(width: 5),
                    Text('Live',
                        style: TextStyle(
                            color: Color(0xFF5E7665),
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ]),
                const SizedBox(width: 10),
                Badge(
                  isLabelVisible: widget.unreadNotifications > 0,
                  label: Text(widget.unreadNotifications > 99
                      ? '99+'
                      : '${widget.unreadNotifications}'),
                  backgroundColor: const Color(0xFFF97316),
                  child: IconButton(
                    onPressed: widget.onOpenNotifications,
                    tooltip: 'Notifications',
                    icon:
                        const Icon(Icons.notifications_none_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF475569),
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)),
                      side: const BorderSide(color: Color(0xFFD9DED7)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 13),
              const Text('Parcel operations', style: LogisticsTheme.pageTitle),
              const SizedBox(height: 6),
              Text(_queueSummary,
                  style: const TextStyle(
                      color: Color(0xFF687970),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4)),
              const SizedBox(height: 13),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: widget.loading || _nextPending == null
                      ? null
                      : () => _openDetail(_nextPending!),
                  style: FilledButton.styleFrom(
                    backgroundColor: DriverColors.primary,
                    disabledBackgroundColor: const Color(0xFFDDE3DD),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF7D8980),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: Text(
                      _nextPending == null
                          ? 'Queue is clear'
                          : 'Review next parcel',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                indicator: const UnderlineTabIndicator(
                    borderSide:
                        BorderSide(color: DriverColors.primary, width: 3),
                    insets: EdgeInsets.symmetric(horizontal: 5)),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: const Color(0xFFD9DED7),
                labelColor: DriverColors.primary,
                unselectedLabelColor: const Color(0xFF859087),
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                tabs: const [
                  Tab(text: 'To scan'),
                  Tab(text: 'All parcels'),
                ],
              ),
            ]),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ParcelList(
                  key: ValueKey('pending-${widget.viewVersion}'),
                  initialOrigin: widget.initialOrigin,
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
        ]),
      ),
    );
  }
}

class _MastheadMetric extends StatelessWidget {
  const _MastheadMetric(
      {required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 25,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1)),
        const SizedBox(width: 9),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF59685F),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]);
}

class _ParcelList extends StatefulWidget {
  final InventoryOrigin? initialOrigin;
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
    super.key,
    this.initialOrigin,
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
  final _search = TextEditingController();
  String _query = '';
  _ParcelFilter _filter = _ParcelFilter.all;

  @override
  void initState() {
    super.initState();
    _filter = switch (widget.initialOrigin) {
      InventoryOrigin.pickup => _ParcelFilter.pickup,
      InventoryOrigin.transferReceipt => _ParcelFilter.inbound,
      InventoryOrigin.transferDeparture => _ParcelFilter.outbound,
      _ => _ParcelFilter.all,
    };
  }

  /// What is on screen. Follows the shell's list while at the top; once the
  /// rider has scrolled down, parcels that join/leave are held back behind an
  /// "N new" pill so rows don't shift under the finger.
  List<InventoryParcel> _shown = const [];
  int _held = 0;
  int _heldNew = 0;

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
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
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  List<InventoryParcel> _filtered(List<InventoryParcel> parcels) {
    final query = _query.trim().toLowerCase();
    return parcels.where((parcel) {
      final matchesFilter = switch (_filter) {
        _ParcelFilter.all => true,
        _ParcelFilter.pickup => parcel.origin == InventoryOrigin.pickup,
        _ParcelFilter.inbound =>
          parcel.origin == InventoryOrigin.transferReceipt,
        _ParcelFilter.outbound =>
          parcel.origin == InventoryOrigin.transferDeparture,
        _ParcelFilter.returns => parcel.isReturn,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      final searchable = [
        parcel.trackingNumber,
        parcel.orderNumber,
        parcel.buyer.name,
        parcel.buyer.contactNo,
        parcel.seller.name,
        parcel.seller.shopName,
        parcel.courier?.fullName,
        parcel.inventoryScannedBy?.fullName,
        parcel.hubName,
        parcel.transferToCompanyName,
        ...parcel.items.map((item) => item.name),
        ...parcel.items.map((item) => item.sku),
      ].whereType<String>().join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    _sync(widget.parcels);
    final parcels = _shown;
    final visibleParcels = _filtered(parcels);
    final now = DateTime.now();
    final needsAttention = widget.pendingStyle
        ? visibleParcels.where((parcel) {
            final received = parcel.forInventoryAt;
            return received != null &&
                now.difference(received.toLocal()).inMinutes >= 30;
          }).toList()
        : const <InventoryParcel>[];
    final needsAttentionIds = {for (final parcel in needsAttention) parcel.id};
    final recent = widget.pendingStyle
        ? visibleParcels
            .where((parcel) => !needsAttentionIds.contains(parcel.id))
            .toList()
        : const <InventoryParcel>[];
    final list = DriverRefreshable(
      onRefresh: widget.onRefresh,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Row(children: [
            Expanded(
                child: Text(
                    widget.pendingStyle
                        ? 'Verification queue'
                        : 'Parcel archive',
                    style: const TextStyle(
                        color: Color(0xFF33483B),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.2))),
            Text('${visibleParcels.length} shown',
                style: const TextStyle(
                    color: Color(0xFF52645B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search tracking, order, people or items…',
              hintStyle:
                  const TextStyle(color: Color(0xFF89948C), fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF63756B), size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFD9DED7))),
              enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFD9DED7))),
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF47735C), width: 1.5)),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final filter in _ParcelFilter.values) ...[
                _RecordFilterChip(
                    label: filter.label,
                    selected: _filter == filter,
                    onTap: () => setState(() => _filter = filter)),
                const SizedBox(width: 7),
              ],
            ]),
          ),
          const SizedBox(height: 16),
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
            const _ParcelSkeleton(),
            const _ParcelSkeleton(),
            const _ParcelSkeleton(),
          ] else if (visibleParcels.isEmpty && parcels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: DriverEmptyState(
                icon: Icons.manage_search_rounded,
                title: 'No matching records',
                subtitle: 'Try another search or clear the selected filter.',
              ),
            )
          else if (parcels.isEmpty)
            DriverEmptyState(
                icon: widget.emptyIcon,
                title: widget.emptyTitle,
                subtitle: widget.emptySubtitle)
          else if (widget.pendingStyle) ...[
            if (needsAttention.isNotEmpty) ...[
              _QueueSectionHeading(
                title: 'Needs attention',
                count: needsAttention.length,
                color: const Color(0xFF9B682D),
                icon: Icons.schedule_rounded,
              ),
              const SizedBox(height: 8),
              for (final parcel in needsAttention) ...[
                _ParcelCard(
                    key: ValueKey(parcel.id),
                    parcel: parcel,
                    pendingStyle: true,
                    onTap: () => widget.onTap(parcel)),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
            ],
            if (recent.isNotEmpty) ...[
              _QueueSectionHeading(
                title: needsAttention.isEmpty
                    ? 'Ready to verify'
                    : 'Recently received',
                count: recent.length,
                color: DriverColors.primary,
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 8),
              for (final parcel in recent) ...[
                _ParcelCard(
                    key: ValueKey(parcel.id),
                    parcel: parcel,
                    pendingStyle: true,
                    onTap: () => widget.onTap(parcel)),
                const SizedBox(height: 10),
              ],
            ],
          ] else
            for (final parcel in visibleParcels) ...[
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

enum _ParcelFilter { all, pickup, inbound, outbound, returns }

extension on _ParcelFilter {
  String get label => switch (this) {
        _ParcelFilter.all => 'All records',
        _ParcelFilter.pickup => 'Pickup',
        _ParcelFilter.inbound => 'Transfer in',
        _ParcelFilter.outbound => 'Transfer out',
        _ParcelFilter.returns => 'Returns',
      };
}

class _RecordFilterChip extends StatelessWidget {
  const _RecordFilterChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.fromLTRB(8, 11, 8, 11),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: selected
                            ? DriverColors.primary
                            : Colors.transparent,
                        width: 2))),
            child: Text(label,
                style: TextStyle(
                    color: selected
                        ? LogisticsTheme.primary
                        : LogisticsTheme.muted,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
          ),
        ),
      );
}

class _DailyVolumeChart extends StatelessWidget {
  const _DailyVolumeChart({required this.parcels, required this.loading});
  final List<InventoryParcel> parcels;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final start = end.subtract(const Duration(days: 6));
    final days = List.generate(7, (index) => start.add(Duration(days: index)));
    final received = List<int>.filled(7, 0);
    final scanned = List<int>.filled(7, 0);
    void addEvent(DateTime? value, List<int> series) {
      final event = value?.toLocal();
      if (event == null) return;
      final date = DateTime(event.year, event.month, event.day);
      final index = date.difference(start).inDays;
      if (index >= 0 && index < series.length) series[index]++;
    }

    for (final parcel in parcels) {
      addEvent(parcel.forInventoryAt, received);
      addEvent(parcel.inventoryScannedAt, scanned);
    }
    final peak = [...received, ...scanned]
        .fold<int>(0, (value, count) => count > value ? count : value);
    final receivedTotal = received.fold<int>(0, (sum, value) => sum + value);
    final scannedTotal = scanned.fold<int>(0, (sum, value) => sum + value);
    final hasEvents = receivedTotal + scannedTotal > 0;
    final accessibility = [
      for (var i = 0; i < days.length; i++)
        '${_weekday(days[i].weekday)}: received ${received[i]}, scanned ${scanned[i]}',
    ].join(', ');

    return Semantics(
      label: loading && parcels.isEmpty
          ? 'Loading daily parcel volume'
          : 'Daily parcel volume for the last seven days. $accessibility',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Daily parcel volume',
                    style: TextStyle(
                        color: Color(0xFF33483B),
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text('Parcels received and scanned',
                    style: TextStyle(color: Color(0xFF748178), fontSize: 10)),
              ])),
          _VolumeLegend(
              label: 'Received',
              total: receivedTotal,
              color: const Color(0xFF8BBDB5)),
          const SizedBox(width: 10),
          _VolumeLegend(
              label: 'Scanned',
              total: scannedTotal,
              color: DriverColors.primary),
        ]),
        const SizedBox(height: 12),
        if (loading && parcels.isEmpty)
          const SizedBox(
              height: 76,
              child: Center(
                  child: LinearProgressIndicator(
                      minHeight: 2,
                      color: DriverColors.primary,
                      backgroundColor: Color(0xFFDDE8E4))))
        else if (!hasEvents)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 17),
            child: Text('No handovers or scans in the past seven days.',
                style: TextStyle(color: Color(0xFF748178), fontSize: 11)),
          )
        else ...[
          SizedBox(
            height: 74,
            width: double.infinity,
            child: CustomPaint(
              painter: _VolumeLinePainter(
                  received: received, scanned: scanned, peak: peak),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 5),
          Row(children: [
            for (final day in days)
              Expanded(
                  child: Center(
                      child: Text(_weekday(day.weekday),
                          style: const TextStyle(
                              color: Color(0xFF77837A),
                              fontSize: 9,
                              fontWeight: FontWeight.w600))))
          ]),
        ],
      ]),
    );
  }
}

class _VolumeLegend extends StatelessWidget {
  const _VolumeLegend(
      {required this.label, required this.total, required this.color});
  final String label;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 3,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text('$label $total',
            style: const TextStyle(
                color: Color(0xFF66766B),
                fontSize: 9,
                fontWeight: FontWeight.w600)),
      ]);
}

class _VolumeLinePainter extends CustomPainter {
  const _VolumeLinePainter(
      {required this.received, required this.scanned, required this.peak});
  final List<int> received;
  final List<int> scanned;
  final int peak;

  @override
  void paint(Canvas canvas, Size size) {
    const insetX = 6.0;
    const insetY = 7.0;
    final chart = Rect.fromLTRB(
        insetX, insetY, size.width - insetX, size.height - insetY);
    final gridPaint = Paint()
      ..color = const Color(0xFFDDE3DC)
      ..strokeWidth = 1;
    for (var row = 0; row < 3; row++) {
      final y = chart.top + chart.height * row / 2;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    Path seriesPath(List<int> values) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = chart.left + chart.width * i / (values.length - 1);
        final y =
            chart.bottom - chart.height * values[i] / (peak == 0 ? 1 : peak);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    void drawSeries(List<int> values, Color color, {required bool dashed}) {
      final path = seriesPath(values);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (dashed) {
        for (final metric in path.computeMetrics()) {
          var distance = 0.0;
          while (distance < metric.length) {
            final end = (distance + 5).clamp(0.0, metric.length).toDouble();
            canvas.drawPath(metric.extractPath(distance, end), paint);
            distance += 8;
          }
        }
      } else {
        canvas.drawPath(path, paint);
      }
      final pointPaint = Paint()..color = color;
      for (var i = 0; i < values.length; i++) {
        final x = chart.left + chart.width * i / (values.length - 1);
        final y =
            chart.bottom - chart.height * values[i] / (peak == 0 ? 1 : peak);
        canvas.drawCircle(Offset(x, y), 2.4, pointPaint);
      }
    }

    drawSeries(received, const Color(0xFF8BBDB5), dashed: true);
    drawSeries(scanned, DriverColors.primary, dashed: false);
  }

  @override
  bool shouldRepaint(covariant _VolumeLinePainter oldDelegate) =>
      oldDelegate.peak != peak ||
      !listEquals(oldDelegate.received, received) ||
      !listEquals(oldDelegate.scanned, scanned);
}

String _weekday(int weekday) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

class _ParcelSkeleton extends StatelessWidget {
  const _ParcelSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFDDE2DB)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _skeletonLine(width: 142, height: 13),
            const Spacer(),
            _skeletonLine(width: 70, height: 9),
          ]),
          const SizedBox(height: 9),
          _skeletonLine(width: 116, height: 10),
          const SizedBox(height: 8),
          _skeletonLine(width: 188, height: 8),
        ]),
      );

  static Widget _skeletonLine(
          {required double width, required double height}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
            color: const Color(0xFFE3E7E0),
            borderRadius: BorderRadius.circular(2)),
      );
}

class _QueueSectionHeading extends StatelessWidget {
  const _QueueSectionHeading(
      {required this.title,
      required this.count,
      required this.color,
      required this.icon});
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Expanded(
            child: Text(title,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .1))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
              color: color.withOpacity(.09),
              borderRadius: BorderRadius.circular(10)),
          child: Text('$count',
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        ),
      ]);
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

  String _relativeAge(DateTime? date) {
    if (date == null) return '';
    final elapsed = DateTime.now().difference(date.toLocal());
    if (elapsed.inMinutes < 1) return 'JUST NOW';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} MIN AGO';
    if (elapsed.inHours < 24) return '${elapsed.inHours} HR AGO';
    return '${elapsed.inDays} D AGO';
  }

  IconData _originIcon(InventoryOrigin origin) => switch (origin) {
        InventoryOrigin.pickup => parcel.isReturn
            ? Icons.keyboard_return_rounded
            : Icons.storefront_outlined,
        InventoryOrigin.transferDeparture => Icons.north_east_rounded,
        InventoryOrigin.transferReceipt => Icons.south_west_rounded,
        InventoryOrigin.unknown => Icons.inventory_2_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final badgeColor =
        pendingStyle ? DriverColors.warning : DriverColors.success;
    final badgeLabel =
        pendingStyle ? _relativeAge(parcel.forInventoryAt) : 'SCANNED';
    final timeLabel = pendingStyle
        ? _formatDate(parcel.forInventoryAt)
        : _formatDate(parcel.inventoryScannedAt);

    final routeLabel = _originLabel(parcel.origin);
    final destination = parcel.transferToCompanyName ?? parcel.hubName;
    final party = parcel.isReturn
        ? (parcel.buyer.name ?? 'Buyer return')
        : (parcel.seller.shopName ??
            parcel.seller.name ??
            parcel.buyer.name ??
            'Parcel handover');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
                color: pendingStyle
                    ? const Color(0xFFD9E1D9)
                    : const Color(0xFFE1E5DF)),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: badgeColor.withOpacity(.10),
                    borderRadius: BorderRadius.circular(9)),
                child: Icon(_originIcon(parcel.origin),
                    color: badgeColor, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              routeLabel.isEmpty
                                  ? 'PARCEL HANDOVER'
                                  : routeLabel.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: badgeColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .65))),
                      if (badgeLabel.isNotEmpty)
                        Text(badgeLabel,
                            style: TextStyle(
                                color: badgeColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .35)),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      parcel.trackingNumber ?? parcel.orderNumber ?? 'Parcel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: Color(0xFF172923),
                          letterSpacing: -.25),
                    ),
                  ])),
            ]),
            const SizedBox(height: 11),
            Text(
              destination == null ? party : '$party → $destination',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF33483B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.local_shipping_outlined,
                  size: 14, color: const Color(0xFF748178)),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(
                parcel.courier?.fullName ??
                    (pendingStyle
                        ? 'Courier not recorded'
                        : 'Handled by hub team'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF66766B),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600),
              )),
              const SizedBox(width: 8),
              Text(
                  '${parcel.items.length} item${parcel.items.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: Color(0xFF66766B),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600)),
              if (parcel.isReturn) ...[
                const SizedBox(width: 8),
                const DriverReturnChip(),
              ],
            ]),
            if (pendingStyle) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFFE5E9E3)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: Text(
                        timeLabel.isEmpty
                            ? 'Ready for verification'
                            : 'Received ${_formatDate(parcel.forInventoryAt)}',
                        style: const TextStyle(
                            color: Color(0xFF748178),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                const Icon(Icons.qr_code_scanner_rounded,
                    size: 16, color: DriverColors.primary),
                const SizedBox(width: 5),
                const Text('Review & scan',
                    style: TextStyle(
                        color: DriverColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded,
                    size: 17, color: DriverColors.primary),
              ]),
            ] else ...[
              const SizedBox(height: 9),
              Row(children: [
                Expanded(
                    child: Text(
                        timeLabel.isEmpty
                            ? 'Scan recorded'
                            : 'Scanned $timeLabel',
                        style: const TextStyle(
                            color: Color(0xFF748178),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600))),
                Text('by ${parcel.inventoryScannedBy?.fullName ?? 'hub team'}',
                    style: const TextStyle(
                        color: Color(0xFF748178),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded,
                    size: 17, color: Color(0xFF8B968D)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
