import 'package:flutter/material.dart';

import '../../../services/remittance_api_service.dart';
import '../../remittances/remittances_screen.dart';

enum _Range { week, month, year }

class CourierEarningsScreen extends StatefulWidget {
  const CourierEarningsScreen({super.key, required this.accessToken});
  final String accessToken;
  @override
  State<CourierEarningsScreen> createState() => _CourierEarningsScreenState();
}

class _CourierEarningsScreenState extends State<CourierEarningsScreen> {
  static const _teal = Color(0xFF0D9488);
  static const _ink = Color(0xFF172B3A);
  late final _api = RemittanceApiService(
      accessToken: widget.accessToken, role: RemittanceRole.courier);
  _Range _range = _Range.week;
  List<Map<String, dynamic>> _ledger = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  DateTime get _start {
    final now = DateTime.now();
    return switch (_range) {
      _Range.week => DateTime(now.year, now.month, now.day - now.weekday + 1),
      _Range.month => DateTime(now.year, now.month),
      _Range.year => DateTime(now.year),
    };
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = <Map<String, dynamic>>[];
      var page = 1, lastPage = 1;
      while (page <= lastPage) {
        final result = await _api.earningsPage(page: page);
        lastPage = result.lastPage;
        rows.addAll(result.items);
        final dates = result.items
            .map(
                (r) => DateTime.tryParse('${r['created_at'] ?? ''}')?.toLocal())
            .whereType<DateTime>();
        // The ledger is newest first, so stop after reading through this period.
        if (dates.isNotEmpty &&
            dates.reduce((a, b) => a.isBefore(b) ? a : b).isBefore(_start)) {
          break;
        }
        page++;
      }
      if (!mounted) return;
      setState(() {
        _ledger = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int _cents(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  List<Map<String, dynamic>> get _rows => _ledger.where((row) {
        if ('${row['status'] ?? ''}'.toLowerCase() == 'void') return false;
        final at = DateTime.tryParse('${row['created_at'] ?? ''}')?.toLocal();
        return at != null &&
            !at.isBefore(_start) &&
            !at.isAfter(DateTime.now());
      }).toList();
  int get _earned => _rows.fold(0, (n, r) => n + _cents(r['amount_cents']));
  int get _awaiting => _rows.fold(0, (n, r) {
        final s = '${r['status'] ?? ''}'.toLowerCase();
        return n +
            (s == 'pending' || s == 'available'
                ? _cents(r['remaining_cents'])
                : 0);
      });
  String _money(int cents) => '₱${(cents / 100).toStringAsFixed(2)}';
  String get _rangeLabel => switch (_range) {
        _Range.week => 'this week',
        _Range.month => 'this month',
        _Range.year => 'this year'
      };

  List<_Bucket> get _buckets {
    final now = DateTime.now();
    final labels = switch (_range) {
      _Range.week => const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
      _Range.month => const ['W1', 'W2', 'W3', 'W4', 'W5'],
      _Range.year => const [
          'J',
          'F',
          'M',
          'A',
          'M',
          'J',
          'J',
          'A',
          'S',
          'O',
          'N',
          'D'
        ],
    };
    final values = List<int>.filled(labels.length, 0);
    for (final row in _rows) {
      final at = DateTime.parse('${row['created_at']}').toLocal();
      final i = switch (_range) {
        _Range.week => at.weekday - 1,
        _Range.month => ((at.day - 1) ~/ 7).clamp(0, 4),
        _Range.year => at.month - 1,
      };
      values[i] += _cents(row['amount_cents']);
    }
    return List.generate(labels.length, (i) {
      final current = switch (_range) {
        _Range.week => now.weekday - 1 == i,
        _Range.month => (now.day - 1) ~/ 7 == i,
        _Range.year => now.month - 1 == i,
      };
      return _Bucket(labels[i], values[i], current);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F8FA),
        appBar: AppBar(
          title: const Text('Earnings',
              style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
          backgroundColor: const Color(0xFFF5F8FA),
          foregroundColor: _ink,
          elevation: 0,
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => RemittancesScreen(
                    accessToken: widget.accessToken,
                    role: RemittanceRole.courier,
                  ),
                ));
              },
              icon: const Icon(Icons.currency_exchange_rounded, size: 17),
              label: const Text('Remittances'),
            ),
            IconButton(
                onPressed: _load,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded))
          ],
        ),
        body: RefreshIndicator(
          color: _teal,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
            children: [
              _totalCard(),
              const SizedBox(height: 12),
              _awaitingCard(),
              const SizedBox(height: 24),
              Row(children: [
                const Expanded(
                    child: Text('Earnings over time',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _ink))),
                _rangePicker(),
              ]),
              const SizedBox(height: 12),
              _chart(),
              const SizedBox(height: 24),
              Row(children: [
                const Expanded(
                    child: Text('Completed work',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _ink))),
                Text('${_rows.length} entries',
                    style: const TextStyle(
                        color: Color(0xFF718096), fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                    padding: EdgeInsets.all(36),
                    child:
                        Center(child: CircularProgressIndicator(color: _teal)))
              else if (_error != null)
                _empty(Icons.cloud_off_outlined, 'Earnings unavailable',
                    'Check your connection, then refresh.')
              else if (_rows.isEmpty)
                _empty(
                    Icons.receipt_long_outlined,
                    'No earnings in this period',
                    'Completed pickups and deliveries will appear here.')
              else
                ..._rows.map(_earningRow),
            ],
          ),
        ),
      );

  Widget _totalCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_teal, Color(0xFF08766F)]),
            borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Total earned · $_rangeLabel',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(_loading ? '—' : _money(_earned),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Includes earnings awaiting company payout',
              style: TextStyle(color: Colors.white70, fontSize: 11.5)),
        ]),
      );

  Widget _awaitingCard() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE7EEF2)),
            borderRadius: BorderRadius.circular(15)),
        child: Row(children: [
          const Icon(Icons.hourglass_top_rounded, color: Color(0xFFB7791F)),
          const SizedBox(width: 10),
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Awaiting payout',
                    style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
                Text('Still included in total earned',
                    style: TextStyle(fontSize: 11, color: Color(0xFF718096))),
              ])),
          Text(_loading ? '—' : _money(_awaiting),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16, color: _ink)),
        ]),
      );

  Widget _rangePicker() => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: const Color(0xFFE9F3F2),
            borderRadius: BorderRadius.circular(11)),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _Range.values.map((range) {
              final selected = range == _range;
              final label = switch (range) {
                _Range.week => 'Week',
                _Range.month => 'Month',
                _Range.year => 'Year'
              };
              return Semantics(
                  button: true,
                  selected: selected,
                  child: GestureDetector(
                    onTap: () {
                      if (!selected) {
                        setState(() => _range = range);
                        _load();
                      }
                    },
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                            color: selected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? _teal
                                    : const Color(0xFF718096)))),
                  ));
            }).toList()),
      );

  Widget _chart() {
    final buckets = _buckets;
    final maxValue =
        buckets.fold<int>(0, (max, b) => b.cents > max ? b.cents : max);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE7EEF2)),
          borderRadius: BorderRadius.circular(15)),
      child: Column(children: [
        SizedBox(
            height: 108,
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: buckets.map((b) {
                  final ratio = maxValue <= 0
                      ? 0.0
                      : (b.cents / maxValue).clamp(0.0, 1.0);
                  return Expanded(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                    child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                            width: 15,
                                            height: b.cents <= 0
                                                ? 3
                                                : 10 + 72 * ratio,
                                            decoration: BoxDecoration(
                                                color: b.current
                                                    ? _teal
                                                    : const Color(0xFFB7E4DF),
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                        top: Radius.circular(
                                                            5)))))),
                                const SizedBox(height: 7),
                                Text(b.label,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: b.current
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: b.current
                                            ? _teal
                                            : const Color(0xFF8796A3))),
                              ])));
                }).toList())),
        const SizedBox(height: 8),
        Text(
            _loading
                ? 'Loading earnings…'
                : maxValue == 0
                    ? 'No completed work recorded in this period'
                    : 'Based on completed work',
            style: const TextStyle(fontSize: 11, color: Color(0xFF8796A3))),
      ]),
    );
  }

  Widget _earningRow(Map<String, dynamic> row) {
    final type = '${row['type'] ?? ''}'.toLowerCase();
    final title = switch (type) {
      'delivery' => 'Delivery completed',
      'pickup' => 'Pickup completed',
      'transfer' => 'Parcel transfer',
      'tip' => 'Tip',
      'bonus' => 'Bonus',
      'deduction' => 'Adjustment',
      _ => 'Courier earning',
    };
    final at = DateTime.tryParse('${row['created_at'] ?? ''}')?.toLocal();
    final order = row['order'] is Map
        ? (row['order'] as Map)['order_number']?.toString()
        : null;
    final amount = _cents(row['amount_cents']);
    final status = '${row['status'] ?? 'pending'}'.toLowerCase();
    final payout = status == 'paid'
        ? 'Paid'
        : status == 'available'
            ? 'Awaiting payout'
            : 'Processing';
    final color =
        status == 'paid' ? const Color(0xFF16845B) : const Color(0xFFAD7416);
    return InkWell(
      onTap: () => _showDetails(title, row, order, at, payout),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE7EEF2)),
            borderRadius: BorderRadius.circular(13)),
        child: Row(children: [
          Icon(
              type == 'pickup'
                  ? Icons.inventory_2_outlined
                  : Icons.local_shipping_outlined,
              color: _teal,
              size: 21),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink)),
                const SizedBox(height: 3),
                Text(
                    [
                      if (order != null && order.isNotEmpty) '#$order',
                      if (at != null) _date(at)
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF718096))),
                const SizedBox(height: 3),
                Text(payout,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ])),
          Text('${amount < 0 ? '−' : '+'}${_money(amount.abs())}',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: amount < 0 ? Colors.red : _ink)),
        ]),
      ),
    );
  }

  void _showDetails(String title, Map<String, dynamic> row, String? order,
      DateTime? at, String payout) {
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (context) => SafeArea(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _ink)),
                    const SizedBox(height: 16),
                    _detail(
                        'Amount earned', _money(_cents(row['amount_cents']))),
                    if (order != null) _detail('Order', '#$order'),
                    if (at != null) _detail('Completed', _date(at, time: true)),
                    _detail('Payout status', payout),
                    if (row['reference'] != null)
                      _detail('Reference', '${row['reference']}'),
                  ]),
            )));
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Color(0xFF718096)))),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w700, color: _ink))
        ]),
      );

  String _date(DateTime at, {bool time = false}) {
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
    final day = '${months[at.month - 1]} ${at.day}, ${at.year}';
    if (!time) return day;
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    return '$day · $hour:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'AM' : 'PM'}';
  }

  Widget _empty(IconData icon, String title, String subtitle) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: Column(children: [
          Icon(icon, color: const Color(0xFF94A3B8), size: 30),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF718096), fontSize: 12)),
          if (_error != null)
            TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
}

class _Bucket {
  const _Bucket(this.label, this.cents, this.current);
  final String label;
  final int cents;
  final bool current;
}
