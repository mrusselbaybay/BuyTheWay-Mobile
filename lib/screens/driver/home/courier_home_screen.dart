import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/remittance_api_service.dart';
import '../../remittances/remittance_format.dart';
import '../chat/driver_chat_controller.dart';
import '../deliveries/assigned_delivery_detail_screen.dart';
import '../driver_models.dart';
import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';

// ---- Visual tokens for this screen ----
const Color _bg = DriverColors.background;
const Color _ink = DriverColors.textPrimary;
const Color _inkSoft = DriverColors.textSecondary;
const Color _line = DriverColors.border;
const Color _teal = DriverColors.primary;
const Color _tealDeep = DriverColors.primaryDark;
const Color _tealSoft = DriverColors.primarySurface;
const Color _amber = Color(0xFF9B682D);
const Color _gold = Color(0xFFE8A026);
const Color _rose = Color(0xFFB95137);
const List<Color> _coveragePalette = [_teal, Color(0xFF5D9C8B), Color(0xFF8FB6A4), Color(0xFFBCCFC0)];
const double _radius = 24;

/// The courier's Home tab: today's route, the next stop, money + COD on
/// hand, what needs attention, area coverage and recent earnings.
///
/// Parcel data comes from the shell's already-loaded `GET /api/driver/deliveries`
/// list (mutated in place by the detail flow, so a `setState` is enough to
/// reflect progress). Money comes from the courier remittance summary and
/// earnings ledger, fetched here in parallel so the parcel sections never
/// wait on them.
class CourierHomeScreen extends StatefulWidget {
  final DriverAccount account;
  final String accessToken;
  final bool isOnline;
  final List<AssignedDelivery> deliveries;
  final bool loading;
  final String? error;
  final DriverChatController controller;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenDeliveries;
  final VoidCallback onOpenRemittances;
  final int unreadNotifications;
  final VoidCallback onOpenNotifications;

  const CourierHomeScreen({
    super.key,
    required this.account,
    required this.accessToken,
    required this.isOnline,
    required this.deliveries,
    required this.loading,
    required this.error,
    required this.controller,
    required this.onRefresh,
    required this.onOpenDeliveries,
    required this.onOpenRemittances,
    required this.unreadNotifications,
    required this.onOpenNotifications,
  });

  @override
  State<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends State<CourierHomeScreen> {
  late final RemittanceApiService _money = RemittanceApiService(accessToken: widget.accessToken, role: RemittanceRole.courier);
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _ledger = const [];
  bool _moneyLoading = true;
  bool _moneyFailed = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _loadMoney();
    // Keeps the "due in 3 hours" copy honest without refetching.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _money.close();
    super.dispose();
  }

  Future<void> _loadMoney() async {
    try {
      final results = await Future.wait([_money.summary(), _money.recentEarnings()]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _ledger = results[1] as List<Map<String, dynamic>>;
        _moneyLoading = false;
        _moneyFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _moneyLoading = false;
        _moneyFailed = _summary == null;
      });
    }
  }

  Future<void> _refresh() => Future.wait([widget.onRefresh(), _loadMoney()]);

  // ---------------------------------------------------------------- derived

  static bool _isToday(DateTime? d) {
    if (d == null) return false;
    final l = d.toLocal(), n = DateTime.now();
    return l.year == n.year && l.month == n.month && l.day == n.day;
  }

  static bool _isPending(AssignedDelivery d) => const {
        AssignedDeliveryStatus.assigned,
        AssignedDeliveryStatus.waitingApproval,
        AssignedDeliveryStatus.pickedUp,
        AssignedDeliveryStatus.transferAssigned,
        AssignedDeliveryStatus.readyToTransfer,
      }.contains(d.status);

  static bool _isFailed(AssignedDelivery d) => d.status == AssignedDeliveryStatus.failedAttempt || d.status == AssignedDeliveryStatus.needsDispatcherReview;

  static bool _isDoneToday(AssignedDelivery d) =>
      const {AssignedDeliveryStatus.delivered, AssignedDeliveryStatus.transferred, AssignedDeliveryStatus.handedOver}.contains(d.status) &&
      _isToday(d.deliveredAt ?? d.transferredAt ?? d.handedOffAt);

  /// Route order: parcels already in hand first (the rider is mid-delivery),
  /// then oldest assignment first.
  List<AssignedDelivery> get _queue {
    final rows = widget.deliveries.where(_isPending).toList()
      ..sort((a, b) {
        final inHand = (b.status == AssignedDeliveryStatus.pickedUp ? 1 : 0) - (a.status == AssignedDeliveryStatus.pickedUp ? 1 : 0);
        if (inHand != 0) return inHand;
        return (a.assignedAt ?? DateTime(2100)).compareTo(b.assignedAt ?? DateTime(2100));
      });
    return rows;
  }

  static int _intOf(dynamic v) => (v as num?)?.toInt() ?? 0;
  int get _cents => _intOf(_summary?['cod_owed_cents']);
  DateTime? get _codDue => DateTime.tryParse('${_summary?['cod_due_at'] ?? ''}')?.toLocal();

  // ---------------------------------------------------------------- actions

  Future<void> _openDetail(AssignedDelivery d) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AssignedDeliveryDetailScreen(delivery: d, accessToken: widget.accessToken, controller: widget.controller)),
    );
    if (!mounted) return;
    setState(() {});
    unawaited(_loadMoney());
  }

  Future<void> _navigate(AssignedDelivery d) async {
    final toPickup = d.status == AssignedDeliveryStatus.assigned || d.status == AssignedDeliveryStatus.transferAssigned ||
        (d.status == AssignedDeliveryStatus.waitingApproval && d.handedOffAt == null);
    final uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': toPickup ? d.pickupLabel : d.dropoffLabel});
    await _launch(uri, 'Could not open maps.');
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    await _launch(Uri(scheme: 'tel', path: phone.trim()), 'Could not start a call. Please dial manually.');
  }

  Future<void> _launch(Uri uri, String failure) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw Exception('launch failed');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure), behavior: SnackBarBehavior.floating));
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    final initialLoad = widget.loading && widget.deliveries.isEmpty;
    final hardError = widget.error != null && widget.deliveries.isEmpty;
    var i = 0;
    Widget reveal(String key, Widget child) => _Reveal(key: ValueKey(key), index: i++, child: child);

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _teal,
        edgeOffset: MediaQuery.of(context).padding.top,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 130),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _hero(initialLoad: initialLoad, hardError: hardError),
            if (initialLoad)
              const Padding(padding: EdgeInsets.fromLTRB(16, 24, 16, 0), child: Column(children: [DriverCardSkeleton(), DriverCardSkeleton()]))
            else if (hardError)
              Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 0), child: _inlineRetry(widget.error!, widget.onRefresh))
            else ...[
              reveal('next', _section('Next stop', action: queue.isEmpty ? null : 'View route', onAction: widget.onOpenDeliveries, child: queue.isEmpty ? _emptyStop() : _nextStop(queue.first))),
              if (queue.length > 1) reveal('upnext', Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: _upNext(queue.skip(1).take(3).toList(), queue.length - 1))),
              reveal('route', Padding(padding: const EdgeInsets.fromLTRB(16, 22, 16, 0), child: _routeCard())),
            ],
            reveal('money', _section('Money', child: _moneyCard())),
            reveal('cod', _codCard()),
            for (final w in _attention()) reveal('attention', w),
            reveal('coverage', _coverage()),
            reveal('activity', _activity()),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, {required Widget child, String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Semantics(header: true, child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: _ink)))),
              if (action != null) _linkButton(action, onAction!),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _linkButton(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _teal)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_rounded, size: 17, color: _teal),
          ]),
        ),
      );

  BoxDecoration get _card => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _line.withOpacity(0.7)),
        boxShadow: [BoxShadow(color: _tealDeep.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 10))],
      );

  // ------------------------------------------------------------------- hero

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  /// Mirrors the logistics dashboard header: shared logo, name, and alert
  /// control, with courier availability kept beside the driver's name.
  Widget _hero({required bool initialLoad, required bool hardError}) {
    final top = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, top + 10, 18, initialLoad || hardError ? 24 : 8),
      child: Row(children: [
        Expanded(
          child: Image.asset(
              'assets/images/logo-buytheway.png',
              width: 130,
              height: 35,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              semanticLabel: 'BuyTheWay',
          ),
        ),
        const SizedBox(width: 8),
        _availabilityBadge(widget.isOnline),
        const SizedBox(width: 8),
        _courierNotificationButton(),
      ]),
    );
  }

  Widget _availabilityBadge(bool online) => Semantics(
        label: online ? 'You are online' : 'You are offline',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: online ? const Color(0xFFDDF1EC) : const Color(0xFFE9ECE7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: online ? const Color(0xFFB8D9CF) : _line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? const Color(0xFF287A5A) : const Color(0xFF89938A),
            )),
            const SizedBox(width: 5),
            Text(online ? 'Online' : 'Offline', style: TextStyle(
              color: online ? const Color(0xFF245D48) : _inkSoft,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            )),
          ]),
        ),
      );

  Widget _courierNotificationButton() => Badge(
        isLabelVisible: widget.unreadNotifications > 0,
        label: Text(widget.unreadNotifications > 99 ? '99+' : '${widget.unreadNotifications}'),
        backgroundColor: const Color(0xFFB95137),
        child: IconButton(
          onPressed: widget.onOpenNotifications,
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded, size: 21),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _inkSoft,
            minimumSize: const Size(42, 42),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(color: _line),
          ),
        ),
      );

  // ------------------------------------------------------------ route card

  Widget _routeCard() {
    final done = widget.deliveries.where(_isDoneToday).length;
    final pending = widget.deliveries.where(_isPending).length;
    final failed = widget.deliveries.where(_isFailed).length;
    final total = done + pending + failed;
    final pct = total == 0 ? 0.0 : done / total;
    final complete = total > 0 && pct >= 1;
    final routeStateColor = failed > 0
        ? _rose
        : complete
            ? const Color(0xFF15803D)
            : _tealDeep;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: [BoxShadow(color: _ink.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('ROUTE CONTROL', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: _inkSoft)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: complete ? const Color(0xFFE4F0E8) : failed > 0 ? const Color(0xFFF7E9E4) : _tealSoft, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: failed > 0 ? _rose : complete ? const Color(0xFF16A34A) : _teal)),
              const SizedBox(width: 6),
            Text(
              failed > 0
                  ? 'NEEDS ATTENTION'
                  : pending > 0
                      ? 'IN PROGRESS'
                      : total == 0
                          ? 'NO STOPS'
                          : 'COMPLETE',
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: routeStateColor),
            ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('$done', style: const TextStyle(fontSize: 38, height: 1, fontWeight: FontWeight.w900, letterSpacing: -1.6, color: _ink, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(width: 6),
          Flexible(child: Text('/ $total stops completed', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _inkSoft), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(5), child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: pct),
          duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 7, backgroundColor: const Color(0xFFE7EBE5), color: _teal),
        )),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _routeStat(Icons.schedule_rounded, 'In progress', '$pending', const Color(0xFFD98A0B))),
          Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 16), color: _line),
          Expanded(child: _routeStat(failed > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded, 'Issues', failed > 0 ? '$failed' : 'None', failed > 0 ? _rose : const Color(0xFF16A34A))),
        ]),
      ]),
    );
  }

  Widget _routeStat(IconData icon, String label, String value, Color color) => Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 18, color: color)),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _inkSoft)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: value == 'None' ? color : _ink, fontFeatures: const [FontFeature.tabularFigures()])),
        ])),
      ]);

  // -------------------------------------------------------------- next stop

  Widget _emptyStop() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: _card,
        child: Column(children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(color: _tealSoft, shape: BoxShape.circle),
            child: const Icon(Icons.task_alt_rounded, color: _teal, size: 30),
          ),
          const SizedBox(height: 14),
          const Text('All caught up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 4),
          Text(widget.isOnline ? 'New assignments from dispatch will show up here.' : 'Go online in Settings to receive assignments.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: _inkSoft)),
        ]),
      );

  Widget _activeRouteRail(AssignedDelivery d, {required bool toPickup}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(children: [
        _activeRoutePoint(
          icon: d.isReturn ? Icons.assignment_return_rounded : Icons.storefront_rounded,
          label: d.isReturn ? 'COLLECT RETURN' : 'PICK UP',
          address: d.pickupLabel,
          active: toPickup,
          complete: !toPickup,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 15),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: 20,
              width: 2,
            decoration: BoxDecoration(color: _teal.withOpacity(0.32), borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
        _activeRoutePoint(
          icon: d.isTransfer ? Icons.compare_arrows_rounded : Icons.location_on_rounded,
          label: d.isTransfer ? 'HAND OFF' : 'DELIVER TO',
          address: d.dropoffLabel,
          active: !toPickup,
          complete: false,
        ),
      ]),
    );
  }

  Widget _activeRoutePoint({
    required IconData icon,
    required String label,
    required String address,
    required bool active,
    required bool complete,
  }) {
    final color = active || complete ? _tealDeep : _inkSoft;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _teal : complete ? const Color(0xFF16A34A) : Colors.white,
          shape: BoxShape.circle,
          border: active || complete ? null : Border.all(color: _line, width: 1.5),
        ),
        child: Icon(complete ? Icons.check_rounded : icon, size: 17, color: active || complete ? Colors.white : _inkSoft),
      ),
      const SizedBox(width: 10),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.7, color: active ? _tealDeep : _inkSoft)),
            if (active) ...[
              const SizedBox(width: 7),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _tealSoft, borderRadius: BorderRadius.circular(8)), child: const Text('NEXT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: _tealDeep, letterSpacing: 0.4))),
            ],
          ]),
          const SizedBox(height: 3),
          Text(address, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.3, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? _ink : color)),
        ]),
      )),
    ]);
  }

  Widget _nextStop(AssignedDelivery d) {
    final toPickup = d.status == AssignedDeliveryStatus.assigned || d.status == AssignedDeliveryStatus.transferAssigned ||
        (d.status == AssignedDeliveryStatus.waitingApproval && d.handedOffAt == null);
    final (primaryLabel, primaryIcon) = switch (d.status) {
      AssignedDeliveryStatus.pickedUp => ('Delivered', Icons.check_rounded),
      AssignedDeliveryStatus.readyToTransfer => ('Hand over', Icons.check_rounded),
      _ => ('Pick up', Icons.inventory_2_outlined),
    };
    final stage = switch (d.status) {
      AssignedDeliveryStatus.pickedUp => 'Out for delivery',
      AssignedDeliveryStatus.readyToTransfer => 'Ready to hand over',
      AssignedDeliveryStatus.waitingApproval => 'Waiting approval',
      _ => 'Ready for pickup',
    };
    final kind = d.isTransfer ? 'Transfer' : d.isReturn ? 'Return' : null;
    final cod = d.codAmountCents;
    final canCall = (d.customerContactNo ?? '').trim().isNotEmpty;

    return Container(
      decoration: _card,
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _chip(stage, _teal, dot: true),
              if (kind != null) ...[const SizedBox(width: 6), _chip(kind, _gold)],
              const Spacer(),
              Flexible(child: Text('#${d.trackingNumber ?? d.orderNumber}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _inkSoft))),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _tealSoft, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.person_pin_circle_rounded, color: _tealDeep, size: 25),
              ),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('DELIVERY FOR', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.9, color: _inkSoft)),
                const SizedBox(height: 2),
                Text(d.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: _ink)),
              ])),
            ]),
            const SizedBox(height: 16),
            _activeRouteRail(d, toPickup: toPickup),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                  decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: cod > 0 ? _amber : const Color(0xFF16A34A), borderRadius: BorderRadius.circular(13)),
                      child: Icon(cod > 0 ? Icons.payments_rounded : Icons.verified_rounded, color: Colors.white, size: 21),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(cod > 0 ? 'COD to collect' : 'Payment', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _inkSoft)),
                        cod > 0
                            ? FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(remittanceMoney(cod), style: const TextStyle(fontSize: 22, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: _ink)))
                            : const Text('Paid online', style: TextStyle(fontSize: 17, height: 1.2, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              _roundIcon(Icons.call_rounded, 'Call ${d.customerName}', canCall ? () => _call(d.customerContactNo) : null, filled: true),
              const SizedBox(width: 10),
              _roundIcon(Icons.chat_bubble_outline_rounded, 'Message ${d.customerName}', () => _openDetail(d)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _teal,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: FilledButton.icon(
                    onPressed: () => _navigate(d),
                    icon: const Icon(Icons.navigation_rounded, size: 19),
                    label: const Text('Navigate'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openDetail(d),
                  icon: Icon(primaryIcon, size: 19),
                  label: Text(primaryLabel),
                  style: FilledButton.styleFrom(backgroundColor: _tealSoft, foregroundColor: _tealDeep, elevation: 0, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ]),
        ),
        const Divider(height: 1, color: _line),
        IntrinsicHeight(
          child: Row(children: [
            Expanded(child: _footerAction(Icons.inventory_2_outlined, 'View details', _inkSoft, () => _openDetail(d))),
            if (d.canMarkFailed) ...[
              const VerticalDivider(width: 1, color: _line),
              Expanded(child: _footerAction(Icons.close_rounded, 'Mark failed', DriverColors.error, () => _openDetail(d))),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _chip(String label, Color color, {bool dot = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(0.11), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot) ...[Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)), const SizedBox(width: 6)],
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
        ]),
      );

  Widget _roundIcon(IconData icon, String label, VoidCallback? onTap, {bool filled = false}) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: filled && enabled ? _tealSoft : Colors.transparent,
          shape: CircleBorder(side: BorderSide(color: enabled ? const Color(0xFFB8D9CF) : _line)),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(width: 48, height: 48, child: Icon(icon, color: enabled ? _teal : _line, size: 22)),
        ),
      ),
    );
  }

  Widget _footerAction(IconData icon, String label, Color color, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      );

  Widget _upNext(List<AssignedDelivery> rows, int total) {
    return Container(
      decoration: _card,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.alt_route_rounded, size: 18, color: _inkSoft),
          const SizedBox(width: 8),
          const Text('Up next', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(width: 6),
          const Text('· Route order', style: TextStyle(fontSize: 12.5, color: _inkSoft)),
          const Spacer(),
          if (total > rows.length) _chip('+${total - rows.length} more', _inkSoft),
        ]),
        const SizedBox(height: 10),
        for (var i = 0; i < rows.length; i++) _timelineStop(rows[i], i + 2, last: i == rows.length - 1),
      ]),
    );
  }

  /// One stop on the route timeline: a numbered node joined to the next by a
  /// connector line, so the list reads as an ordered path, not a plain list.
  Widget _timelineStop(AssignedDelivery d, int number, {required bool last}) {
    return InkWell(
      onTap: () => _openDetail(d),
      borderRadius: BorderRadius.circular(16),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 36,
            child: Column(children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _tealSoft, shape: BoxShape.circle, border: Border.all(color: _teal, width: 2)),
                child: Text('$number', style: const TextStyle(fontWeight: FontWeight.w800, color: _tealDeep, fontSize: 13.5, fontFeatures: [FontFeature.tabularFigures()])),
              ),
              if (!last) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 3), decoration: BoxDecoration(color: const Color(0xFFB8D9CF), borderRadius: BorderRadius.circular(2)))),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 10 : 16),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: _ink)),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: _inkSoft),
                      const SizedBox(width: 3),
                      Expanded(child: Text(d.deliveryArea ?? d.dropoffLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _inkSoft))),
                    ]),
                  ]),
                ),
                const SizedBox(width: 8),
                d.codAmountCents > 0 ? _chip(remittanceMoney(d.codAmountCents), _amber) : _chip('Paid', const Color(0xFF16A34A)),
                const Icon(Icons.chevron_right_rounded, size: 20, color: _inkSoft),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------------ money

  Widget _moneyCard() {
    if (_moneyFailed) {
      return _inlineRetry('Could not load your earnings.', () {
        setState(() => _moneyLoading = true);
        _loadMoney();
      });
    }
    final loading = _moneyLoading;
    String v(String key) => remittanceMoney(_intOf(_summary?[key]));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _tealDeep,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.white.withOpacity(0.8)),
                const SizedBox(width: 6),
                Text('Available balance', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.8))),
              ]),
              const SizedBox(height: 6),
              loading
                  ? const DriverShimmerBox(height: 32, width: 150)
                  : FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v('available_cents'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Colors.white))),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _moneyTile(Icons.today_rounded, 'Today', loading ? null : v('earned_today_cents')),
          const SizedBox(width: 10),
          _moneyTile(Icons.date_range_rounded, 'This week', loading ? null : v('earned_week_cents')),
        ]),
      ]),
    );
  }

  Widget _moneyTile(IconData icon, String label, String? value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.14))),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 18, color: Colors.white)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.78))),
                const SizedBox(height: 2),
                value == null
                    ? const DriverShimmerBox(height: 16, width: 56)
                    : FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white))),
              ]),
            ),
          ]),
        ),
      );

  String? get _dueHint {
    final due = _codDue;
    if (due == null) return null;
    if (due.isBefore(DateTime.now())) return 'Overdue — remit now';
    final h = due.hour % 12 == 0 ? 12 : due.hour % 12;
    final time = '$h:${due.minute.toString().padLeft(2, '0')} ${due.hour < 12 ? 'AM' : 'PM'}';
    return 'Remit by $time ${_isToday(due) ? 'today' : '${_months[due.month - 1].substring(0, 3)} ${due.day}'}';
  }

  Widget _codCard() {
    if (_moneyLoading || _moneyFailed) return const SizedBox.shrink();
    final owed = _cents;
    final hint = _dueHint;
    final urgent = owed > 0;
    final accent = urgent ? _amber : const Color(0xFF16A34A);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _card,
        child: Column(children: [
          Row(children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(16)),
              child: Icon(urgent ? Icons.payments_rounded : Icons.verified_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('COD on hand', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _inkSoft)),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(remittanceMoney(owed), style: const TextStyle(fontSize: 27, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: _ink))),
              ]),
            ),
            if (urgent)
              FilledButton(
                onPressed: widget.onOpenRemittances,
                style: FilledButton.styleFrom(backgroundColor: _tealDeep, minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                child: const Text('Remit now'),
              ),
          ]),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: accent.withOpacity(0.09), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(urgent ? Icons.schedule_rounded : Icons.check_circle_rounded, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(child: Text(urgent ? (hint ?? 'Remit your collected cash to your logistics company') : 'All cash remitted — nothing due', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: urgent ? const Color(0xFF8A4B08) : const Color(0xFF15803D)))),
            ]),
          ),
        ]),
      ),
    );
  }

  // -------------------------------------------------------------- attention

  List<Widget> _attention() {
    final items = <Widget>[];
    final due = _codDue;
    if (!_moneyLoading && _cents > 0 && due != null) {
      final diff = due.difference(DateTime.now());
      if (diff < const Duration(hours: 24)) {
        final when = diff.isNegative
            ? 'is overdue'
            : diff.inHours >= 1
                ? 'is due in ${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'}'
                : 'is due in ${diff.inMinutes.clamp(1, 59)} min';
        items.add(_attentionTile(
          icon: Icons.warning_amber_rounded,
          title: diff.isNegative ? 'COD remittance overdue' : 'COD remittance due soon',
          body: '${remittanceMoney(_cents)} $when. Remit on time to keep accepting COD parcels.',
          warn: true,
          onTap: widget.onOpenRemittances,
        ));
      }
    }

    final fresh = widget.deliveries.where((d) => d.status == AssignedDeliveryStatus.assigned && d.assignedAt != null && DateTime.now().difference(d.assignedAt!) < const Duration(hours: 6)).toList();
    if (fresh.isNotEmpty) {
      final area = fresh.first.deliveryArea;
      items.add(_attentionTile(
        icon: Icons.alt_route_rounded,
        title: 'New area assignment',
        body: '${fresh.length} ${fresh.length == 1 ? 'parcel' : 'parcels'}${area != null ? ' in $area' : ''} ${fresh.length == 1 ? 'was' : 'were'} added to your route.',
        onTap: widget.onOpenDeliveries,
      ));
    }
    if (items.isEmpty) return const [];
    return [
      _section('Needs attention', child: Column(children: [for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 10), items[i]]]))
    ];
  }

  Widget _attentionTile({required IconData icon, required String title, required String body, required VoidCallback onTap, bool warn = false}) {
    final accent = warn ? _amber : _teal;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: warn ? _amber.withOpacity(0.35) : _line, width: warn ? 1.5 : 1)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _ink))),
                  if (warn) ...[const SizedBox(width: 8), _chip('Action needed', _amber)],
                ]),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(fontSize: 12.5, color: _inkSoft, height: 1.35)),
              ]),
            ),
            const SizedBox(width: 6),
            const Padding(padding: EdgeInsets.only(top: 12), child: Icon(Icons.chevron_right_rounded, size: 22, color: _inkSoft)),
          ]),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- coverage

  Widget _coverage() {
    final counts = <String, int>{};
    for (final d in widget.deliveries.where(_isPending)) {
      final area = (d.deliveryArea ?? '').trim();
      final key = area.isEmpty ? 'Other' : area;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox.shrink();
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final shown = sorted.take(_coveragePalette.length).toList();
    final rest = sorted.skip(_coveragePalette.length).fold<int>(0, (s, e) => s + e.value);
    if (rest > 0) shown[shown.length - 1] = MapEntry('Others', shown.last.value + rest);
    final total = shown.fold<int>(0, (s, e) => s + e.value);
    final peak = shown.first.value;

    return _section(
      'My coverage',
      action: 'View all',
      onAction: widget.onOpenDeliveries,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _card,
        child: Column(children: [
          Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: _tealSoft, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.map_rounded, color: _teal, size: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$total ${total == 1 ? 'parcel' : 'parcels'} on route', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: _ink)),
                Text('Across ${shown.length} ${shown.length == 1 ? 'area' : 'areas'}', style: const TextStyle(fontSize: 12.5, color: _inkSoft)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _areaRow(shown[i].key, shown[i].value, total, peak, _coveragePalette[i], busiest: i == 0 && shown.length > 1),
          ],
        ]),
      ),
    );
  }

  Widget _areaRow(String name, int count, int total, int peak, Color color, {bool busiest = false}) {
    final pct = total == 0 ? 0 : (count / total * 100).round();
    return Semantics(
      label: '$name, $count ${count == 1 ? 'parcel' : 'parcels'}, $pct percent',
      excludeSemantics: true,
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(13)), child: Icon(Icons.location_on_rounded, size: 20, color: color)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink))),
              if (busiest) ...[const SizedBox(width: 6), _chip('Busiest', color)],
            ]),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: peak == 0 ? 0 : count / peak),
                duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 7, backgroundColor: color.withOpacity(0.12), color: color),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$count', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink, fontFeatures: [FontFeature.tabularFigures()])),
          Text('$pct%', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _inkSoft)),
        ]),
      ]),
    );
  }

  // --------------------------------------------------------------- activity

  String _when(DateTime? at) {
    if (at == null) return '';
    final l = at.toLocal(), n = DateTime.now();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final time = '$h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'AM' : 'PM'}';
    if (_isToday(l)) return 'Today, $time';
    final y = n.subtract(const Duration(days: 1));
    if (l.year == y.year && l.month == y.month && l.day == y.day) return 'Yesterday, $time';
    return '${_months[l.month - 1].substring(0, 3)} ${l.day}, $time';
  }

  Widget _activity() {
    if (_moneyLoading) return _section('Recent activity', child: const DriverCardSkeleton());
    final rows = _ledger.where((r) => '${r['status']}' != 'void').take(5).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return _section(
      'Recent activity',
      action: 'Full ledger',
      onAction: widget.onOpenRemittances,
      child: Container(
        decoration: _card,
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 74, color: _line),
            _activityRow(rows[i]),
          ],
        ]),
      ),
    );
  }

  Widget _activityRow(Map<String, dynamic> r) {
    final cents = _intOf(r['amount_cents']);
    final negative = cents < 0;
    final type = '${r['type']}';
    final (label, icon, color) = switch (type) {
      'delivery' => ('Delivery earnings', Icons.local_shipping_rounded, _teal),
      'pickup' => ('Pickup earnings', Icons.inventory_2_rounded, const Color(0xFF5D9C8B)),
      'transfer' => ('Transfer earnings', Icons.swap_horiz_rounded, const Color(0xFF8FB6A4)),
      'failed_attempt' => ('Failed attempt fee', Icons.replay_rounded, _gold),
      'bonus' => ('Bonus', Icons.workspace_premium_rounded, _gold),
      'deduction' => ('Deduction', Icons.remove_circle_rounded, _rose),
      'refund_adjustment' => ('Refund adjustment', Icons.undo_rounded, _rose),
      _ => (type.isEmpty ? 'Adjustment' : type[0].toUpperCase() + type.substring(1).replaceAll('_', ' '), Icons.tune_rounded, _inkSoft),
    };
    final order = (r['order'] is Map ? (r['order'] as Map)['order_number'] : null)?.toString();
    final when = _when(DateTime.tryParse('${r['created_at']}'));
    final amountColor = negative ? _rose : const Color(0xFF15803D);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(15)),
          child: Icon(icon, color: color, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 1),
            Text(order == null || order.isEmpty ? when : '#$order · $when', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _inkSoft)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: amountColor.withOpacity(0.09), borderRadius: BorderRadius.circular(12)),
          child: Text('${negative ? '' : '+'}${remittanceMoney(cents)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: amountColor)),
        ),
      ]),
    );
  }

  // ----------------------------------------------------------------- errors

  Widget _inlineRetry(String message, VoidCallback onRetry) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _card,
        child: Column(children: [
          const Icon(Icons.wifi_off_rounded, color: _inkSoft, size: 30),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: _ink)),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Try again')),
        ]),
      );
}

/// Fade + slight rise on first appearance, staggered by [index]. Skipped
/// entirely when the OS asks to reduce motion. Keyed by section so a
/// rebuild (pull-to-refresh, a conditional section appearing) never replays it.
class _Reveal extends StatelessWidget {
  final int index;
  final Widget child;
  const _Reveal({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index.clamp(0, 6) * 70),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: c)),
    );
  }
}
