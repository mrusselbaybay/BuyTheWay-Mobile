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
  bool _headerVisible = true;
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
  double _lastScrollOffset = 0;
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
        _api.records(_tab,
            page: _page, search: _search.text.trim(), status: _status),
      ]);
      // _load() bumps the generation: a poll that began before the user changed
      // tab/page/filter/search (or finished an action) is dropped.
      if (!isActive() || !mounted || generation != _generation || _loading) {
        return;
      }
      final records = result[1] as RemittancePageData;
      _mergeRemote(
          result[0] as Map<String, dynamic>, records.items, records.lastPage);
    },
    interval: const Duration(seconds: 45),
    shouldSkip: () =>
        _loading ||
        !widget.active ||
        (_route?.isCurrent == false && !_actionOpen),
  );

  /// Seam for push/realtime (e.g. a remittance verdict notification).
  Future<void> refreshNow() => _poller.refreshNow();

  String _fp(Object? value) => jsonEncode(value, toEncodable: (o) => '$o')
      .replaceAll(RegExp(r'"[^"]*url[^"]*":"[^"]*",?'), '');

  void _mergeRemote(Map<String, dynamic> summary,
      List<Map<String, dynamic>> fresh, int lastPage) {
    final summaryChanged = _fp(summary) != _fp(_summary);
    final byId = {for (final r in _rows) '${r['id']}': r};
    final sameShape = fresh.length == _rows.length &&
        [
          for (var i = 0; i < fresh.length; i++)
            '${fresh[i]['id']}' == '${_rows[i]['id']}'
        ].every((e) => e);
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
    final rowsChanged = next.length != _rows.length ||
        [for (var i = 0; i < next.length; i++) identical(next[i], _rows[i])]
            .any((e) => !e);
    final heldChanged = hold != (_heldRows != null) ||
        (hold && _heldRows!.length != fresh.length);

    // Tell an open action screen whether its record moved.
    if (_watchedId != null) {
      final latest = freshById[_watchedId];
      if (_fp(latest) != _fp(_watched.value) &&
          (latest != null || _watched.value != null)) {
        _watched.value = latest ?? const {'__missing': true};
      }
    }
    if (!summaryChanged &&
        !rowsChanged &&
        !heldChanged &&
        lastPage == _lastPage) {
      return;
    }
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
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
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
    _scroll.addListener(_handleScroll);
    _load();
    _poller.start();
  }

  void _handleScroll() {
    if (!_scroll.hasClients) return;
    final offset = _scroll.position.pixels;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;

    final shouldShow = offset <= 8 || (delta < -1 && !_headerVisible);
    final shouldHide = offset > 40 && delta > 1 && _headerVisible;
    if ((shouldShow && !_headerVisible) || shouldHide) {
      setState(() => _headerVisible = shouldShow);
    }
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
              id:
                  '${action == 'receiptHistory' ? row['submission_id'] : row['id']}',
              statement: action == 'statement',
              historyTitle: action == 'receiptHistory'
                  ? 'Receipt history'
                  : 'Verification history')));
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
    if (!_seller) return _courierSummaryView();
    final primary = _seller
        ? _summary['outstanding_cents']
        : _summary['manual_cod_owed_cents'];
    final secondary =
        _seller ? _summary['exposure_cents'] : _summary['available_cents'];
    final owes = remittanceCents(primary) > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: DriverColors.heroGradient),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: DriverColors.primary.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(
                    _seller
                        ? Icons.receipt_long_rounded
                        : Icons.payments_outlined,
                    size: 17,
                    color: Colors.white)),
            const SizedBox(width: 9),
            Expanded(
                child: Text(_seller ? 'Outstanding fees' : 'COD REMITTANCE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 0.75,
                        fontWeight: FontWeight.w800))),
            if (!_seller) const SizedBox(width: 8),
            if (!_seller)
              _heroPill(owes ? 'Action needed' : 'All settled',
                  owes ? Icons.schedule_rounded : Icons.check_circle_rounded),
          ]),
          const SizedBox(height: 14),
          Text(remittanceMoney(primary),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.65)),
          const SizedBox(height: 6),
          Text(
              _seller
                  ? 'Confirm incoming payments and settle your fees.'
                  : 'Send collected COD to the seller, then track confirmation here.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12.5,
                  height: 1.35)),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12)),
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
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: DriverColors.warning),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        '${_summary['reason'] ?? 'You are approaching your COD balance limit.'} Existing orders can continue normally.',
                        style: const TextStyle(fontSize: 12.5, height: 1.35))),
              ])),
      ] else
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DriverColors.border.withOpacity(0.7)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded,
                size: 16, color: DriverColors.primaryDark),
            SizedBox(width: 8),
            Expanded(
                child: Text(
                    'Courier earnings are paid separately by logistics.',
                    style: DriverText.caption)),
          ]),
        ),
    ]);
  }

  Widget _courierSummaryView() {
    final owed = remittanceCents(_summary['manual_cod_owed_cents']);
    final available = remittanceCents(_summary['available_cents']);
    final settled = owed <= 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DriverColors.border.withOpacity(0.85)),
          boxShadow: [
            BoxShadow(
              color: DriverColors.textPrimary.withOpacity(0.035),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(children: [
          Positioned(
            right: -35,
            top: -53,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: DriverColors.primarySurface.withOpacity(0.65), width: 22),
              ),
            ),
          ),
          Positioned(
            right: 54,
            bottom: -72,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DriverColors.primarySurface.withOpacity(0.55),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 18, 19, 17),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                  child: Text('COURIER WALLET',
                      style: TextStyle(
                          color: DriverColors.primaryDark,
                          fontSize: 10,
                          letterSpacing: 1.15,
                          fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: settled
                        ? const Color(0xFFDAF7E8)
                        : const Color(0xFFFFE9C2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        settled
                            ? Icons.check_circle_rounded
                            : Icons.schedule_rounded,
                        size: 13,
                        color: settled
                            ? const Color(0xFF12834E)
                            : const Color(0xFF9A5D05)),
                    const SizedBox(width: 5),
                    Text(settled ? 'UP TO DATE' : 'REMIT DUE',
                        style: TextStyle(
                            color: settled
                                ? const Color(0xFF12834E)
                                : const Color(0xFF9A5D05),
                            fontSize: 9,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w900)),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              const Text('COD balance to remit',
                  style: TextStyle(
                      color: DriverColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(remittanceMoney(owed),
                    style: const TextStyle(
                        color: DriverColors.textPrimary,
                        fontSize: 38,
                        height: 1.08,
                        letterSpacing: -1.1,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 7),
              Text(
                settled
                    ? 'You’re all caught up on cash collected for COD orders.'
                    : 'Submit a receipt for cash collected on delivered COD orders.',
                style: const TextStyle(
                    color: DriverColors.textSecondary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (_tab != 'collections') _changeTab('collections');
                      if (_scroll.hasClients) {
                        _scroll.animateTo(
                          (_scroll.offset + 330)
                              .clamp(0, _scroll.position.maxScrollExtent)
                              .toDouble(),
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: DriverColors.primaryDark,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    icon: const Icon(Icons.north_east_rounded, size: 16),
                    label: const Text('View COD collections'),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: DriverColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DriverColors.border),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('EARNINGS',
                            style: TextStyle(
                                color: DriverColors.textSecondary,
                                fontSize: 8,
                                letterSpacing: 0.65,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(remittanceMoney(available),
                            style: const TextStyle(
                                color: DriverColors.primaryDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                      ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: DriverColors.border),
        ),
        child: const Row(children: [
          Icon(Icons.account_balance_outlined,
              size: 17, color: DriverColors.primaryDark),
          SizedBox(width: 9),
          Expanded(
              child: Text('Courier earnings are paid separately by logistics.',
                  style: DriverText.caption)),
        ]),
      ),
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

  Color _filterStatusColor(String status) => switch (status) {
        'verified' ||
        'paid' ||
        'completed' ||
        'resolved' =>
          const Color(0xFF70D8A0),
        'rejected' || 'disputed' || 'overdue' => const Color(0xFFFF8D85),
        'awaiting_verification' ||
        'pending' ||
        'partially_paid' =>
          const Color(0xFFFFD071),
        _ => const Color(0xFF78D9D0),
      };

  Widget _statusMenuRow(String label,
          {required bool selected, required Color color}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFD2E8E5),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
          ),
          if (selected)
            const Icon(Icons.check_rounded, size: 17, color: Color(0xFF8FE5D8)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final selectedRows =
        _rows.where((r) => _selection.contains('${r['id']}')).toList();
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: _headerVisible
          ? AppBar(
              automaticallyImplyLeading: false,
              titleSpacing: 18,
              toolbarHeight: _seller ? null : 84,
              backgroundColor: Colors.white,
              foregroundColor: DriverColors.textPrimary,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              shape: const Border(
                  bottom: BorderSide(color: DriverColors.border)),
              title: _seller
                  ? const Text('Seller remittances')
                  : const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(children: [
                          SizedBox(
                              width: 7,
                              height: 7,
                              child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      color: DriverColors.primary,
                                      shape: BoxShape.circle))),
                          SizedBox(width: 7),
                          Text('RIDER  /  FIELD ROUTE',
                              style: TextStyle(
                                  color: DriverColors.textSecondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0)),
                        ]),
                        SizedBox(height: 5),
                        Text('Remittances',
                            style: TextStyle(
                                fontSize: 27,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                                color: DriverColors.textPrimary,
                                letterSpacing: -0.8)),
                        SizedBox(height: 4),
                        Text('COD collections and earnings',
                            style: TextStyle(
                                color: DriverColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ))
          : null,
      body: SafeArea(
          child: Stack(children: [
        RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                if (_summary.isNotEmpty) ...[
                  _summaryView(),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                    height: 46,
                    child: ListView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        children: _tabs.entries.map((entry) {
                          final active = _tab == entry.key;
                          return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Material(
                                  color: active
                                      ? DriverColors.primaryDark
                                      : Colors.white,
                                  shape: StadiumBorder(
                                      side: BorderSide(
                                          color: active
                                              ? DriverColors.primaryDark
                                              : DriverColors.border)),
                                  child: InkWell(
                                      customBorder: const StadiumBorder(),
                                      onTap: () => _changeTab(entry.key),
                                      child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 15),
                                          child: Center(
                                              child: Text(entry.value,
                                                  style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: active
                                                          ? Colors.white
                                                          : DriverColors
                                                              .textSecondary)))))));
                        }).toList())),
                const SizedBox(height: 13),
                if (!_seller)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 2),
                    child: Row(children: [
                      Text('LEDGER',
                          style: DriverText.label.copyWith(
                              color: DriverColors.primaryDark,
                              letterSpacing: 0.9,
                              fontSize: 9.5)),
                      const SizedBox(width: 7),
                      const Text('Choose a view',
                          style: TextStyle(
                              color: DriverColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _search,
                          maxLength: 100,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search_rounded,
                                  color: DriverColors.textSecondary),
                              hintText: _seller
                                  ? 'Search order or reference'
                                  : 'Find an order or receipt',
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
                        color: const Color(0xFF123D3A),
                        surfaceTintColor: Colors.transparent,
                        elevation: 14,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.12))),
                        menuPadding: const EdgeInsets.symmetric(vertical: 7),
                        onSelected: (value) {
                          _status = value;
                          _page = 1;
                          _load(refreshSummary: false);
                        },
                        itemBuilder: (_) => [
                              PopupMenuItem<String>(
                                value: '',
                                height: 48,
                                child: _statusMenuRow(
                                  _tab == 'gcash'
                                      ? 'Awaiting verification'
                                      : 'All statuses',
                                  selected: _status.isEmpty,
                                  color: const Color(0xFF78D9D0),
                                ),
                              ),
                              ..._statuses
                                  .map((status) => PopupMenuItem<String>(
                                        value: status,
                                        height: 48,
                                        child: _statusMenuRow(
                                          remittanceLabel(status),
                                          selected: _status == status,
                                          color: _filterStatusColor(status),
                                        ),
                                      )),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tab == 'collections'
                            ? 'COD activity'
                            : _tabs[_tab] ?? 'Activity',
                        style: DriverText.sectionTitle.copyWith(fontSize: 15),
                      ),
                    ),
                    if (!_seller && !_loading && _error == null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: DriverColors.primarySurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: DriverColors.primary,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text('LIVE · ${_rows.length}',
                              style: const TextStyle(
                                  color: DriverColors.primaryDark,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3)),
                        ]),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
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
                      Icon(Icons.arrow_upward_rounded,
                          size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Updated',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
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
