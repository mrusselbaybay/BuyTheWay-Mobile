import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../logistics_models.dart';

class LogisticsDashboardScreen extends StatelessWidget {
  const LogisticsDashboardScreen({
    super.key,
    required this.account,
    required this.pending,
    required this.scanned,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onOpenInventory,
    required this.unreadNotifications,
    required this.onOpenNotifications,
  });

  final LogisticsAccount account;
  final List<InventoryParcel> pending;
  final List<InventoryParcel> scanned;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenInventory;
  final int unreadNotifications;
  final VoidCallback onOpenNotifications;

  static const _teal = Color(0xFF0D9488);
  static const _paper = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final pickup =
        pending.where((p) => p.origin == InventoryOrigin.pickup).length;
    final outbound = pending
        .where((p) => p.origin == InventoryOrigin.transferDeparture)
        .length;
    final inbound = pending
        .where((p) => p.origin == InventoryOrigin.transferReceipt)
        .length;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scannedToday = scanned.where((p) {
      final value = p.inventoryScannedAt?.toLocal();
      return value != null && !value.isBefore(today);
    }).length;
    final orderedPending = [...pending]..sort((a, b) {
        final aTime = a.forInventoryAt;
        final bTime = b.forInventoryAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });
    final oldest = orderedPending.isEmpty ? null : orderedPending.first;
    final delayed = pending.where((p) {
      final received = p.forInventoryAt;
      return received != null &&
          now.difference(received.toLocal()).inMinutes >= 30;
    }).length;
    final recentScans = [...scanned]..sort((a, b) {
        final aTime = a.inventoryScannedAt;
        final bTime = b.inventoryScannedAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

    return ColoredBox(
      color: _paper,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: onRefresh,
          color: _teal,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              final horizontal = wide ? 28.0 : 18.0;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 26),
                children: [
                  _DashboardHeader(
                    companyName: account.companyName,
                    unreadNotifications: unreadNotifications,
                    onOpenNotifications: onOpenNotifications,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: error!),
                  ],
                  const SizedBox(height: 18),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _ScannerHero(
                              count: pending.length,
                              loading: loading,
                              oldest: oldest?.forInventoryAt,
                              onTap: onOpenInventory),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 1,
                          child: _StatusMonitor(
                            pendingCount: pending.length,
                            scannedToday: scannedToday,
                            delayedCount: delayed,
                            loading: loading,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _ScannerHero(
                        count: pending.length,
                        loading: loading,
                        oldest: oldest?.forInventoryAt,
                        onTap: onOpenInventory),
                    const SizedBox(height: 12),
                    _StatusMonitor(
                      pendingCount: pending.length,
                      scannedToday: scannedToday,
                      delayedCount: delayed,
                      loading: loading,
                    ),
                  ],
                  if (!loading && delayed > 0 && oldest != null) ...[
                    const SizedBox(height: 18),
                    _AttentionCard(parcel: oldest, onTap: onOpenInventory),
                  ],
                  const SizedBox(height: 22),
                  _SectionHeading(
                      title: 'Parcel flow', caption: 'AWAITING VERIFICATION'),
                  const SizedBox(height: 10),
                  if (wide)
                    Row(children: [
                      Expanded(
                          child: _RouteCard(
                              icon: Icons.storefront_outlined,
                              title: 'Seller collection',
                              subtitle: 'Pickup',
                              count: loading ? null : pickup,
                              accent: _teal,
                              onTap: onOpenInventory)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _RouteCard(
                              icon: Icons.local_shipping_outlined,
                              title: 'Hub transfer in',
                              subtitle: 'Inbound',
                              count: loading ? null : inbound,
                              accent: const Color(0xFF2563EB),
                              onTap: onOpenInventory)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _RouteCard(
                              icon: Icons.outbox_outlined,
                              title: 'Hub transfer out',
                              subtitle: 'Outbound',
                              count: loading ? null : outbound,
                              accent: const Color(0xFF7C3AED),
                              onTap: onOpenInventory)),
                    ])
                  else
                    _RouteBreakdown(
                        pickup: loading ? null : pickup,
                        inbound: loading ? null : inbound,
                        outbound: loading ? null : outbound,
                        onTap: onOpenInventory),
                  if (recentScans.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _SectionHeading(
                        title: 'Recent activity', caption: 'LATEST SCANS'),
                    const SizedBox(height: 9),
                    _RecentActivity(
                        parcels: recentScans.take(3).toList(),
                        onTap: onOpenInventory),
                  ],
                  const SizedBox(height: 16),
                  const _SecurityNote(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader(
      {required this.companyName,
      required this.unreadNotifications,
      required this.onOpenNotifications});
  final String companyName;
  final int unreadNotifications;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
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
            ]),
            const SizedBox(height: 5),
            Text(companyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.2)),
          ]),
        ),
        const SizedBox(width: 8),
        Badge(
          isLabelVisible: unreadNotifications > 0,
          label:
              Text(unreadNotifications > 99 ? '99+' : '$unreadNotifications'),
          backgroundColor: const Color(0xFFF97316),
          child: IconButton(
            onPressed: onOpenNotifications,
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded, size: 21),
            style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF475569),
                minimumSize: const Size(42, 42),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
      ]);
}

class _ScannerHero extends StatelessWidget {
  const _ScannerHero(
      {required this.count,
      required this.loading,
      required this.oldest,
      required this.onTap});
  final int count;
  final bool loading;
  final DateTime? oldest;
  final VoidCallback onTap;

  static const _teal = Color(0xFF0D9488);

  String get _oldestLabel {
    if (oldest == null) return 'Ready for the next courier handover.';
    final elapsed = DateTime.now().difference(oldest!.toLocal());
    if (elapsed.inMinutes < 60)
      return 'Oldest parcel waiting ${elapsed.inMinutes.clamp(0, 59)} minutes.';
    if (elapsed.inHours < 24)
      return 'Oldest parcel waiting ${elapsed.inHours} hours.';
    return 'Oldest parcel waiting ${elapsed.inDays} days.';
  }

  @override
  Widget build(BuildContext context) => Material(
        color: _teal,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(children: [
            const Positioned(right: -54, top: -60, child: _HeroGlow()),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.18),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('RECEIVING TERMINAL',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.05))),
                      const Spacer(),
                      Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: Color(0xFF6EE7B7),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(count == 0 && !loading ? 'CLEAR' : 'OPEN',
                          style: const TextStyle(
                              color: Color(0xFFD1FAE5),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .8)),
                    ]),
                    const SizedBox(height: 20),
                    LayoutBuilder(builder: (context, constraints) {
                      final compact = constraints.maxWidth < 390;
                      return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        count == 0 && !loading
                                            ? 'Queue clear'
                                            : '$count parcel${count == 1 ? '' : 's'} awaiting verification',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: compact ? 21 : 25,
                                            height: 1.1,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -.55)),
                                    const SizedBox(height: 8),
                                    Text(
                                        count == 0 && !loading
                                            ? 'Every received parcel has been verified.'
                                            : _oldestLabel,
                                        style: const TextStyle(
                                            color: Color(0xFFD5F5EF),
                                            fontSize: 11,
                                            height: 1.45)),
                                  ]),
                            ),
                            const SizedBox(width: 8),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(loading ? '—' : '$count',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 52,
                                          height: .95,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -3,
                                          fontFeatures: [
                                            FontFeature.tabularFigures()
                                          ])),
                                  const Text('PARCELS IN QUEUE',
                                      style: TextStyle(
                                          color: Color(0xFFD1FAE5),
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: .8)),
                                ]),
                          ]);
                    }),
                    const SizedBox(height: 17),
                    Container(height: 1, color: Colors.white.withOpacity(.2)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(
                          count == 0
                              ? Icons.inventory_2_outlined
                              : Icons.qr_code_scanner_rounded,
                          size: 18,
                          color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              count == 0
                                  ? 'View parcel records'
                                  : 'Open parcel queue',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800))),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 18, color: Colors.white),
                    ]),
                  ]),
            ),
          ]),
        ),
      );
}

class _HeroGlow extends StatelessWidget {
  const _HeroGlow();

  @override
  Widget build(BuildContext context) => Container(
        width: 210,
        height: 210,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Colors.white.withOpacity(.19),
              Colors.white.withOpacity(0)
            ])),
      );
}

class _StatusMonitor extends StatelessWidget {
  const _StatusMonitor(
      {required this.pendingCount,
      required this.scannedToday,
      required this.delayedCount,
      required this.loading});
  final int pendingCount;
  final int scannedToday;
  final int delayedCount;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 10,
                  offset: Offset(0, 3))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Expanded(
                child: Text('TODAY AT A GLANCE',
                    style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2))),
            Icon(Icons.monitor_heart_outlined,
                color: Color(0xFF14B8A6), size: 18),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _MiniStat(
                    label: 'Scanned',
                    value: loading ? '—' : '$scannedToday',
                    color: const Color(0xFF047857),
                    surface: const Color(0xFFECFDF5))),
            const SizedBox(width: 7),
            Expanded(
                child: _MiniStat(
                    label: 'Waiting',
                    value: loading ? '—' : '$pendingCount',
                    color: const Color(0xFF0F766E),
                    surface: const Color(0xFFE6FFFA))),
            const SizedBox(width: 7),
            Expanded(
                child: _MiniStat(
                    label: 'Delayed',
                    value: loading ? '—' : '$delayedCount',
                    color: const Color(0xFFC2410C),
                    surface: const Color(0xFFFFF7ED))),
          ]),
        ]),
      );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label,
      required this.value,
      required this.color,
      required this.surface});
  final String label;
  final String value;
  final Color color;
  final Color surface;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
            color: surface, borderRadius: BorderRadius.circular(11)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 19,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(height: 5),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.caption});
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.25))),
        Text(caption,
            style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
      ]);
}

class _RouteBreakdown extends StatelessWidget {
  const _RouteBreakdown(
      {required this.pickup,
      required this.inbound,
      required this.outbound,
      required this.onTap});
  final int? pickup;
  final int? inbound;
  final int? outbound;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(children: [
          _RouteRow(
              icon: Icons.storefront_outlined,
              title: 'Seller collection',
              subtitle: 'Pickup',
              count: pickup,
              accent: const Color(0xFF0D9488),
              onTap: onTap),
          const Divider(
              height: 1, indent: 14, endIndent: 14, color: Color(0xFFF1F5F9)),
          _RouteRow(
              icon: Icons.local_shipping_outlined,
              title: 'Hub transfer in',
              subtitle: 'Inbound',
              count: inbound,
              accent: const Color(0xFF2563EB),
              onTap: onTap),
          const Divider(
              height: 1, indent: 14, endIndent: 14, color: Color(0xFFF1F5F9)),
          _RouteRow(
              icon: Icons.outbox_outlined,
              title: 'Hub transfer out',
              subtitle: 'Outbound',
              count: outbound,
              accent: const Color(0xFF7C3AED),
              onTap: onTap),
        ]),
      );
}

class _RouteRow extends StatelessWidget {
  const _RouteRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.count,
      required this.accent,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final int? count;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            _RouteIcon(icon: icon, accent: accent),
            const SizedBox(width: 11),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle.toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8)),
                ])),
            Text(count?.toString() ?? '—',
                style: TextStyle(
                    color: count == 0
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF0F172A),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(width: 3),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFF94A3B8)),
          ]),
        ),
      );
}

class _RouteCard extends StatelessWidget {
  const _RouteCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.count,
      required this.accent,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final int? count;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(children: [
              _RouteIcon(icon: icon, accent: accent),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle.toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .7)),
                  ])),
              Text(count?.toString() ?? '—',
                  style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ]),
          ),
        ),
      );
}

class _RouteIcon extends StatelessWidget {
  const _RouteIcon({required this.icon, required this.accent});
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: accent.withOpacity(.09),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: accent, size: 19),
      );
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.parcel, required this.onTap});
  final InventoryParcel parcel;
  final VoidCallback onTap;

  String get _waiting {
    final received = parcel.forInventoryAt;
    if (received == null) return 'Waiting for verification';
    final elapsed = DateTime.now().difference(received.toLocal());
    if (elapsed.inMinutes < 60)
      return 'Waiting ${elapsed.inMinutes.clamp(0, 59)} minutes';
    if (elapsed.inHours < 24) return 'Waiting ${elapsed.inHours} hours';
    return 'Waiting ${elapsed.inDays} days';
  }

  String get _route => switch (parcel.origin) {
        InventoryOrigin.pickup =>
          parcel.isReturn ? 'Buyer return' : 'Seller collection',
        InventoryOrigin.transferReceipt => 'Incoming transfer',
        InventoryOrigin.transferDeparture => 'Outgoing transfer',
        InventoryOrigin.unknown => 'Parcel handover',
      };

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFED7AA))),
            child: Row(children: [
              Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.schedule_rounded,
                      color: Color(0xFFC2410C), size: 20)),
              const SizedBox(width: 11),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('NEEDS ATTENTION',
                        style: TextStyle(
                            color: Color(0xFFC2410C),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8)),
                    const SizedBox(height: 3),
                    Text(
                        parcel.trackingNumber ?? parcel.orderNumber ?? 'Parcel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF431407),
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('$_route · $_waiting',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF9A3412),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600)),
                  ])),
              const SizedBox(width: 8),
              const Text('Review',
                  style: TextStyle(
                      color: Color(0xFFC2410C),
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFC2410C), size: 18),
            ]),
          ),
        ),
      );
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.parcels, required this.onTap});
  final List<InventoryParcel> parcels;
  final VoidCallback onTap;

  String _time(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(children: [
          for (var i = 0; i < parcels.length; i++) ...[
            InkWell(
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                child: Row(children: [
                  SizedBox(
                      width: 46,
                      child: Text(_time(parcels[i].inventoryScannedAt),
                          style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700))),
                  Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: Color(0xFF10B981), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            parcels[i].trackingNumber ??
                                parcels[i].orderNumber ??
                                'Parcel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                            'Scanned by ${parcels[i].inventoryScannedBy?.fullName ?? 'hub team'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500)),
                      ])),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8), size: 18),
                ]),
              ),
            ),
            if (i != parcels.length - 1)
              const Divider(
                  height: 1,
                  indent: 13,
                  endIndent: 13,
                  color: Color(0xFFF1F5F9)),
          ],
        ]),
      );
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: const Color(0xFFE8F5F1),
            borderRadius: BorderRadius.circular(12)),
        child:
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.verified_user_outlined,
              color: Color(0xFF0F766E), size: 17),
          SizedBox(width: 9),
          Expanded(
              child: Text(
                  'Scan the matching parcel QR before dispatch to protect the handover record.',
                  style: TextStyle(
                      color: Color(0xFF315E57),
                      fontSize: 10,
                      height: 1.4,
                      fontWeight: FontWeight.w600))),
        ]),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFB91C1C), size: 19),
          const SizedBox(width: 9),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600))),
        ]),
      );
}
