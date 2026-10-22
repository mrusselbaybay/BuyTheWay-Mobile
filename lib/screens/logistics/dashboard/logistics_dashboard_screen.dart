import 'package:flutter/material.dart';

import '../../driver/driver_theme.dart';
import '../../driver/widgets/driver_shared_widgets.dart';
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

  static const _ink = Color(0xFF172923);
  static const _forest = Color(0xFF184D3B);
  static const _mint = Color(0xFFE7F0E9);
  static const _paper = Color(0xFFF5F6F1);
  static const _muted = Color(0xFF687970);

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

    return ColoredBox(
      color: _paper,
      child: SafeArea(
        bottom: false,
        child: DriverRefreshable(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LOGISTICS / CHECKPOINT',
                            style: TextStyle(
                                color: _forest,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 7),
                        Text(account.companyName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _ink,
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                height: 1.08,
                                letterSpacing: -0.8)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    button: true,
                    label: unreadNotifications > 0
                        ? 'Notifications, $unreadNotifications unread'
                        : 'Notifications',
                    child: Badge(
                      isLabelVisible: unreadNotifications > 0,
                      label: Text(unreadNotifications > 99
                          ? '99+'
                          : '$unreadNotifications'),
                      backgroundColor: const Color(0xFFB95137),
                      child: IconButton.filledTonal(
                        onPressed: onOpenNotifications,
                        tooltip: 'Notifications',
                        icon: const Icon(Icons.notifications_none_rounded),
                        style: IconButton.styleFrom(
                            backgroundColor: _mint,
                            foregroundColor: _forest,
                            minimumSize: const Size(48, 48)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text('Your checkpoint',
                  style: TextStyle(
                      color: _muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: DriverColors.errorSurface,
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: DriverColors.error),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(error!,
                            style: const TextStyle(
                                color: DriverColors.error,
                                fontWeight: FontWeight.w600))),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
              if (loading)
                const DriverCardSkeleton()
              else
                Material(
                  color: _forest,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: onOpenInventory,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(23),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.qr_code_scanner_rounded,
                                color: Color(0xFFBCE5C2), size: 24),
                            const SizedBox(width: 10),
                            const Expanded(
                                child: Text('READY TO RECEIVE',
                                    style: TextStyle(
                                        color: Color(0xFFBCE5C2),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5))),
                            Icon(Icons.arrow_outward_rounded,
                                color: Colors.white.withOpacity(.8), size: 20),
                          ]),
                          const SizedBox(height: 28),
                          Text('${pending.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 72,
                                  height: .9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -4)),
                          const SizedBox(height: 10),
                          Text(
                              pending.length == 1
                                  ? 'parcel awaiting a scan'
                                  : 'parcels awaiting a scan',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 23),
                          Container(
                              height: 1, color: Colors.white.withOpacity(.2)),
                          const SizedBox(height: 16),
                          const Row(children: [
                            Text('Open scan queue',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            Spacer(),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 19),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 15),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(19),
                child: InkWell(
                  onTap: onOpenInventory,
                  borderRadius: BorderRadius.circular(19),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    child: Row(children: [
                      const Icon(Icons.inventory_2_outlined,
                          color: _forest, size: 25),
                      const SizedBox(width: 14),
                      const Expanded(
                          child: Text('In inventory',
                              style: TextStyle(
                                  color: _ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700))),
                      Text(loading ? '—' : '${scanned.length}',
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 26,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, color: _muted),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 31),
              const Text('Where they came from',
                  style: TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.4)),
              const SizedBox(height: 5),
              const Text('Parcels waiting at your checkpoint',
                  style: TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 15),
              _SourceRow(
                  icon: Icons.storefront_outlined,
                  label: 'Seller pickups',
                  count: loading ? null : pickup),
              _SourceRow(
                  icon: Icons.north_east_rounded,
                  label: 'Outgoing transfers',
                  count: loading ? null : outbound),
              _SourceRow(
                  icon: Icons.south_west_rounded,
                  label: 'Incoming transfers',
                  count: loading ? null : inbound),
              const SizedBox(height: 20),
              const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: _muted, size: 17),
                    SizedBox(width: 9),
                    Expanded(
                        child: Text(
                            'Scan each parcel before it can move to delivery or transfer.',
                            style: TextStyle(
                                color: _muted, fontSize: 12, height: 1.4))),
                  ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow(
      {required this.icon, required this.label, required this.count});

  final IconData icon;
  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 15),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE0E6DD)))),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: const Color(0xFFE7F0E9),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: const Color(0xFF184D3B), size: 19)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Color(0xFF172923),
                      fontSize: 14,
                      fontWeight: FontWeight.w600))),
          Text(count == null ? '—' : '$count',
              style: const TextStyle(
                  color: Color(0xFF172923),
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
        ]),
      );
}
