import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/poller.dart';
import '../../services/remittance_api_service.dart';
import '../driver/driver_theme.dart';
import '../driver/widgets/driver_shared_widgets.dart';
import 'remittance_action_screen.dart';
import 'remittance_detail_screen.dart';
import 'remittance_format.dart';
import 'remittance_record_card.dart';

class RemittancesScreen extends StatefulWidget {
  const RemittancesScreen(
      {super.key,
      required this.accessToken,
      required this.role,
      this.orderNumber = '',
      this.revokeOnClose = false,
      this.active = true,
      this.api});
  final String accessToken;
  final RemittanceRole role;
  final String orderNumber;
  final bool revokeOnClose;

  /// False while this screen is a hidden tab: background refresh pauses.
  final bool active;
  final RemittanceApiService? api;
  @override
  State<RemittancesScreen> createState() => _RemittancesScreenState();
}

class _RemittancesScreenState extends State<RemittancesScreen> {
  late final RemittanceApiService _api = widget.api ??
      RemittanceApiService(accessToken: widget.accessToken, role: widget.role);
  late final TextEditingController _search =
      TextEditingController(text: widget.orderNumber);
  late String _tab = _seller ? 'cod' : 'collections';
  bool get _seller => widget.role == RemittanceRole.seller;
  final Set<String> _selection = {};
  Timer? _debounce;
  int _generation = 0;
  int _page = 1;
  int _lastPage = 1;
  bool _loading = true;
  String? _error;
  String _status = '';
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _rows = [];

  // ---- Background refresh ----
  // Re-reads the summary and the current tab/page/filters every 45s. Rows are
  // merged by id (unchanged rows keep their object); when the list is scrolled
  // and rows join/leave, they wait behind an "N updated" pill. While an action
  // screen (proof upload, verify, dispute) is open the poll keeps running, but
  // only to tell that screen — through [_watched] — if its record changed; the
  // form itself is never touched.
  final _scroll = ScrollController();
  ModalRoute<dynamic>? _route;
  bool _actionOpen = false;
  String? _watchedId;
  final ValueNotifier<Map<String, dynamic>?> _watched = ValueNotifier(null);
  List<Map<String, dynamic>>? _heldRows;
  int _heldLastPage = 1;

  late final Poller _poller = Poller(
    (isActive) async {
      final generation = _generation;
      final result = await Future.wait<Object>([
        _api.summary(),
        _api.records(_tab, page: _page, search: _search.text.trim(), status: _status),
      ]);
      // _load() bumps the generation: a poll that began before the user changed
      // tab/page/filter/search (or finished an action) is dropped.
      if (!isActive() || !mounted || generation != _generation || _loading) return;
      final records = result[1] as RemittancePageData;
      _mergeRemote(result[0] as Map<String, dynamic>, records.items, records.lastPage);
    },
    interval: const Duration(seconds: 45),
    shouldSkip: () => _loading || !widget.active || (_route?.isCurrent == false && !_actionOpen),
  );

  /// Seam for push/realtime (e.g. a remittance verdict notification).
  Future<void> refreshNow() => _poller.refreshNow();

  String _fp(Object? value) => jsonEncode(value, toEncodable: (o) => '$o').replaceAll(RegExp(r'"[^"]*url[^"]*":"[^"]*",?'), '');

  void _mergeRemote(Map<String, dynamic> summary, List<Map<String, dynamic>> fresh, int lastPage) {
    final summaryChanged = _fp(summary) != _fp(_summary);
    final byId = {for (final r in _rows) '${r['id']}': r};
    final sameShape = fresh.length == _rows.length && [for (var i = 0; i < fresh.length; i++) '${fresh[i]['id']}' == '${_rows[i]['id']}'].every((e) => e);
    final scrolled = _scroll.hasClients && _scroll.offset > 24;
    final hold = !sameShape && _rows.isNotEmpty && fresh.isNotEmpty && scrolled;
    final base = hold ? _rows : fresh;
    final freshById = {for (final r in fresh) '${r['id']}': r};
    final next = <Map<String, dynamic>>[];
    for (final r in base) {
      final f = hold ? freshById['${r['id']}'] : r;
      if (f == null) {
        next.add(r);
        continue;
      }
      final old = byId['${f['id']}'];
      next.add(old != null && _fp(old) == _fp(f) ? old : f);
    }
    final rowsChanged = next.length != _rows.length || [for (var i = 0; i < next.length; i++) identical(next[i], _rows[i])].any((e) => !e);
    final heldChanged = hold != (_heldRows != null) || (hold && _heldRows!.length != fresh.length);

    // Tell an open action screen whether its record moved.
    if (_watchedId != null) {
      final latest = freshById[_watchedId];
      if (_fp(latest) != _fp(_watched.value) && (latest != null || _watched.value != null)) {
        _watched.value = latest ?? const {'__missing': true};
      }
    }
    if (!summaryChanged && !rowsChanged && !heldChanged && lastPage == _lastPage) return;
    setState(() {
      if (summaryChanged) _summary = summary;
      _rows = next;
      _heldRows = hold ? fresh : null;
      _heldLastPage = lastPage;
      if (!hold) _lastPage = lastPage;
      _selection.removeWhere((id) => !next.any((r) => '${r['id']}' == id));
    });
  }

  void _applyHeld() {
    final held = _heldRows;
    if (held == null) return;
    setState(() {
      _rows = held;
      _lastPage = _heldLastPage;
      _heldRows = null;
      _selection.removeWhere((id) => !held.any((r) => '${r['id']}' == id));
    });
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Map<String, String> get _tabs => _seller
      ? const {
          'cod': 'Courier receipts',
          'gcash': 'Buyer GCash',
          'obligations': 'Balances',
          'statements': 'Statements',
          'payments': 'Payment receipts',
          'disputes': 'Disputes',
        }
      : const {
          'collections': 'COD collections',
          'cod': 'Submitted receipts',
          'earnings': 'Courier contributions',
          'payouts': 'Logistics payouts'
        };

  List<String> get _statuses => switch (_tab) {
        'collections' => [],
        'cod' || 'payments' || 'gcash' => [
            'awaiting_verification',
            'verified',
            'rejected',
            if (_tab != 'gcash') 'disputed'
          ],
        'statements' => [
            'pending',
            'partially_paid',
            'completed',
            'overdue',
            'disputed'
          ],
        'earnings' => ['pending', 'available', 'paid', 'cancelled'],
        'payouts' => ['draft', 'approved', 'paid', 'cancelled'],
        'disputes' => ['pending', 'resolved'],
        _ => ['pending', 'partially_paid', 'completed', 'disputed'],
      };

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
  void didUpdateWidget(covariant RemittancesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _poller.refreshIfStale();
  }

  @override
  void dispose() {
    _poller.stop();
    _scroll.dispose();
    _watched.dispose();
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    if (widget.api == null) _api.close();
    if (widget.revokeOnClose) {
      unawaited(ApiService().logout(widget.accessToken).catchError((_) {}));
    }
    super.dispose();
  }

  Future<void> _load({bool refreshSummary = true}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _selection.clear();
      _heldRows = null;
    });
    try {
      final result = await Future.wait<Object>([
        if (refreshSummary) _api.summary() else Future.value(_summary),
        _api.records(_tab,
            page: _page, search: _search.text.trim(), status: _status),
      ]);
      if (!mounted || generation != _generation) return;
      final records = result[1] as RemittancePageData;
      setState(() {
        _summary = result[0] as Map<String, dynamic>;
        _rows = records.items;
        _lastPage = records.lastPage;
        _loading = false;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e is ApiException
              ? e.message
              : 'Could not load remittances. Check your connection and retry.';
          _loading = false;
        });
      }
    }
  }

  void _changeTab(String tab) {
    if (tab == _tab) return;
    _debounce?.cancel();
    setState(() {
      _tab = tab;
      _page = 1;
      _status = '';
    });
    _load(refreshSummary: false);
  }

  Future<void> _action(String action, Map<String, dynamic> row,
      {List<String>? ids, int? maxCents}) async {
    if (action == 'proof') {
      final uri = Uri.tryParse('${row['proof_url']}');
      if (uri == null || !['https', 'http'].contains(uri.scheme)) return;
      try {
        if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
          throw StateError('Could not open');
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Could not open the proof. Refresh for a new link and retry.')));
        }
      }
      return;
    }
    if (['history', 'receiptHistory', 'statement'].contains(action)) {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RemittanceDetailScreen(
              api: _api,
              id: '${action == 'receiptHistory' ? row['submission_id'] : row['id']}',
              statement: action == 'statement')));
      return;
    }
    final recipient = (_summary['recipients'] as List? ?? [])
        .whereType<Map>()
        .where((r) => r['key'] == row['recipient_key'])
        .firstOrNull;
    _watchedId = '${row['id']}';
    _watched.value = null;
    _actionOpen = true;
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => RemittanceActionScreen(
              api: _api,
              latest: _watched,
              action: action,
              tab: _tab,
              row: row,
              recipient: recipient == null
                  ? null
                  : Map<String, dynamic>.from(recipient),
              obligationIds: ids,
              maxCents: maxCents,
            )));
    _actionOpen = false;
    _watchedId = null;
    if (!mounted || changed != true) return;
    DriverTopNotification.show(context,
        message: action == 'verify'
            ? 'Receipt confirmed.'
            : ['cod', 'payment'].contains(action)
                ? 'Proof submitted. Awaiting recipient verification.'
                : 'Saved.');
    await _load();
  }

  void _batchPayment() {
    final selected =
        _rows.where((r) => _selection.contains('${r['id']}')).toList();
    if (selected.isEmpty) return;
    _action('payment', selected.first,
        ids: selected.map((r) => '${r['id']}').toList(),
        maxCents: selected.fold<int>(
            0,
            (total, row) =>
                total +
                remittanceCents(row['amount_cents']) -
                remittanceCents(row['paid_cents'])));
  }

  Widget _summaryView() {
    final primary = _seller
        ? _summary['outstanding_cents']
        : _summary['manual_cod_owed_cents'];
    final secondary =
        _seller ? _summary['exposure_cents'] : _summary['available_cents'];
    final owes = remittanceCents(primary) > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: DriverColors.heroGradient),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: DriverColors.primary.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(
                _seller
                    ? Icons.receipt_long_rounded
                    : Icons.account_balance_wallet_rounded,
                size: 16,
                color: Colors.white70),
            const SizedBox(width: 6),
            Text(_seller ? 'Outstanding fees' : 'COD to remit',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            if (!_seller)
              _heroPill(owes ? 'Action needed' : 'All settled',
                  owes ? Icons.schedule_rounded : Icons.check_circle_rounded),
          ]),
          const SizedBox(height: 6),
          Text(remittanceMoney(primary),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              _seller
                  ? 'Confirm incoming payments and settle your fees.'
                  : 'Send collected COD to the seller, then track confirmation here.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12.5,
                  height: 1.35)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(
                  child: Text(_seller ? 'COD exposure' : 'Available earnings',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600))),
              Text(remittanceMoney(secondary),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
      if (_seller) ...[
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _infoChip(Icons.speed_rounded,
              'COD limit ${_summary['limit_cents'] == null ? 'not set' : remittanceMoney(_summary['limit_cents'])}'),
          if (_summary['next_deadline'] != null)
            _infoChip(Icons.event_rounded, 'Due ${_summary['next_deadline']}'),
          if (_summary['period_start'] != null)
            _infoChip(Icons.date_range_rounded,
                '${_summary['period_start']} – ${_summary['period_end']}'),
        ]),
        if (_summary['cod_eligible'] == false || _summary['warning'] == true)
          Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: DriverColors.warningSurface,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: DriverColors.warning),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        '${_summary['reason'] ?? 'You are approaching your COD balance limit.'} Existing orders can continue normally.',
                        style: const TextStyle(fontSize: 12.5, height: 1.35))),
              ])),
      ] else
        Padding(
            padding: const EdgeInsets.only(top: 10, left: 4),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: DriverColors.textSecondary),
              const SizedBox(width: 6),
              const Expanded(
                  child: Text(
                      'Logistics pays your courier earnings separately from COD remittances.',
                      style: DriverText.caption)),
            ])),
    ]);
  }

  Widget _heroPill(String text, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _infoChip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DriverColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: DriverColors.primary),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DriverColors.textPrimary)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final selectedRows =
        _rows.where((r) => _selection.contains('${r['id']}')).toList();
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(
          title: Text(_seller ? 'Seller remittances' : 'Remittances'),
          actions: [
            IconButton(
                onPressed: _loading ? null : _load,
                tooltip: 'Refresh remittances',
                icon: const Icon(Icons.refresh_rounded))
          ]),
      body: SafeArea(
          child: Stack(children: [
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_summary.isNotEmpty) ...[
                    _summaryView(),
                    const SizedBox(height: 20),
                  ],
                  SizedBox(
                      height: 40,
                      child: ListView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          children: _tabs.entries.map((entry) {
                            final active = _tab == entry.key;
                            return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Material(
                                    color: active
                                        ? DriverColors.primary
                                        : Colors.white,
                                    shape: StadiumBorder(
                                        side: BorderSide(
                                            color: active
                                                ? DriverColors.primary
                                                : DriverColors.border)),
                                    child: InkWell(
                                        customBorder: const StadiumBorder(),
                                        onTap: () => _changeTab(entry.key),
                                        child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            child: Center(
                                                child: Text(entry.value,
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: active
                                                            ? Colors.white
                                                            : DriverColors
                                                                .textSecondary)))))));
                          }).toList())),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: _search,
                            maxLength: 100,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search_rounded,
                                    color: DriverColors.textSecondary),
                                hintText: 'Search order or reference',
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: DriverColors.border)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: DriverColors.primary,
                                        width: 1.5))),
                            onChanged: (_) {
                              _debounce?.cancel();
                              _debounce =
                                  Timer(const Duration(milliseconds: 400), () {
                                _page = 1;
                                _load(refreshSummary: false);
                              });
                            })),
                    if (_statuses.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                          tooltip: 'Filter by status',
                          initialValue: _status,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          onSelected: (value) {
                            _status = value;
                            _page = 1;
                            _load(refreshSummary: false);
                          },
                          itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: '',
                                    child: Text(_tab == 'gcash'
                                        ? 'Awaiting verification'
                                        : 'All statuses')),
                                ..._statuses.map((s) => PopupMenuItem(
                                    value: s, child: Text(remittanceLabel(s))))
                              ],
                          child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                  color: _status.isEmpty
                                      ? Colors.white
                                      : DriverColors.primarySurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: _status.isEmpty
                                          ? DriverColors.border
                                          : DriverColors.primary)),
                              child: Icon(Icons.tune_rounded,
                                  color: _status.isEmpty
                                      ? DriverColors.textSecondary
                                      : DriverColors.primary))),
                    ],
                  ]),
                  if (_status.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: InputChip(
                                label: Text(remittanceLabel(_status)),
                                onDeleted: () {
                                  _status = '';
                                  _page = 1;
                                  _load(refreshSummary: false);
                                }))),
                  const SizedBox(height: 16),
                  if (_selection.isNotEmpty && !_loading)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FilledButton.icon(
                            onPressed: _batchPayment,
                            icon: const Icon(Icons.send_outlined),
                            label: Text(
                                'Remit ${_selection.length} selected charges'))),
                  if (_loading)
                    const _RemittanceSkeleton()
                  else if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(children: [
                          const Icon(Icons.cloud_off_rounded,
                              size: 44, color: DriverColors.textSecondary),
                          const SizedBox(height: 12),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: DriverColors.textSecondary,
                                  height: 1.4)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry'))
                        ]))
                  else if (_rows.isEmpty)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(children: [
                          Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                  color: DriverColors.primarySurface,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.receipt_long_rounded,
                                  size: 32, color: DriverColors.primary)),
                          const SizedBox(height: 14),
                          Text(
                              _tab == 'collections'
                                  ? 'No COD collections found'
                                  : 'No ${_tabs[_tab]!.toLowerCase()} found',
                              style: DriverText.sectionTitle),
                          const SizedBox(height: 6),
                          Text(
                              _tab == 'collections'
                                  ? 'Only COD cash recorded for your delivered parcels appears here. GCash orders do not require a courier remittance.'
                                  : 'Try another status or clear your search.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: DriverColors.textSecondary))
                        ]))
                  else
                    ..._rows.map((row) {
                      final selectable = _seller &&
                          _tab == 'obligations' &&
                          row['status'] != 'disputed' &&
                          row['recipient_key'] != 'unassigned' &&
                          remittanceCents(row['amount_cents']) >
                              remittanceCents(row['paid_cents']) &&
                          (selectedRows.isEmpty ||
                              selectedRows.first['recipient_key'] ==
                                  row['recipient_key']);
                      return RemittanceRecordCard(
                          row: row,
                          tab: _tab,
                          seller: _seller,
                          selected: _selection.contains('${row['id']}'),
                          onSelect: selectable
                              ? (selected) => setState(() {
                                    if (selected == true) {
                                      _selection.add('${row['id']}');
                                    } else {
                                      _selection.remove('${row['id']}');
                                    }
                                  })
                              : null,
                          onAction: (action) => _action(action, row));
                    }),
                  if (!_loading && _error == null && _lastPage > 1)
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                              onPressed: _page > 1
                                  ? () {
                                      _page--;
                                      _load(refreshSummary: false);
                                    }
                                  : null,
                              child: const Text('Previous')),
                          Text('Page $_page of $_lastPage'),
                          TextButton(
                              onPressed: _page < _lastPage
                                  ? () {
                                      _page++;
                                      _load(refreshSummary: false);
                                    }
                                  : null,
                              child: const Text('Next')),
                        ]),
                  const SizedBox(height: 24),
                ],
              )),
            if (_heldRows != null)
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
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Updated', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ])),
    );
  }
}

class _RemittanceSkeleton extends StatelessWidget {
  const _RemittanceSkeleton();
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Loading remittances',
      child: Column(
          children: List.generate(
              3,
              (_) => Container(
                  height: 130,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            height: 18, width: 140, color: DriverColors.border),
                        const SizedBox(height: 16),
                        Container(
                            height: 12,
                            width: 220,
                            color: DriverColors.background),
                        const SizedBox(height: 12),
                        Container(
                            height: 12,
                            width: 100,
                            color: DriverColors.background)
                      ])))));
}
