import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/remittance_api_service.dart';
import '../driver/driver_theme.dart';
import 'remittance_format.dart';

class RemittanceDetailScreen extends StatefulWidget {
  const RemittanceDetailScreen(
      {super.key,
      required this.api,
      required this.id,
      required this.statement});
  final RemittanceApiService api;
  final String id;
  final bool statement;
  @override
  State<RemittanceDetailScreen> createState() => _RemittanceDetailScreenState();
}

class _RemittanceDetailScreenState extends State<RemittanceDetailScreen> {
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  List<Map<String, dynamic>> _rows = [];
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
      final RemittancePageData records;
      if (widget.statement) {
        final result = await widget.api.statement(widget.id, page: _page);
        records = RemittancePageData.fromJson({'data': result['items']});
      } else {
        records = await widget.api.history(widget.id, page: _page);
      }
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

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: DriverColors.background,
        appBar: AppBar(
            title: Text(widget.statement
                ? 'Statement orders'
                : 'Verification history')),
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
                        const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No recorded entries yet.'))
                      else
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
