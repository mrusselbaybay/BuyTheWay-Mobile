import 'dart:async';

import 'package:flutter/material.dart';

import '../driver_models.dart';
import '../driver_theme.dart';
import '../notifications/driver_notification_bell.dart';
import '../widgets/driver_shared_widgets.dart';

class DriverHomeScreen extends StatefulWidget {
  final bool isOnline;
  final DateTime? shiftStart;
  final DriverAccount account;
  final ActiveDelivery? activeDelivery;
  final List<DeliveryRequest> availableRequests;
  final double todayEarnings;
  final int completedToday;
  final VoidCallback onGoOnline;
  final ValueChanged<DeliveryRequest> onOpenRequest;
  final VoidCallback onContinueActiveDelivery;
  final Future<void> Function() onRefreshRequests;
  final int unreadNotifications;
  final VoidCallback onOpenNotifications;

  const DriverHomeScreen({
    super.key,
    required this.isOnline,
    required this.shiftStart,
    required this.account,
    required this.activeDelivery,
    required this.availableRequests,
    required this.todayEarnings,
    required this.completedToday,
    required this.onGoOnline,
    required this.onOpenRequest,
    required this.onContinueActiveDelivery,
    required this.onRefreshRequests,
    required this.unreadNotifications,
    required this.onOpenNotifications,
  });

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _loading = true;
  Timer? _clock;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _loading = false);
    });
    _tickElapsed();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => _tickElapsed());
  }

  @override
  void didUpdateWidget(covariant DriverHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tickElapsed();
  }

  void _tickElapsed() {
    if (!mounted) return;
    setState(() {
      _elapsed = widget.shiftStart == null ? Duration.zero : DateTime.now().difference(widget.shiftStart!);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriverColors.background,
      body: RefreshIndicator(
        color: DriverColors.primary,
        edgeOffset: MediaQuery.of(context).padding.top,
        onRefresh: widget.onRefreshRequests,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _earningsCard(context),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
              sliver: SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.activeDelivery != null) ...[
                        _activeDeliveryCard(context, widget.activeDelivery!),
                        const SizedBox(height: 24),
                      ],
                      DriverSectionHeader(title: widget.isOnline ? 'Available requests' : 'Requests'),
                      const SizedBox(height: 12),
                      _requestsSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 68),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: DriverColors.heroGradient),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.18), border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5)),
            child: Text(widget.account.avatarInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(widget.account.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              ],
            ),
          ),
          _statusToggle(),
          const SizedBox(width: 4),
          DriverNotificationBell(unread: widget.unreadNotifications, onTap: widget.onOpenNotifications),
        ],
      ),
    );
  }

  Widget _statusToggle() {
    final online = widget.isOnline;
    return Semantics(
      label: online ? 'You are online' : 'You are offline',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: online ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? const Color(0xFF6EE7B7) : Colors.white54)),
            const SizedBox(width: 6),
            Text(online ? 'Online' : 'Offline', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _earningsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("TODAY'S EARNINGS", style: DriverText.label),
          const SizedBox(height: 4),
          Text('₱${widget.todayEarnings.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 32, height: 1.1, color: DriverColors.textPrimary)),
          if (todayBreakdown.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 2,
              children: todayBreakdown
                  .map((line) => Text.rich(TextSpan(children: [
                        TextSpan(text: '${line.label} ', style: DriverText.caption),
                        TextSpan(text: '₱${line.amount.toStringAsFixed(0)}', style: DriverText.caption.copyWith(color: DriverColors.textPrimary, fontWeight: FontWeight.w700)),
                      ])))
                  .toList(),
            ),
          ],
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: DriverColors.border)),
          Row(
            children: [
              _miniStat(Icons.inventory_2_rounded, '${widget.completedToday}', 'Deliveries'),
              _miniStat(Icons.schedule_rounded, _elapsedLabel, widget.isOnline ? 'Online' : 'Offline'),
              _miniStat(Icons.star_rounded, '${widget.account.rating}', 'Rating', color: const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label, {Color color = DriverColors.primary}) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: DriverColors.textPrimary)),
                Text(label, style: DriverText.caption.copyWith(fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeDeliveryCard(BuildContext context, ActiveDelivery delivery) {
    final stageLabel = switch (delivery.stage) {
      DeliveryStage.headingToPickup => 'En route to pickup',
      DeliveryStage.atPickup => 'At pickup location',
      DeliveryStage.headingToDropoff => 'En route to delivery',
      DeliveryStage.atDropoff => 'At delivery location',
      DeliveryStage.completed => 'Completed',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: DriverColors.primaryGradient),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: DriverColors.primary.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: Text(stageLabel, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Text('₱${delivery.request.estimatedFare.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          Text(delivery.request.customerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.place_rounded, size: 13, color: Colors.white70),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  delivery.stage == DeliveryStage.headingToPickup || delivery.stage == DeliveryStage.atPickup ? delivery.request.pickupAddress : delivery.request.dropoffAddress,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onContinueActiveDelivery,
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text('Continue delivery'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: DriverColors.primaryDark, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestsSection() {
    if (!widget.isOnline) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(18)),
        child: Column(
          children: [
            const Icon(Icons.power_settings_new_rounded, color: DriverColors.primary, size: 28),
            const SizedBox(height: 10),
            const Text("You're offline", style: TextStyle(fontWeight: FontWeight.w800, color: DriverColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Go online to start receiving delivery requests.', textAlign: TextAlign.center, style: DriverText.caption),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: widget.onGoOnline,
              style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              child: const Text('Go online'),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return const Column(children: [DriverCardSkeleton(), DriverCardSkeleton()]);
    }

    if (widget.availableRequests.isEmpty) {
      return const DriverEmptyState(icon: Icons.hourglass_empty_rounded, title: 'No requests nearby', subtitle: 'Pull to refresh — new requests will show up here the moment they come in.');
    }

    return Column(
      children: widget.availableRequests.map((r) => _RequestCard(request: r, onTap: () => widget.onOpenRequest(r))).toList(),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final DeliveryRequest request;
  final VoidCallback onTap;
  const _RequestCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DriverColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(request.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: DriverColors.textPrimary))),
                Text('₱${request.estimatedFare.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: DriverColors.primaryDark)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.storefront_rounded, size: 13, color: DriverColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(request.pickupLabel, style: DriverText.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.flag_rounded, size: 13, color: DriverColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(request.dropoffLabel, style: DriverText.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                DriverStatusBadge(label: '${request.distanceKm.toStringAsFixed(1)} km', color: DriverColors.info, icon: Icons.route_rounded),
                const SizedBox(width: 6),
                DriverStatusBadge(label: '${request.etaMinutes} min', color: DriverColors.warning, icon: Icons.timer_rounded),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: DriverColors.textSecondary, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
