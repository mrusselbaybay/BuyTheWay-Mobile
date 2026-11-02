import 'package:flutter/material.dart';
import 'dart:convert';

import '../../services/api_service.dart';
import '../../services/poller.dart';
import '../../services/remittance_api_service.dart';
import '../driver/driver_theme.dart';
import 'remittance_format.dart';

class RemittanceDetailScreen extends StatefulWidget {
  const RemittanceDetailScreen(
      {super.key,
      required this.api,
      required this.id,
      required this.statement,
      this.historyTitle});
  final RemittanceApiService api;
  final String id;
  final bool statement;
  final String? historyTitle;
  @override
  State<RemittanceDetailScreen> createState() => _RemittanceDetailScreenState();
}

class _RemittanceDetailScreenState extends State<RemittanceDetailScreen> {
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  List<Map<String, dynamic>> _rows = [];
  ModalRoute<dynamic>? _route;

  /// Silent 60s refresh of the page being viewed; only rebuilds on a change.
  late final Poller _poller = Poller(
    (isActive) async {
      final page = _page;
      final records = await _fetch();
      if (!isActive() || !mounted || _loading || page != _page) return;
      if (jsonEncode(records.items, toEncodable: (o) => '$o') ==
              jsonEncode(_rows, toEncodable: (o) => '$o') &&
          records.lastPage == _lastPage) return;
      setState(() {
        _rows = records.items;
        _lastPage = records.lastPage;
      });
    },
    interval: const Duration(seconds: 60),
    shouldSkip: () => _loading || _route?.isCurrent == false,
  );

  Future<RemittancePageData> _fetch() async {
    if (widget.statement) {
      final result = await widget.api.statement(widget.id, page: _page);
      return RemittancePageData.fromJson({'data': result['items']});
    }
    return widget.api.history(widget.id, page: _page);
  }

  @override
  void initState() {
    super.initState();
    _load();
    _poller.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _poller.stop();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _fetch();
      if (mounted) {
        setState(() {
          _rows = records.items;
          _lastPage = records.lastPage;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException
              ? e.message
              : 'Could not load details. Please retry.';
          _loading = false;
        });
      }
    }
  }

  String _eventTitle(dynamic action) {
    final key = '${action ?? ''}'.toLowerCase();
    return switch (key) {
      'created' ||
      'submitted' ||
      'receipt_submitted' ||
      'proof_submitted' =>
        'Receipt submitted',
      'verified' || 'payment_verified' || 'confirmed' => 'Payment verified',
      'rejected' || 'payment_rejected' => 'Receipt rejected',
      'disputed' || 'dispute_created' => 'Payment disputed',
      'resolved' || 'dispute_resolved' => 'Dispute resolved',
      'paid' || 'payment_recorded' => 'Payment recorded',
      'updated' => 'Details updated',
      _ => remittanceLabel(action),
    };
  }

  Color _eventColor(dynamic action) {
    final key = '${action ?? ''}'.toLowerCase();
    if (key.contains('reject') || key.contains('disput'))
      return DriverColors.error;
    if (key.contains('verif') || key.contains('confirm') || key == 'paid')
      return DriverColors.success;
    if (key.contains('submit') || key == 'created') return DriverColors.primary;
    return DriverColors.textSecondary;
  }

  IconData _eventIcon(dynamic action) {
    final key = '${action ?? ''}'.toLowerCase();
    if (key.contains('reject')) return Icons.close_rounded;
    if (key.contains('disput')) return Icons.flag_outlined;
    if (key.contains('verif') || key.contains('confirm') || key == 'paid') {
      return Icons.check_rounded;
    }
    if (key.contains('submit') || key == 'created')
      return Icons.upload_file_rounded;
    return Icons.history_rounded;
  }

  String _eventDate(dynamic value) {
    final raw = '${value ?? ''}';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw.replaceFirst('T', ' ').split('.').first;
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
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.hour < 12 ? 'AM' : 'PM';
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year} · $hour:$minute $period';
  }

  Widget _historyEntry(Map<String, dynamic> row, int index, int count) {
    final data = row['data'] as Map? ?? const {};
    final action = row['action'];
    final accent = _eventColor(action);
    final amount = data['amount_cents'];
    final before = data['before_cents'];
    final after = data['after_cents'];
    final note = data['note'] ?? data['reason'] ?? data['resolution'];
    final actor =
        remittanceName(row).isEmpty ? 'System update' : remittanceName(row);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 34,
        child: Column(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.11),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withOpacity(0.3)),
            ),
            child: Icon(_eventIcon(action), size: 15, color: accent),
          ),
          if (index < count - 1)
            SizedBox(
              height: 12,
              child: Center(
                child: Container(width: 1, color: DriverColors.border),
              ),
            ),
        ]),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DriverColors.border),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Text(_eventTitle(action),
                      style: const TextStyle(
                          color: DriverColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800))),
              if (amount != null)
                Text(remittanceMoney(amount),
                    style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            Text(_eventDate(row['created_at']),
                style: const TextStyle(
                    color: DriverColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 7),
            Row(children: [
              const Icon(Icons.person_outline_rounded,
                  size: 14, color: DriverColors.textSecondary),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(actor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: DriverColors.textSecondary, fontSize: 11.5))),
            ]),
            if (before != null && after != null) ...[
              const SizedBox(height: 9),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                    color: DriverColors.background,
                    borderRadius: BorderRadius.circular(9)),
                child: Row(children: [
                  const Text('Balance',
                      style: TextStyle(
                          color: DriverColors.textSecondary, fontSize: 10.5)),
                  const Spacer(),
                  Text(remittanceMoney(before),
                      style: const TextStyle(
                          color: DriverColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 7),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 14, color: DriverColors.textSecondary)),
                  Text(remittanceMoney(after),
                      style: const TextStyle(
                          color: DriverColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
            ],
            if (row['reference'] != null || data['reference'] != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                  'Reference: ${row['reference'] ?? data['reference']}',
                  style: const TextStyle(
                      color: DriverColors.textSecondary, fontSize: 11.5)),
            ],
            if (note != null && '$note'.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: accent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(9)),
                child: Text('$note',
                    style: const TextStyle(
                        color: DriverColors.textPrimary,
                        fontSize: 11.5,
                        height: 1.35)),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: DriverColors.background,
        appBar: AppBar(
            title: Text(widget.statement
                ? 'Statement orders'
                : widget.historyTitle ?? 'Verification history')),
        body: SafeArea(
            child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (_loading)
                        const Center(
                            child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator()))
                      else if (_error != null)
                        Column(children: [
                          Text(_error!),
                          TextButton(
                              onPressed: _load, child: const Text('Retry'))
                        ])
                      else if (_rows.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 22),
                          padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: DriverColors.border),
                          ),
                          child: Column(children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: const BoxDecoration(
                                  color: DriverColors.primarySurface,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.history_rounded,
                                  color: DriverColors.primary, size: 25),
                            ),
                            const SizedBox(height: 12),
                            Text(
                                widget.statement
                                    ? 'No orders in this statement yet'
                                    : 'No history recorded yet',
                                style: const TextStyle(
                                    color: DriverColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Text(
                                widget.statement
                                    ? 'Order charges included in this payout statement will appear here.'
                                    : 'Updates will appear here as this receipt moves through review.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: DriverColors.textSecondary,
                                    fontSize: 12,
                                    height: 1.4)),
                          ]),
                        )
                      else if (!widget.statement) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 18),
                          padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(13)),
                              child: const Icon(Icons.receipt_long_rounded,
                                  color: Colors.white, size: 21),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      widget.historyTitle ??
                                          'Verification history',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  Text(
                                      '${_rows.length} ${_rows.length == 1 ? 'event' : 'events'} · Most recent first',
                                      style: const TextStyle(
                                          color: Color(0xFFD5F4EF),
                                          fontSize: 11.5)),
                                ])),
                            const Icon(Icons.autorenew_rounded,
                                color: Color(0xFFD5F4EF), size: 19),
                          ]),
                        ),
                        ..._rows.asMap().entries.map((entry) => _historyEntry(
                            entry.value, entry.key, _rows.length)),
                      ] else
                        ..._rows.map((row) {
                          final data = row['data'] as Map? ?? const {};
                          return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: widget.statement
                                          ? [
                                              Text(remittanceOrder(row),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800)),
                                              Text(
                                                  remittanceLabel(row['kind'])),
                                              if (row['company'] != null)
                                                Text(remittanceName(
                                                    row['company'])),
                                              if (row['leg_id'] != null)
                                                Text(
                                                    'Delivery leg: ${row['leg_id']}',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: DriverColors
                                                            .textSecondary)),
                                              Text(
                                                  'Charge: ${remittanceMoney(row['amount_cents'])}'),
                                              Text(
                                                  'Verified payment: ${remittanceMoney(row['paid_cents'])}'),
                                              Text(remittanceLabel(
                                                  row['status'])),
                                            ]
                                          : [
                                              Text(
                                                  remittanceLabel(
                                                      row['action']),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800)),
                                              Text('${row['created_at'] ?? ''}'
                                                  .replaceFirst('T', ' ')
                                                  .split('.')
                                                  .first),
                                              Text(remittanceName(row).isEmpty
                                                  ? 'System'
                                                  : remittanceName(row)),
                                              if (data['amount_cents'] != null)
                                                Text(remittanceMoney(
                                                    data['amount_cents'])),
                                              if (data['before_cents'] != null)
                                                Text(
                                                    '${remittanceMoney(data['before_cents'])} → ${remittanceMoney(data['after_cents'])}'),
                                              if (data['reference'] != null)
                                                SelectableText(
                                                    'Reference: ${data['reference']}'),
                                              if (data['note'] != null ||
                                                  data['reason'] != null ||
                                                  data['resolution'] != null)
                                                Text(
                                                    '${data['note'] ?? data['reason'] ?? data['resolution']}'),
                                            ])));
                        }),
                      if (!_loading && _error == null && _lastPage > 1)
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                  onPressed: _page > 1
                                      ? () {
                                          _page--;
                                          _load();
                                        }
                                      : null,
                                  child: const Text('Previous')),
                              Text('Page $_page of $_lastPage'),
                              TextButton(
                                  onPressed: _page < _lastPage
                                      ? () {
                                          _page++;
                                          _load();
                                        }
                                      : null,
                                  child: const Text('Next'))
                            ]),
                    ]))),
      );
}
