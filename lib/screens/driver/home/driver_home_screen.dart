import 'dart:async';

import 'package:flutter/material.dart';

import '../driver_models.dart';
import '../driver_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriverColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: DriverColors.primary,
          onRefresh: widget.onRefreshRequests,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(context)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _quickStatsGrid(),
                      const SizedBox(height: 20),
                      _earningsCard(context),
                      if (widget.activeDelivery != null) ...[
                        const SizedBox(height: 20),
                        _activeDeliveryCard(context, widget.activeDelivery!),
                      ],
                      const SizedBox(height: 22),
                      DriverSectionHeader(title: widget.isOnline ? 'Available requests' : 'Go online to see requests'),
                      const SizedBox(height: 12),
                      _requestsSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: DriverColors.primaryGradient),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
        boxShadow: [BoxShadow(color: DriverColors.primary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.2), border: Border.all(color: Colors.white.withOpacity(0.4))),
                child: Text(widget.account.avatarInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.account.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFCD34D)),
                        const SizedBox(width: 3),
                        Text('${widget.account.rating} rating', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              _statusToggle(),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _headerStat(Icons.local_shipping_rounded, '${widget.completedToday}', 'Deliveries')),
              Expanded(child: _headerStat(Icons.payments_rounded, '₱${widget.todayEarnings.toStringAsFixed(0)}', 'Today')),
              Expanded(child: _headerStat(Icons.timer_rounded, _elapsedLabel, widget.isOnline ? 'Online' : 'Offline')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: widget.isOnline ? Colors.white.withOpacity(0.22) : Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.isOnline ? const Color(0xFF6EE7B7) : Colors.white54)),
          const SizedBox(width: 5),
          Text(widget.isOnline ? 'Online' : 'Offline', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _headerStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 17),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10)),
      ],
    );
  }

  Widget _quickStatsGrid() {
    final stats = [
      ('${widget.completedToday}', 'Deliveries today', Icons.inventory_2_rounded, DriverColors.primary),
      ('${widget.account.rating}', 'Rating', Icons.star_rounded, const Color(0xFFF59E0B)),
      (_elapsedLabel, 'Hours online', Icons.schedule_rounded, const Color(0xFF8B5CF6)),
      ('94%', 'Acceptance rate', Icons.thumb_up_rounded, const Color(0xFFEC4899)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: stats.map((s) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))]),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: s.$4.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(s.$3, size: 22, color: s.$4),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: DriverColors.textPrimary)),
                    Text(s.$2, style: const TextStyle(fontSize: 11.5, color: DriverColors.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _earningsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: DriverColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text("Today's earnings", style: DriverText.sectionTitle),
              const Spacer(),
              Text('₱${widget.todayEarnings.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: DriverColors.primaryDark)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: todayBreakdown
                .map(
                  (line) => Expanded(
                    child: Column(
                      children: [
                        Text('₱${line.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: DriverColors.textPrimary)),
                        Text(line.label, style: DriverText.caption),
                      ],
                    ),
                  ),
                )
                .toList(),
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
