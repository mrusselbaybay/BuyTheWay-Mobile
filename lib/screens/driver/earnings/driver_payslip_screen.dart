import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_service.dart';
import '../driver_theme.dart';

class DriverPayslipScreen extends StatefulWidget {
  const DriverPayslipScreen({super.key, required this.accessToken});
  final String accessToken;
  @override
  State<DriverPayslipScreen> createState() => _DriverPayslipScreenState();
}

class _DriverPayslipScreenState extends State<DriverPayslipScreen> {
  final _client = http.Client();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _tab = 'ledger';
  int _page = 1;
  int _lastPage = 1;
  int _generation = 0;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _rows = [];
  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${widget.accessToken}'
      };
  String _money(dynamic value) {
    final cents = (value as num?)?.toInt() ?? 0;
    final absolute = cents.abs();
    return '${cents < 0 ? '−' : ''}₱${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
  }

  String _label(dynamic value) => '$value'.replaceAll('_', ' ');
  String _date(dynamic value) => value == null ? '' : '$value'.split('T').first;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _client.close();
    super.dispose();
  }

  Future<Map<String, dynamic>> _request(String path,
      {bool post = false}) async {
    final url = Uri.parse('${ApiService.baseUrl}/courier/$path');
    final response = await (post
            ? _client.post(url, headers: _headers)
            : _client.get(url, headers: _headers))
        .timeout(const Duration(seconds: 20));
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final errors = payload['errors'];
      final message = errors is Map && errors.isNotEmpty
          ? (errors.values.first as List).first
          : payload['message'];
      throw Exception(message ?? 'Could not load earnings. Please try again.');
    }
    return payload;
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait([
        _request('earnings/summary'),
        _request('${_tab == 'ledger' ? 'earnings' : 'payouts'}?page=$_page')
      ]);
      if (!mounted || generation != _generation) return;
      final list = result[1]['data'] as Map;
      setState(() {
        _summary = Map<String, dynamic>.from(result[0]['data'] as Map);
        _rows = (list['data'] as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _lastPage = (list['last_page'] as num).toInt();
        _loading = false;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _cashout() async {
    setState(() => _busy = true);
    try {
      await _request('earnings/early-cashout', post: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Cash-out requested. Your company will review your statement.')));
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _statement(Map<String, dynamic> row) async {
    setState(() => _busy = true);
    try {
      final payload = await _request('payouts/${row['id']}');
      if (!mounted) return;
      final payout = payload['data'] as Map;
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => DraggableScrollableSheet(
                expand: false,
                initialChildSize: .65,
                maxChildSize: .9,
                builder: (_, controller) => ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(24),
                    children: [
                      Row(children: [
                        const Expanded(
                            child: Text('Payout statement',
                                style: DriverText.sectionTitle)),
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            tooltip: 'Close')
                      ]),
                      Text(
                          '${_date(payout['period_start'])} – ${_date(payout['period_end'])}'),
                      const SizedBox(height: 16),
                      ...(payout['lines'] as List).map((line) {
                        final earning = line['earning'] as Map;
                        return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_label(earning['type'])),
                            subtitle: Text(
                                '${earning['reason'] ?? earning['order']?['order_number'] ?? ''}'),
                            trailing: Text(_money(line['amount_cents'])));
                      }),
                      const Divider(),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('COD settled by payout'),
                          trailing:
                              Text('−${_money(payout['cod_offset_cents'])}')),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Net payout',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text(_money(payout['net_cents']),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                      if (payout['reference'] != null)
                        Text('Payment reference: ${payout['reference']}'),
                      const Text(
                          'Any remaining deduction or COD balance carries forward.'),
                    ]),
              ));
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final minimum = _summary['early_cashout_minimum_cents'] as num?;
    final net = (_summary['net_cents'] as num?)?.toInt() ?? 0;
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(
          title: const Text('Earnings & payouts'),
          backgroundColor: Colors.white),
      body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                const Text(
                    'Paid by your logistics company for completed tasks.',
                    style: DriverText.caption),
                const SizedBox(height: 16),
                if (_error != null)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_error!,
                                    style: const TextStyle(
                                        color: DriverColors.error)),
                                TextButton(
                                    onPressed: _loading ? null : _load,
                                    child: const Text('Retry'))
                              ]))),
                if (_loading)
                  ...List.generate(
                      4,
                      (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                              height: 68,
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12)))))
                else ...[
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    for (final entry in {
                      'pending_cents': 'Pending',
                      'available_cents': 'Available earnings',
                      'paid_cents': 'Paid',
                      'cod_owed_cents': 'COD to hand over'
                    }.entries)
                      SizedBox(
                          width: (MediaQuery.sizeOf(context).width - 44) / 2,
                          child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(entry.value,
                                        style: DriverText.caption),
                                    const SizedBox(height: 6),
                                    Text(_money(_summary[entry.key]),
                                        style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700))
                                  ]))),
                  ]),
                  const SizedBox(height: 16),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('After adjustments & COD: ${_money(net)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                if (minimum == null)
                                  const Text(
                                      'Early cash-out not enabled by your company',
                                      style: DriverText.caption)
                                else ...[
                                  Text('Minimum: ${_money(minimum)}',
                                      style: DriverText.caption),
                                  FilledButton.icon(
                                      onPressed: _busy || net < minimum
                                          ? null
                                          : _cashout,
                                      icon: const Icon(Icons
                                          .account_balance_wallet_outlined),
                                      label: Text(_busy
                                          ? 'Requesting…'
                                          : 'Request early cash-out'))
                                ],
                              ]))),
                  const SizedBox(height: 16),
                ],
                SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'ledger',
                          label: Text('Ledger'),
                          icon: Icon(Icons.receipt_long_outlined)),
                      ButtonSegment(
                          value: 'payouts',
                          label: Text('Payslips'),
                          icon: Icon(Icons.payments_outlined))
                    ],
                    selected: {
                      _tab
                    },
                    onSelectionChanged: _loading || _busy
                        ? null
                        : (values) {
                            setState(() {
                              _tab = values.first;
                              _page = 1;
                            });
                            _load();
                          }),
                const SizedBox(height: 16),
                if (!_loading && _rows.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Column(children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 36, color: DriverColors.textSecondary),
                        SizedBox(height: 12),
                        Text('No records yet', style: DriverText.sectionTitle),
                        Text(
                            'Completed tasks and company payout statements appear here.',
                            textAlign: TextAlign.center,
                            style: DriverText.caption)
                      ])),
                if (!_loading)
                  ..._rows.map((row) => Card(
                          child: ListTile(
                        onTap: _tab == 'payouts' && !_busy
                            ? () => _statement(row)
                            : null,
                        leading: Icon(
                            _tab == 'payouts'
                                ? Icons.payments_outlined
                                : Icons.local_shipping_outlined,
                            color: DriverColors.primaryDark),
                        title: Text(_tab == 'ledger'
                            ? _label(row['type'])
                            : '${_date(row['period_start'])} – ${_date(row['period_end'])}'),
                        subtitle: Text(_tab == 'ledger'
                            ? '${row['reason'] ?? row['order']?['order_number'] ?? _date(row['created_at'])}\n${_label(row['status'])}'
                            : '${_label(row['status'])}${row['reference'] == null ? '' : ' · ${row['reference']}'}'),
                        trailing: Text(
                            _money(row[_tab == 'ledger'
                                ? 'amount_cents'
                                : 'net_cents']),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ))),
                if (!_loading && _lastPage > 1)
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
                        Text('$_page / $_lastPage'),
                        TextButton(
                            onPressed: _page < _lastPage
                                ? () {
                                    _page++;
                                    _load();
                                  }
                                : null,
                            child: const Text('Next'))
                      ]),
              ])),
    );
  }
}
