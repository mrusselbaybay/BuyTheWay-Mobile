import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../chat/driver_chat_controller.dart';
import '../driver_models.dart';
import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';
import 'assigned_delivery_detail_screen.dart';
import '../../../services/remittance_api_service.dart';
import '../../remittances/remittances_screen.dart';

/// "Mission Control" redesign of the Deliveries tab — deliveries the
/// logistics team has assigned to this driver, the new occupant of the
/// bottom-nav slot History used to hold (see widgets/driver_nav_bar.dart).
/// Read-only as a queue by design: starting a run still happens through
/// the Home tab's active-delivery flow, so this screen is purely "what
/// dispatch has handed me" — completing a step still routes through
/// [AssignedDeliveryDetailScreen]'s photo-gated actions, never instantly
/// from here.
///
/// Backed by a real fetch — `GET /api/driver/deliveries`, loaded by
/// DriverShell into [deliveries] — not hardcoded data. The "Live Pulse"
/// counts, the "Priority Alert" pick, and the delayed-item heuristic below
/// are all derived client-side from that same list, since the API doesn't
/// (yet) carry a due-by/SLA field of its own — see [_isAtRisk]'s docblock.
///
/// History remains one tap away via the app-bar icon shortcut — same
/// "demoted from a tab to a compact action" pattern already used for
/// Settings on the Account screen.
class DriverDeliveriesScreen extends StatefulWidget {
  final List<AssignedDelivery> deliveries;
  final String accessToken;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenHistory;
  final DriverChatController controller;

  const DriverDeliveriesScreen({
    super.key,
    required this.deliveries,
    required this.accessToken,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onOpenHistory,
    required this.controller,
  });

  @override
  State<DriverDeliveriesScreen> createState() => _DriverDeliveriesScreenState();
}

/// A quick filter driven by tapping either a Live Pulse card or a status
/// chip — [delayed] has no matching [AssignedDeliveryStatus] since it's a
/// derived, not a stored, state (see [_isAtRisk]).
enum _QuickFilter { all, toPickUp, toDeliver, delivered, delayed }

class _DriverDeliveriesScreenState extends State<DriverDeliveriesScreen> {
  _QuickFilter _filter = _QuickFilter.all;
  bool _alertExpanded = true;

  /// Heuristic "this needs attention" flag — the schema has no per-order
  /// due-by/SLA timestamp to compare against, so this stands in for one:
  /// anything not yet delivered that's been sitting for more than half a
  /// working day since it was assigned. Good enough to surface genuinely
  /// stale rows on today's queue; not a substitute for a real SLA field if
  /// one gets added to the API later.
  static const _atRiskAfter = Duration(hours: 6);

  /// Every status a delivery is "done" at from this rider's perspective —
  /// nothing left to act on. Includes the cross-region transfer leg's own
  /// terminal state (transferred) alongside the normal delivered/handedOver.
  bool _isDone(AssignedDelivery d) =>
      d.status == AssignedDeliveryStatus.delivered ||
      d.status == AssignedDeliveryStatus.handedOver ||
      d.status == AssignedDeliveryStatus.awaitingInventory ||
      d.status == AssignedDeliveryStatus.transferred;

  bool _isAtRisk(AssignedDelivery d) {
    if (_isDone(d)) return false;
    final since = d.assignedAt;
    if (since == null) return false;
    return DateTime.now().difference(since) > _atRiskAfter;
  }

  List<AssignedDelivery> get _filtered {
    final all = widget.deliveries;
    switch (_filter) {
      case _QuickFilter.all:
        return all;
      case _QuickFilter.toPickUp:
        return all
            .where((d) => d.status == AssignedDeliveryStatus.assigned || d.status == AssignedDeliveryStatus.transferAssigned)
            .toList();
      case _QuickFilter.toDeliver:
        return all
            .where((d) => d.status == AssignedDeliveryStatus.pickedUp || d.status == AssignedDeliveryStatus.readyToTransfer)
            .toList();
      case _QuickFilter.delivered:
        return all.where(_isDone).toList();
      case _QuickFilter.delayed:
        return all.where(_isAtRisk).toList();
    }
  }

  void _setFilter(_QuickFilter f) {
    HapticFeedback.selectionClick();
    setState(() => _filter = _filter == f ? _QuickFilter.all : f);
  }

  /// The single most-at-risk row across the whole list (not just the
  /// current filter) — oldest not-yet-delivered assignment first. Null
  /// when nothing qualifies, in which case the banner just doesn't render.
  AssignedDelivery? get _priorityAlert {
    final candidates = widget.deliveries
        .where((d) => !_isDone(d) && d.assignedAt != null)
        .toList()
      ..sort((a, b) => a.assignedAt!.compareTo(b.assignedAt!));
    return candidates.isEmpty ? null : candidates.first;
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone.trim());
    try {
      HapticFeedback.lightImpact();
      if (!await launchUrl(uri)) throw Exception('launch failed');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start a call. Please dial manually.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _openDetail(AssignedDelivery delivery) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AssignedDeliveryDetailScreen(delivery: delivery, accessToken: widget.accessToken, controller: widget.controller)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    final total = widget.deliveries.length;
    final inProgress = widget.deliveries
        .where((d) => d.status == AssignedDeliveryStatus.pickedUp || d.status == AssignedDeliveryStatus.readyToTransfer)
        .length;
    final delayed = widget.deliveries.where(_isAtRisk).length;
    final completed = widget.deliveries.where(_isDone).length;
    final alert = _priorityAlert;

    return Scaffold(
      backgroundColor: DriverColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DriverGradientHeader(
              title: 'Deliveries',
              subtitle: "Mission control for today's run",
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Remittances',
                  icon: const Icon(Icons.currency_exchange_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RemittancesScreen(accessToken: widget.accessToken, role: RemittanceRole.courier))),
                ),
                IconButton(
                onPressed: widget.onOpenHistory,
                tooltip: 'History',
                icon: const Icon(Icons.history_rounded, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.15)),
              ),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                color: DriverColors.primary,
                onRefresh: widget.onRefresh,
                child: widget.error != null
                    ? _errorList()
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                        children: [
                          _LivePulseStrip(
                            total: total,
                            inProgress: inProgress,
                            delayed: delayed,
                            completed: completed,
                            active: _filter,
                            onTapTotal: () => _setFilter(_QuickFilter.all),
                            onTapInProgress: () => _setFilter(_QuickFilter.toDeliver),
                            onTapDelayed: () => _setFilter(_QuickFilter.delayed),
                            onTapCompleted: () => _setFilter(_QuickFilter.delivered),
                          ),
                          if (alert != null) ...[
                            const SizedBox(height: 14),
                            _PriorityAlertBanner(
                              delivery: alert,
                              expanded: _alertExpanded,
                              onToggle: () => setState(() => _alertExpanded = !_alertExpanded),
                              onCall: () => _call(alert.customerContactNo),
                              onTap: () => _openDetail(alert),
                            ),
                          ],
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 34,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _filterChip('All', _filter == _QuickFilter.all, () => _setFilter(_QuickFilter.all)),
                                const SizedBox(width: 8),
                                _filterChip('To pick up', _filter == _QuickFilter.toPickUp, () => _setFilter(_QuickFilter.toPickUp)),
                                const SizedBox(width: 8),
                                _filterChip('To deliver', _filter == _QuickFilter.toDeliver, () => _setFilter(_QuickFilter.toDeliver)),
                                const SizedBox(width: 8),
                                _filterChip('Delivered', _filter == _QuickFilter.delivered, () => _setFilter(_QuickFilter.delivered)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.loading ? 'Loading…' : '${results.length} deliver${results.length == 1 ? 'y' : 'ies'}',
                            style: DriverText.caption,
                          ),
                          const SizedBox(height: 10),
                          if (widget.loading && widget.deliveries.isEmpty)
                            ...List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: DriverShimmerBox(height: 158, radius: 16)))
                          else if (results.isEmpty)
                            DriverEmptyState(
                              icon: Icons.inventory_2_rounded,
                              title: 'No deliveries assigned',
                              subtitle: widget.deliveries.isEmpty ? 'Deliveries the logistics team assigns to you will show up here.' : 'No deliveries match this filter.',
                            )
                          else
                            ...results.map((d) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _MissionCard(
                                    delivery: d,
                                    atRisk: _isAtRisk(d),
                                    onTap: () => _openDetail(d),
                                    onCall: d.customerContactNo == null ? null : () => _call(d.customerContactNo),
                                  ),
                                )),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorList() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
              const Text('Couldn\'t load deliveries', style: DriverText.sectionTitle, textAlign: TextAlign.center),
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

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: selected ? DriverColors.primary : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? Colors.transparent : DriverColors.border)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : DriverColors.textSecondary)),
      ),
    );
  }
}

/// The "Live Pulse" horizontal stat strip — tap any card to filter the list
/// below to that state.
class _LivePulseStrip extends StatelessWidget {
  final int total;
  final int inProgress;
  final int delayed;
  final int completed;
  final _QuickFilter active;
  final VoidCallback onTapTotal;
  final VoidCallback onTapInProgress;
  final VoidCallback onTapDelayed;
  final VoidCallback onTapCompleted;

  const _LivePulseStrip({
    required this.total,
    required this.inProgress,
    required this.delayed,
    required this.completed,
    required this.active,
    required this.onTapTotal,
    required this.onTapInProgress,
    required this.onTapDelayed,
    required this.onTapCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _PulseCard(label: 'Total', value: '$total', icon: Icons.inventory_2_rounded, selected: active == _QuickFilter.all, onTap: onTapTotal),
          const SizedBox(width: 10),
          _PulseCard(label: 'In progress', value: '$inProgress', icon: Icons.local_shipping_rounded, selected: active == _QuickFilter.toDeliver, onTap: onTapInProgress, pulse: inProgress > 0),
          const SizedBox(width: 10),
          _PulseCard(label: 'Delayed', value: '$delayed', icon: Icons.warning_amber_rounded, selected: active == _QuickFilter.delayed, onTap: onTapDelayed, warn: delayed > 0),
          const SizedBox(width: 10),
          _PulseCard(label: 'Completed', value: '$completed', icon: Icons.check_circle_rounded, selected: active == _QuickFilter.delivered, onTap: onTapCompleted),
        ],
      ),
    );
  }
}

class _PulseCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final bool pulse;
  final bool warn;
  final VoidCallback onTap;

  const _PulseCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.pulse = false,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = warn ? DriverColors.warning : DriverColors.primary;
    return GestureDetector(
      onTap: onTap,
      // These are small, fixed-size stat tiles, not body copy — clamping
      // text scaling here (rather than fighting an ever-larger pixel
      // budget) is what actually guarantees no overflow no matter what
      // font-size the device's accessibility settings use. The strip's
      // own height (108) still gives normal-scale text comfortable room.
      child: MediaQuery.withNoTextScaling(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 118,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? Colors.transparent : DriverColors.border),
            boxShadow: selected ? DriverColors.glow(accent, blur: 14, spread: 0.5) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: selected ? Colors.white : accent),
                  if (pulse) ...[const SizedBox(width: 5), _PulsingDot(color: selected ? Colors.white : DriverColors.primary)],
                ],
              ),
              const SizedBox(height: 10),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: selected ? Colors.white : DriverColors.textPrimary)),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white.withOpacity(0.9) : DriverColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small breathing dot used for "live" states — no animation package
/// required, just a looping AnimationController driving opacity.
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}

/// Collapsible "most urgent delivery" banner — glowing Teal border, quick
/// call action.
class _PriorityAlertBanner extends StatelessWidget {
  final AssignedDelivery delivery;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onCall;
  final VoidCallback onTap;

  const _PriorityAlertBanner({
    required this.delivery,
    required this.expanded,
    required this.onToggle,
    required this.onCall,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DriverColors.primary.withOpacity(0.5), width: 1.4),
        boxShadow: DriverColors.glow(DriverColors.primary, blur: 20, spread: 0),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  const Icon(Icons.priority_high_rounded, size: 16, color: DriverColors.primary),
                  const SizedBox(width: 6),
                  const Text('Priority alert', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: DriverColors.primary)),
                  const Spacer(),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: expanded ? 0.5 : 0,
                    child: const Icon(Icons.expand_more_rounded, color: DriverColors.primary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onTap,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('#${delivery.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                    const SizedBox(width: 8),
                                    Flexible(child: Text(delivery.customerName, style: DriverText.caption, overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    DriverDispatchChip(label: delivery.dispatchedByLabel),
                                    if (delivery.isReturn)
                                      DriverReturnChip(returned: delivery.isReturned),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (delivery.customerContactNo != null) ...[
                            const SizedBox(width: 10),
                            DriverCallFab(onTap: onCall),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A delivery card with swipe-to-reveal actions: swipe left reveals Call
/// and Details buttons; swipe right is a quick shortcut into the full
/// detail screen (where the actual photo-gated pickup/delivery actions
/// live — a swipe can't complete either step by itself, since both require
/// proof-of-parcel photo).
class _MissionCard extends StatefulWidget {
  final AssignedDelivery delivery;
  final bool atRisk;
  final VoidCallback onTap;
  final VoidCallback? onCall;

  const _MissionCard({required this.delivery, required this.atRisk, required this.onTap, required this.onCall});

  @override
  State<_MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<_MissionCard> {
  static const double _actionsWidth = 96;
  double _drag = 0;

  (String, Color, IconData) get _actionTag {
    switch (widget.delivery.status) {
      case AssignedDeliveryStatus.failedAttempt:
        return ('Failed Attempt', DriverColors.warning, Icons.warning_amber_rounded);
      case AssignedDeliveryStatus.needsDispatcherReview:
        return ('Needs Dispatcher Review', DriverColors.error, Icons.support_agent_rounded);
      case AssignedDeliveryStatus.assigned:
        return ('To pick up', DriverColors.warning, Icons.storefront_rounded);
      case AssignedDeliveryStatus.pickedUp:
        return ('To deliver', DriverColors.info, Icons.local_shipping_rounded);
      case AssignedDeliveryStatus.delivered:
        return ('Delivered', DriverColors.success, Icons.check_circle_rounded);
      case AssignedDeliveryStatus.handedOver:
        return ('Handed over', DriverColors.textSecondary, Icons.assignment_turned_in_rounded);
      case AssignedDeliveryStatus.awaitingInventory:
        return ('Picked up', DriverColors.success, Icons.check_circle_rounded);
      // Cross-region transfer leg — see AssignedDeliveryStatus's docblock.
      // Only reached when dispatch had to hand this leg to a courier who
      // didn't already have the parcel (no one to reuse from the pickup
      // leg) — same "To pick up" framing as a local pickup for that
      // reason. The common case — the same courier who collected it
      // carries it straight on — skips this status entirely and starts
      // at readyToTransfer instead (see Api\Logistics\
      // ParcelAssignmentController::acceptTransferRequest on the web
      // side).
      case AssignedDeliveryStatus.transferAssigned:
        return ('To pick up', DriverColors.warning, Icons.storefront_rounded);
      case AssignedDeliveryStatus.readyToTransfer:
        return ('To deliver', DriverColors.info, Icons.compare_arrows_rounded);
      case AssignedDeliveryStatus.transferred:
        return ('Delivered', DriverColors.success, Icons.check_circle_rounded);
    }
  }

  String _timeAgo(DateTime? d) {
    if (d == null) return 'Unknown time';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _drag = (_drag + details.delta.dx).clamp(-_actionsWidth, 36);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_drag > 26) {
      // Swipe-right past the threshold: quick-open the detail screen, then
      // snap back closed.
      HapticFeedback.selectionClick();
      widget.onTap();
      setState(() => _drag = 0);
      return;
    }
    setState(() => _drag = _drag < -_actionsWidth / 2 ? -_actionsWidth : 0);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.delivery;
    final (tagLabel, tagColor, tagIcon) = _actionTag;
    final completed = d.status == AssignedDeliveryStatus.delivered || d.status == AssignedDeliveryStatus.transferred;
    final handedOver = d.status == AssignedDeliveryStatus.handedOver || d.status == AssignedDeliveryStatus.awaitingInventory;
    final done = completed || handedOver;
    final barColor = widget.atRisk
        ? DriverColors.warning
        : (done ? DriverColors.border : DriverColors.primary);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Revealed actions sit behind the card, on its right edge.
          Positioned.fill(
            child: Container(
              color: DriverColors.background,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onCall != null) ...[
                    _RevealAction(icon: Icons.call_rounded, color: DriverColors.primary, onTap: widget.onCall!),
                    const SizedBox(width: 8),
                  ],
                  _RevealAction(icon: Icons.arrow_forward_ios_rounded, color: DriverColors.textSecondary, onTap: widget.onTap),
                ],
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: Transform.translate(
              offset: Offset(_drag, 0),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DriverColors.border)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.onTap,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(width: 5, decoration: BoxDecoration(color: barColor, borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)))),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(8)),
                                      child: Text('#${d.orderNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DriverColors.primaryDark)),
                                    ),
                                    const Spacer(),
                                    if (widget.atRisk) ...[
                                      const Icon(Icons.warning_amber_rounded, size: 13, color: DriverColors.warning),
                                      const SizedBox(width: 3),
                                    ],
                                    Text(_timeAgo(completed ? d.deliveredAt : (d.handedOffAt ?? d.assignedAt)), style: DriverText.caption),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (d.deliveryAttempt.reason != null && (d.status == AssignedDeliveryStatus.failedAttempt || d.status == AssignedDeliveryStatus.needsDispatcherReview))
                                  Text(d.deliveryAttempt.reason!, style: DriverText.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                                Text(d.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                                const SizedBox(height: 2),
                                Text(
                                  (d.status == AssignedDeliveryStatus.assigned || d.status == AssignedDeliveryStatus.transferAssigned)
                                      // A return's first leg is collected at the buyer's door.
                                      ? (d.returnPickupAddress ?? d.pickupLabel)
                                      : d.dropoffLabel,
                                  style: DriverText.body,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                DriverDispatchChip(label: d.dispatchedByLabel),
                                  const SizedBox(height: 6),
                                  Text("You'll earn ₱${d.earningPreviewCents ~/ 100}.${(d.earningPreviewCents % 100).toString().padLeft(2, '0')}", style: const TextStyle(color: DriverColors.primaryDark, fontWeight: FontWeight.w700)),
                                  if (d.earningIsEstimate) const Text('Estimate until the final route is confirmed', style: DriverText.caption),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    // Status and return tag stack vertically.
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        DriverStatusBadge(label: tagLabel, color: tagColor, icon: tagIcon),
                                        if (d.isReturn) ...[
                                          const SizedBox(height: 4),
                                          DriverReturnChip(returned: d.isReturned),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.inventory_2_outlined, size: 13, color: DriverColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text('${d.parcels}', style: DriverText.caption),
                                    const Spacer(),
                                    Text(
                                      done ? 'Tap for details' : 'Swipe or tap',
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: DriverColors.primary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _RevealAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: DriverColors.border)),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
