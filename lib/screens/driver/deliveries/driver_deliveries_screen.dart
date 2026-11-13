import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/api_service.dart';
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
/// DriverShell into [deliveries]. Queue counts and the six-hour attention
/// hint are derived from that list because the API does not yet carry a
/// due-by/SLA field.
///
/// History remains one tap away via the app-bar icon shortcut — same
/// "demoted from a tab to a compact action" pattern already used for
/// Settings on the Account screen.
class DriverDeliveriesScreen extends StatefulWidget {
  final List<AssignedDelivery> deliveries;
  final Map<String, dynamic>? capacity;
  final String accessToken;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenHistory;
  final DriverChatController controller;

  const DriverDeliveriesScreen({
    super.key,
    required this.deliveries,
    this.capacity,
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

/// A quick queue filter. Attention is derived from assignment age, not a
/// backend delivery status (see [_isAtRisk]).
enum _QuickFilter { all, toPickUp, toDeliver, attention, done }

class _DriverDeliveriesScreenState extends State<DriverDeliveriesScreen> {
  _QuickFilter _filter = _QuickFilter.all;

  /// Local age heuristic until the API supplies per-order due times.
  static const _atRiskAfter = Duration(hours: 6);

  /// Every status where there is no further action for this courier.
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

  bool _needsAttention(AssignedDelivery d) =>
      _isAtRisk(d) ||
      d.status == AssignedDeliveryStatus.failedAttempt ||
      d.status == AssignedDeliveryStatus.needsDispatcherReview;

  List<AssignedDelivery> get _filtered {
    final all = widget.deliveries;
    switch (_filter) {
      case _QuickFilter.all:
        return all;
      case _QuickFilter.toPickUp:
        return all.where((d) => d.isPickupTask).toList();
      case _QuickFilter.toDeliver:
        return all.where((d) => d.isDeliveryTask).toList();
      case _QuickFilter.done:
        return all.where(_isDone).toList();
      case _QuickFilter.attention:
        return all.where(_needsAttention).toList();
    }
  }

  void _setFilter(_QuickFilter f) {
    HapticFeedback.selectionClick();
    setState(() => _filter = f);
  }

  /// The oldest parcel needing attention. Age is a local heuristic, not an
  /// SLA or dispatch priority.
  AssignedDelivery? get _attentionDelivery {
    final candidates = widget.deliveries.where(_needsAttention).toList()
      ..sort((a, b) => (a.assignedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(b.assignedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
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
        const SnackBar(
            content: Text('Could not start a call. Please dial manually.'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _openDetail(AssignedDelivery delivery) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => AssignedDeliveryDetailScreen(
              delivery: delivery,
              accessToken: widget.accessToken,
              controller: widget.controller)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    final total = widget.deliveries.length;
    final inProgress = widget.deliveries.where((d) => d.isDeliveryTask).length;
    final needsAttention = widget.deliveries.where(_needsAttention).length;
    final completed = widget.deliveries.where(_isDone).length;
    final attention = _attentionDelivery;

    return Scaffold(
      backgroundColor: DriverColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _CourierDispatchHeader(
              total: total,
              onHistory: widget.onOpenHistory,
              onRemittances: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RemittancesScreen(
                      accessToken: widget.accessToken,
                      role: RemittanceRole.courier))),
            ),
            Expanded(
              child: RefreshIndicator(
                color: DriverColors.primary,
                onRefresh: widget.onRefresh,
                child: widget.error != null
                    ? _errorList()
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
                        children: [
                          if (widget.capacity != null) ...[
                            _CapacityRibbon(capacity: widget.capacity!),
                            const SizedBox(height: 16),
                          ],
                          if (attention != null) ...[
                            _AttentionRibbon(
                              delivery: attention,
                              onTap: () => _openDetail(attention),
                              onCall: attention.customerContactNo == null
                                  ? null
                                  : () => _call(attention.customerContactNo),
                            ),
                            const SizedBox(height: 18),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('YOUR QUEUE',
                                        style: DriverText.label.copyWith(
                                            color: DriverColors.primaryDark,
                                            letterSpacing: 1.2)),
                                    const SizedBox(height: 3),
                                    Text(
                                        widget.loading
                                            ? 'Finding your parcels'
                                            : 'Parcels in your care',
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: DriverColors.textPrimary,
                                            letterSpacing: -0.5)),
                                  ],
                                ),
                              ),
                              Text(
                                  widget.loading
                                      ? '…'
                                      : '${results.length} shown',
                                  style: DriverText.caption),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _QueueFilterBar(
                            active: _filter,
                            counts: {
                              _QuickFilter.all: total,
                              _QuickFilter.toPickUp: widget.deliveries
                                  .where((d) => d.isPickupTask)
                                  .length,
                              _QuickFilter.toDeliver: inProgress,
                              _QuickFilter.attention: needsAttention,
                              _QuickFilter.done: completed,
                            },
                            onSelect: _setFilter,
                          ),
                          const SizedBox(height: 14),
                          if (widget.loading && widget.deliveries.isEmpty)
                            ...List.generate(
                                3,
                                (_) => const Padding(
                                    padding: EdgeInsets.only(bottom: 10),
                                    child: DriverShimmerBox(
                                        height: 158, radius: 16)))
                          else if (results.isEmpty)
                            DriverEmptyState(
                              icon: Icons.inventory_2_rounded,
                              title: 'No deliveries assigned',
                              subtitle: widget.deliveries.isEmpty
                                  ? 'Deliveries the logistics team assigns to you will show up here.'
                                  : 'No deliveries match this filter.',
                            )
                          else
                            ...results.map((d) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _MissionCard(
                                    delivery: d,
                                    atRisk: _isAtRisk(d),
                                    onTap: () => _openDetail(d),
                                    onCall: d.customerContactNo == null
                                        ? null
                                        : () => _call(d.customerContactNo),
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
          decoration: BoxDecoration(
              color: DriverColors.errorSurface,
              borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.wifi_off_rounded,
                    color: DriverColors.error, size: 24),
              ),
              const SizedBox(height: 12),
              const Text('Couldn\'t load deliveries',
                  style: DriverText.sectionTitle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(widget.error!,
                  style: DriverText.caption, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: widget.onRefresh,
                style: ElevatedButton.styleFrom(
                    backgroundColor: DriverColors.primary,
                    foregroundColor: Colors.white),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourierDispatchHeader extends StatelessWidget {
  const _CourierDispatchHeader(
      {required this.total,
      required this.onHistory,
      required this.onRemittances});

  final int total;
  final VoidCallback onHistory;
  final VoidCallback onRemittances;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom:
                BorderSide(color: DriverColors.border.withValues(alpha: 0.8))),
        boxShadow: [
          BoxShadow(
            color: DriverColors.textPrimary.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 14, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: DriverColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'RIDER  /  FIELD ROUTE',
                        style: DriverText.label.copyWith(
                          color: DriverColors.textSecondary,
                          letterSpacing: 1.0,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Deliveries',
                    style: TextStyle(
                      fontSize: 27,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      color: DriverColors.textPrimary,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$total ${total == 1 ? 'parcel' : 'parcels'} assigned',
                    style: const TextStyle(
                      color: DriverColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _HeaderAction(
                icon: Icons.payments_outlined,
                tooltip: 'Remittances',
                onTap: onRemittances),
            const SizedBox(width: 6),
            _HeaderAction(
                icon: Icons.history_toggle_off_rounded,
                tooltip: 'History',
                onTap: onHistory),
          ],
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
            backgroundColor: DriverColors.background,
            side: BorderSide(color: DriverColors.border.withValues(alpha: 0.9)),
            foregroundColor: DriverColors.textSecondary),
        icon: Icon(icon, size: 19),
      );
}

class _CapacityRibbon extends StatelessWidget {
  const _CapacityRibbon({required this.capacity});
  final Map<String, dynamic> capacity;

  @override
  Widget build(BuildContext context) {
    final used = (capacity['used_units'] as num?)?.toDouble() ?? 0;
    final max = (capacity['max_units'] as num?)?.toDouble() ?? 0;
    final ratio = max <= 0 ? 0.0 : (used / max).clamp(0.0, 1.0);
    final breakdown = capacity['breakdown'] as Map?;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: DriverColors.border.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF0F766E).withValues(alpha: 0.045),
                blurRadius: 16,
                offset: const Offset(0, 5))
          ]),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: DriverColors.primarySurface,
                      borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.local_shipping_rounded,
                      size: 17, color: DriverColors.primaryDark)),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('Vehicle load',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: DriverColors.textPrimary))),
              Text(
                  used.toStringAsFixed(used == used.roundToDouble() ? 0 : 1),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: DriverColors.primaryDark)),
              Text(
                  ' / ${max.toStringAsFixed(max == max.roundToDouble() ? 0 : 1)} units',
                  style: DriverText.caption),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    backgroundColor: DriverColors.primarySurface,
                    color: ratio >= 0.9
                        ? DriverColors.warning
                        : DriverColors.primary),
              )),
          const SizedBox(height: 7),
          Row(children: [
            _LoadSize(label: 'S', value: breakdown?['Small']),
            const SizedBox(width: 12),
            _LoadSize(label: 'M', value: breakdown?['Medium']),
            const SizedBox(width: 12),
            _LoadSize(label: 'L', value: breakdown?['Large']),
            const Spacer(),
            Text(
              max <= 0
                  ? 'CAPACITY UNKNOWN'
                  : used >= max
                      ? 'FULL LOAD'
                      : '${(max - used).clamp(0, double.infinity).toStringAsFixed((max - used) == (max - used).roundToDouble() ? 0 : 1)} UNITS FREE',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.75,
                  color: ratio >= 0.9
                      ? DriverColors.warning
                      : DriverColors.textSecondary),
            ),
          ]),
        ],
      ),
    );
  }
}

class _LoadSize extends StatelessWidget {
  const _LoadSize({required this.label, required this.value});
  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) => Text('$label  ${value ?? 0}',
      style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: DriverColors.textSecondary));
}

class _AttentionRibbon extends StatelessWidget {
  const _AttentionRibbon(
      {required this.delivery, required this.onTap, this.onCall});
  final AssignedDelivery delivery;
  final VoidCallback onTap;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF2D39A))),
            child: Row(children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFE9BD),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.schedule_outlined,
                      size: 18, color: Color(0xFFAD6200))),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        delivery.status ==
                                AssignedDeliveryStatus.needsDispatcherReview
                            ? 'Needs dispatch review'
                            : delivery.status ==
                                    AssignedDeliveryStatus.failedAttempt
                                ? 'Delivery attempt failed'
                                : 'No update in 6h+',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF70420A))),
                    const SizedBox(height: 2),
                    Text(
                        '#${delivery.orderNumber}  ·  ${delivery.customerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF805B2B),
                            fontWeight: FontWeight.w500)),
                  ])),
              if (onCall != null)
                IconButton(
                    tooltip: 'Call customer',
                    onPressed: onCall,
                    icon: const Icon(Icons.call_outlined,
                        size: 18, color: DriverColors.primaryDark)),
              if (onCall == null)
                const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 18, color: Color(0xFF805B2B))),
            ]),
          ),
        ),
      );
}

class _QueueFilterBar extends StatelessWidget {
  const _QueueFilterBar(
      {required this.active, required this.counts, required this.onSelect});
  final _QuickFilter active;
  final Map<_QuickFilter, int> counts;
  final ValueChanged<_QuickFilter> onSelect;

  static const _items = [
    (_QuickFilter.all, 'All', Icons.view_list_outlined),
    (_QuickFilter.toPickUp, 'Pickup', Icons.storefront_outlined),
    (_QuickFilter.toDeliver, 'On route', Icons.local_shipping_outlined),
    (_QuickFilter.attention, 'Needs a look', Icons.schedule_outlined),
    (_QuickFilter.done, 'Done by you', Icons.task_alt_outlined),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            final (filter, label, icon) = _items[index];
            final selected = active == filter;
            final count = counts[filter] ?? 0;
            return Semantics(
              button: true,
              selected: selected,
              label: '$label, $count parcels',
              child: Material(
                color: selected ? DriverColors.primaryDark : Colors.white,
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  onTap: () => onSelect(filter),
                  borderRadius: BorderRadius.circular(13),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 210),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                            color: selected
                                ? DriverColors.primaryDark
                                : DriverColors.border)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon,
                          size: 14,
                          color: selected
                              ? Colors.white
                              : DriverColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : DriverColors.textSecondary)),
                      const SizedBox(width: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                                scale: animation, child: child)),
                        child: Text('$count',
                            key: ValueKey('$filter-$count-$selected'),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? const Color(0xFFD4FFF5)
                                    : DriverColors.primaryDark)),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      );
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

  const _MissionCard(
      {required this.delivery,
      required this.atRisk,
      required this.onTap,
      required this.onCall});

  @override
  State<_MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<_MissionCard> {
  static const double _actionsWidth = 116;
  double _drag = 0;

  Widget _productImage(String url) {
    const fallback =
        Icon(Icons.image_outlined, color: DriverColors.textSecondary, size: 23);
    if (url.startsWith('data:image/')) {
      try {
        final comma = url.indexOf(',');
        if (comma < 0) return fallback;
        final payload = url.substring(comma + 1);
        final bytes = url.substring(0, comma).contains(';base64')
            ? base64Decode(payload)
            : Uint8List.fromList(Uri.decodeComponent(payload).codeUnits);
        return Image.memory(bytes,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback);
      } catch (_) {
        return fallback;
      }
    }
    return Image.network(url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback);
  }

  String? _resolveProductImage(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.hasScheme) return uri.toString();
    final origin = Uri.parse(ApiService.baseUrl).replace(path: '');
    return origin
        .resolve('/${raw.replaceFirst(RegExp(r'^/+'), '')}')
        .toString();
  }

  (String, Color, IconData) get _actionTag {
    switch (widget.delivery.status) {
      case AssignedDeliveryStatus.failedAttempt:
        return (
          'Failed Attempt',
          DriverColors.warning,
          Icons.warning_amber_outlined
        );
      case AssignedDeliveryStatus.needsDispatcherReview:
        return (
          'Needs Dispatcher Review',
          DriverColors.error,
          Icons.support_agent_outlined
        );
      case AssignedDeliveryStatus.assigned:
        return widget.delivery.isDeliveryLeg
            ? ('To deliver', DriverColors.info, Icons.local_shipping_outlined)
            : ('To pick up', DriverColors.warning, Icons.storefront_outlined);
      case AssignedDeliveryStatus.waitingApproval:
        return (
          'Waiting approval',
          DriverColors.warning,
          Icons.hourglass_empty_rounded
        );
      case AssignedDeliveryStatus.pickedUp:
        return ('To deliver', DriverColors.info, Icons.local_shipping_outlined);
      case AssignedDeliveryStatus.delivered:
        return (
          'Delivered',
          DriverColors.success,
          Icons.check_circle_outline_rounded
        );
      case AssignedDeliveryStatus.handedOver:
        return (
          'Handed over',
          DriverColors.textSecondary,
          Icons.assignment_turned_in_outlined
        );
      case AssignedDeliveryStatus.awaitingInventory:
        return (
          'Picked up',
          DriverColors.success,
          Icons.check_circle_outline_rounded
        );
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
        return ('To pick up', DriverColors.warning, Icons.storefront_outlined);
      case AssignedDeliveryStatus.readyToTransfer:
        return ('To deliver', DriverColors.info, Icons.compare_arrows_rounded);
      case AssignedDeliveryStatus.transferred:
        return (
          'Delivered',
          DriverColors.success,
          Icons.check_circle_outline_rounded
        );
    }
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'Time unavailable';
    final local = date.toLocal();
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
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day} · $hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
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
    final completed = d.status == AssignedDeliveryStatus.delivered ||
        d.status == AssignedDeliveryStatus.transferred;
    final handedOver = d.status == AssignedDeliveryStatus.handedOver ||
        d.status == AssignedDeliveryStatus.awaitingInventory;
    final done = completed || handedOver;
    final nextIsPickup = d.isPickupTask;
    final nextStop = switch (d.status) {
      AssignedDeliveryStatus.awaitingInventory =>
        'Picked up · waiting for logistics scan',
      AssignedDeliveryStatus.handedOver => 'Handed back to Logistics',
      AssignedDeliveryStatus.delivered => 'Delivered to the customer',
      AssignedDeliveryStatus.transferred => 'Transferred to the next hub',
      _ => nextIsPickup
          ? (d.isReturn
              ? (d.returnPickupAddress ?? d.pickupLabel)
              : (d.pickupAddress ?? d.pickupLabel))
          : d.dropoffLabel,
    };
    final nextStopLabel = nextIsPickup
        ? (d.status == AssignedDeliveryStatus.waitingApproval
            ? 'HANDOFF REQUEST'
            : 'PICK UP FROM')
        : (done ? 'LATEST UPDATE' : 'DELIVER TO');
    final activityAt = completed
        ? (d.deliveredAt ?? d.transferredAt)
        : (d.handedOffAt ?? d.assignedAt);
    String? productImage;
    for (final item in d.items) {
      productImage = _resolveProductImage(item.image);
      if (productImage != null) break;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
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
                    _RevealAction(
                        icon: Icons.call_outlined,
                        label: 'Call customer',
                        color: DriverColors.primary,
                        onTap: widget.onCall!),
                    const SizedBox(width: 8),
                  ],
                  _RevealAction(
                      icon: Icons.arrow_forward_ios_rounded,
                      label: 'Open parcel details',
                      color: DriverColors.textSecondary,
                      onTap: widget.onTap),
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
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: widget.atRisk
                          ? const Color(0xFFECCB8C)
                          : DriverColors.border.withValues(alpha: 0.9)),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF123A38).withValues(alpha: 0.045),
                        blurRadius: 16,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: widget.onTap,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: DriverColors.background,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: productImage == null
                                        ? const Icon(Icons.image_outlined,
                                            color: DriverColors.textSecondary,
                                            size: 23)
                                        : _productImage(productImage),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(d.customerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14.5,
                                                color:
                                                    DriverColors.textPrimary)),
                                        const SizedBox(height: 3),
                                        Row(children: [
                                          if (widget.atRisk) ...[
                                            const Icon(Icons.schedule_rounded,
                                                size: 12,
                                                color: DriverColors.warning),
                                            const SizedBox(width: 4),
                                          ],
                                          Flexible(
                                            child: Text(
                                                _formatDateTime(activityAt),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: DriverText.caption),
                                          ),
                                        ]),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  DriverStatusBadge(
                                      label: tagLabel,
                                      color: tagColor,
                                      icon: tagIcon),
                                ]),
                                if (d.outOfArea) ...[
                                  const SizedBox(height: 8),
                                  const DriverStatusBadge(
                                    label: 'Out of area',
                                    color: DriverColors.warning,
                                    icon: Icons.route_outlined,
                                  ),
                                ],
                                if (d.deliveryAttempt.reason != null &&
                                    (d.status ==
                                            AssignedDeliveryStatus
                                                .failedAttempt ||
                                        d.status ==
                                            AssignedDeliveryStatus
                                                .needsDispatcherReview))
                                  Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(d.deliveryAttempt.reason!,
                                          style: DriverText.caption,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis)),
                                const SizedBox(height: 12),
                                Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                          width: 25,
                                          height: 25,
                                          margin: const EdgeInsets.only(top: 1),
                                          decoration: BoxDecoration(
                                              color: nextIsPickup
                                                  ? DriverColors.primarySurface
                                                  : const Color(0xFFECF4F5),
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: Icon(
                                              nextIsPickup
                                                  ? Icons.storefront_outlined
                                                  : Icons.flag_outlined,
                                              size: 14,
                                              color: nextIsPickup
                                                  ? DriverColors.primaryDark
                                                  : const Color(0xFF527177))),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(nextStopLabel,
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.9,
                                                    color: nextIsPickup
                                                        ? DriverColors
                                                            .primaryDark
                                                        : DriverColors
                                                            .textSecondary)),
                                            const SizedBox(height: 2),
                                            Text(nextStop,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    height: 1.25,
                                                    fontWeight: FontWeight.w600,
                                                    color: DriverColors
                                                        .textPrimary),
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ])),
                                    ]),
                                const SizedBox(height: 9),
                                Row(children: [
                                  const Icon(Icons.local_shipping_outlined,
                                      size: 13,
                                      color: DriverColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                      child: Text(d.dispatchedByLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: DriverText.caption)),
                                  const SizedBox(width: 8),
                                  Text(
                                      '₱${(d.earningPreviewCents / 100).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          color: DriverColors.primaryDark,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12)),
                                  if (d.earningIsEstimate)
                                    const Text(' est.',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: DriverColors.textSecondary,
                                            fontWeight: FontWeight.w600)),
                                ]),
                                const SizedBox(height: 11),
                                Container(
                                    height: 1,
                                    color: DriverColors.border
                                        .withValues(alpha: 0.8)),
                                const SizedBox(height: 9),
                                Row(
                                  children: [
                                    const Icon(Icons.receipt_long_outlined,
                                        size: 15,
                                        color: DriverColors.textSecondary),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text('#${d.orderNumber}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: DriverText.caption),
                                    ),
                                    if (d.trackingNumber != null) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.qr_code_2_rounded,
                                          size: 14,
                                          color: DriverColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(d.trackingNumber!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: DriverText.caption),
                                      ),
                                    ] else
                                      const Spacer(),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (d.isReturn)
                                      DriverReturnChip(returned: d.isReturned),
                                    const Spacer(),
                                    const Icon(Icons.inventory_2_outlined,
                                        size: 14,
                                        color: DriverColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text('${d.parcels}',
                                        style: DriverText.caption),
                                    const SizedBox(width: 5),
                                    const Icon(Icons.chevron_right_rounded,
                                        size: 19,
                                        color: DriverColors.textSecondary),
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
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _RevealAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: DriverColors.border)),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
