import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/api_service.dart';
import '../driver_models.dart';
import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';

enum HistoryDateFilter { all, today, yesterday, week, month }

enum HistorySort { date, duration }

/// "Archive Intelligence" redesign of the History screen — a searchable,
/// sortable record of every parcel this driver has actually delivered,
/// with a sticky stats footer that updates live as filters change.
///
/// Backed by the same real `GET /api/driver/deliveries` fetch the
/// Deliveries tab already loads into DriverShell's `_assignedDeliveries` —
/// not the module's old hardcoded mock list. This screen just filters that
/// shared list down to the delivered ones ([AssignedDeliveryStatus.delivered])
/// and presents them as a completed-run archive; [onRefresh] re-hits the
/// same endpoint DriverShell already wires up for the Deliveries tab, so
/// pulling to refresh here keeps both screens in sync.
///
/// There's no on-time/late verdict here (unlike an earlier version of this
/// screen) — the API has no ETA/SLA baseline to compare against, so this
/// only shows real, known facts: when a run was delivered and, when both
/// timestamps are on file, how long it took from pickup to drop-off.
class DriverHistoryScreen extends StatefulWidget {
  final List<AssignedDelivery> deliveries;
  final String accessToken;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  const DriverHistoryScreen({
    super.key,
    required this.deliveries,
    required this.accessToken,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  HistoryDateFilter _dateFilter = HistoryDateFilter.all;
  HistorySort _sort = HistorySort.date;
  final _searchController = TextEditingController();
  String _search = '';
  DateTimeRange? _customRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AssignedDelivery> get _completed => widget.deliveries.where((d) => d.status == AssignedDeliveryStatus.delivered).toList();

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool _matchesDate(AssignedDelivery d) {
    final at = d.deliveredAt;
    if (at == null) return _dateFilter == HistoryDateFilter.all && _customRange == null;
    final now = DateTime.now();
    switch (_dateFilter) {
      case HistoryDateFilter.all:
        final range = _customRange;
        if (range == null) return true;
        final day = DateTime(at.year, at.month, at.day);
        return !day.isBefore(range.start) && !day.isAfter(range.end);
      case HistoryDateFilter.today:
        return _sameDay(at, now);
      case HistoryDateFilter.yesterday:
        return _sameDay(at, now.subtract(const Duration(days: 1)));
      case HistoryDateFilter.week:
        return now.difference(at).inDays < 7;
      case HistoryDateFilter.month:
        return now.difference(at).inDays < 30;
    }
  }

  int? _durationMinutes(AssignedDelivery d) {
    final start = d.handedOffAt ?? d.assignedAt;
    final end = d.deliveredAt;
    if (start == null || end == null) return null;
    return end.difference(start).inMinutes;
  }

  List<AssignedDelivery> get _filtered {
    final list = _completed.where((d) {
      if (!_matchesDate(d)) return false;
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toLowerCase();
        if (!d.customerName.toLowerCase().contains(q) &&
            !d.orderNumber.toLowerCase().contains(q) &&
            !(d.trackingNumber ?? '').toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (_sort) {
      case HistorySort.date:
        list.sort((a, b) => (b.deliveredAt ?? DateTime(0)).compareTo(a.deliveredAt ?? DateTime(0)));
      case HistorySort.duration:
        list.sort((a, b) => (_durationMinutes(b) ?? -1).compareTo(_durationMinutes(a) ?? -1));
    }
    return list;
  }

  int get _totalParcels => _filtered.fold(0, (s, d) => s + d.parcels);

  double? get _avgMinutes {
    final durations = _filtered.map(_durationMinutes).whereType<int>().toList();
    if (durations.isEmpty) return null;
    return durations.fold<int>(0, (s, m) => s + m) / durations.length;
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: _customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: DriverColors.primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _dateFilter = HistoryDateFilter.all;
    });
  }

  void _setDateFilter(HistoryDateFilter f) {
    HapticFeedback.selectionClick();
    setState(() {
      _dateFilter = f;
      _customRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return Scaffold(
      backgroundColor: DriverColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DriverGradientHeader(
              title: 'History',
              subtitle: 'Your delivery archive',
              onBack: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: DriverColors.primary.withOpacity(0.35))),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _search = v),
                            decoration: const InputDecoration(
                              hintText: 'Search by order ID or customer',
                              prefixIcon: Icon(Icons.search_rounded, size: 20, color: DriverColors.primary),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SortButton(sort: _sort, onChanged: (s) => setState(() => _sort = s)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _chip('All time', _dateFilter == HistoryDateFilter.all && _customRange == null, () => _setDateFilter(HistoryDateFilter.all)),
                        const SizedBox(width: 8),
                        _chip('Today', _dateFilter == HistoryDateFilter.today, () => _setDateFilter(HistoryDateFilter.today)),
                        const SizedBox(width: 8),
                        _chip('Yesterday', _dateFilter == HistoryDateFilter.yesterday, () => _setDateFilter(HistoryDateFilter.yesterday)),
                        const SizedBox(width: 8),
                        _chip('This week', _dateFilter == HistoryDateFilter.week, () => _setDateFilter(HistoryDateFilter.week)),
                        const SizedBox(width: 8),
                        _chip('This month', _dateFilter == HistoryDateFilter.month, () => _setDateFilter(HistoryDateFilter.month)),
                        const SizedBox(width: 8),
                        _chip(
                          _customRange == null ? 'Custom range' : '${_fmtShort(_customRange!.start)}–${_fmtShort(_customRange!.end)}',
                          _customRange != null,
                          _pickCustomRange,
                          icon: Icons.date_range_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _body(results)),
            if (widget.error == null) _StatsFooter(count: results.length, totalParcels: _totalParcels, avgMinutes: _avgMinutes),
          ],
        ),
      ),
    );
  }

  Widget _body(List<AssignedDelivery> results) {
    if (widget.error != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(color: DriverColors.errorSurface, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.wifi_off_rounded, color: DriverColors.error, size: 24),
                ),
                const SizedBox(height: 12),
                const Text('Couldn\'t load history', style: DriverText.sectionTitle, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(widget.error!, style: DriverText.caption, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: widget.onRefresh,
                  style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (widget.loading && widget.deliveries.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: 3,
        itemBuilder: (context, i) => const Padding(padding: EdgeInsets.only(bottom: 10), child: DriverShimmerBox(height: 96, radius: 14)),
      );
    }

    return RefreshIndicator(
      color: DriverColors.primary,
      onRefresh: widget.onRefresh,
      child: results.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                DriverEmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No deliveries found',
                  subtitle: widget.deliveries.isEmpty ? 'Parcels you deliver will show up here once completed.' : 'Try a different filter or search term.',
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: results.length,
              itemBuilder: (context, i) => _HistoryCard(entry: results[i], accessToken: widget.accessToken, durationMinutes: _durationMinutes(results[i])),
            ),
    );
  }

  String _fmtShort(DateTime d) => '${d.month}/${d.day}';

  Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: selected ? DriverColors.primary : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? Colors.transparent : DriverColors.border)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: selected ? Colors.white : DriverColors.textSecondary), const SizedBox(width: 4)],
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : DriverColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final HistorySort sort;
  final ValueChanged<HistorySort> onChanged;
  const _SortButton({required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<HistorySort>(
      initialValue: sort,
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(value: HistorySort.date, child: Text('By date')),
        PopupMenuItem(value: HistorySort.duration, child: Text('By duration')),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: DriverColors.primary.withOpacity(0.35))),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert_rounded, size: 18, color: DriverColors.primary),
            SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: DriverColors.primary),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final AssignedDelivery entry;
  final String accessToken;
  final int? durationMinutes;
  const _HistoryCard({required this.entry, required this.accessToken, required this.durationMinutes});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  final ApiService _api = ApiService();
  bool _expanded = false;
  bool _openingPhoto = false;

  String _formatDate(DateTime? d) {
    if (d == null) return 'Unknown time';
    final local = d.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day} · $h:$m $period';
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    try {
      HapticFeedback.lightImpact();
      if (!await launchUrl(Uri(scheme: 'tel', path: phone.trim()))) throw Exception('launch failed');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start a call. Please dial manually.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _openMap(String address) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': address});
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw Exception('launch failed');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _viewPhoto(bool pickup) async {
    setState(() => _openingPhoto = true);
    try {
      final response = pickup
          ? await _api.getPickupPhoto(parcelAssignmentId: widget.entry.id, accessToken: widget.accessToken)
          : await _api.getDeliveryPhoto(parcelAssignmentId: widget.entry.id, accessToken: widget.accessToken);
      final url = response['url'] as String?;
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) throw Exception('launch failed');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the ${pickup ? 'pickup' : 'delivery'} photo.'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _openingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final duration = widget.durationMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: DriverColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _expanded = !_expanded);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 8), decoration: const BoxDecoration(color: DriverColors.success, shape: BoxShape.circle)),
                  Expanded(child: Text(e.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
                  const DriverStatusBadge(label: 'Delivered', color: DriverColors.success, icon: Icons.check_circle_rounded),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text(_formatDate(e.deliveredAt), style: DriverText.caption),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 16),
                  Text('#${e.orderNumber}', style: DriverText.caption),
                  const Spacer(),
                  if (duration != null)
                    Text(_formatDuration(duration), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: DriverColors.primaryDark)),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10, left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            Row(children: [const Icon(Icons.storefront_rounded, size: 13, color: DriverColors.textSecondary), const SizedBox(width: 6), Expanded(child: Text(e.pickupLabel, style: DriverText.body))]),
                            const SizedBox(height: 4),
                            Row(children: [const Icon(Icons.flag_rounded, size: 13, color: DriverColors.textSecondary), const SizedBox(width: 6), Expanded(child: Text(e.dropoffLabel, style: DriverText.body))]),
                            const SizedBox(height: 8),
                            DriverDispatchChip(label: e.dispatchedByLabel),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (e.customerContactNo != null)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _call(e.customerContactNo),
                                      icon: const Icon(Icons.call_outlined, size: 15),
                                      label: const Text('Contact customer'),
                                      style: OutlinedButton.styleFrom(foregroundColor: DriverColors.primaryDark, side: BorderSide(color: DriverColors.primary.withOpacity(0.4)), padding: const EdgeInsets.symmetric(vertical: 10)),
                                    ),
                                  ),
                                if (e.customerContactNo != null) const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _openMap(e.dropoffLabel),
                                    icon: const Icon(Icons.map_outlined, size: 15),
                                    label: const Text('View route'),
                                    style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                                  ),
                                ),
                              ],
                            ),
                            if (e.hasPickupPhoto || e.hasDeliveryPhoto) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (e.hasPickupPhoto)
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _openingPhoto ? null : () => _viewPhoto(true),
                                        icon: const Icon(Icons.image_outlined, size: 15),
                                        label: const Text('Pickup photo'),
                                        style: OutlinedButton.styleFrom(foregroundColor: DriverColors.primaryDark, side: BorderSide(color: DriverColors.primary.withOpacity(0.4)), padding: const EdgeInsets.symmetric(vertical: 10)),
                                      ),
                                    ),
                                  if (e.hasPickupPhoto && e.hasDeliveryPhoto) const SizedBox(width: 8),
                                  if (e.hasDeliveryPhoto)
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _openingPhoto ? null : () => _viewPhoto(false),
                                        icon: const Icon(Icons.image_outlined, size: 15),
                                        label: const Text('Delivery photo'),
                                        style: OutlinedButton.styleFrom(foregroundColor: DriverColors.primaryDark, side: BorderSide(color: DriverColors.primary.withOpacity(0.4)), padding: const EdgeInsets.symmetric(vertical: 10)),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsFooter extends StatelessWidget {
  final int count;
  final int totalParcels;
  final double? avgMinutes;

  const _StatsFooter({required this.count, required this.totalParcels, required this.avgMinutes});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3))],
        ),
        child: Row(
          children: [
            _stat('$count', 'Deliveries'),
            _divider(),
            _stat('$totalParcels', 'Parcels'),
            _divider(),
            _stat(avgMinutes == null ? '—' : '${avgMinutes!.round()}m', 'Avg. time'),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: DriverColors.textPrimary)),
          Text(label, style: DriverText.caption),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: DriverColors.border);
}
