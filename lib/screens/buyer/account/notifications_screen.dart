import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/poller.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../chat/chat_list_screen.dart' show chatTimeLabel;
import '../orders/order_detail_screen.dart';
import '../widgets/buyer_widgets.dart';
import 'my_reports_screen.dart';
import 'profile_screen.dart';
import 'settings_screens.dart' show BuyerHelpScreen;

/// The buyer's notification inbox (opened from the bell in the home header).
/// Newest first, paged; read state lives on the server and the bell badge
/// follows [BuyerStore.notifUnread].
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final store = BuyerStore.instance;
  final _scroll = ScrollController();

  List<BuyerNotification>? items;
  String? error;
  bool hasMore = false;
  bool loadingMore = false;
  int _page = 1;

  /// Keeps new items arriving while the screen is open, without disturbing
  /// the pages already loaded (new ones are only prepended).
  late final Poller _poller = Poller(
    (isActive) async {
      final result = await store.api.notifications();
      if (!isActive() || !mounted || items == null) return;
      final known = {for (final n in items!) n.id};
      final fresh = result.items.where((n) => !known.contains(n.id)).toList();
      store.setNotifUnread(result.unread);
      if (fresh.isNotEmpty) setState(() => items = [...fresh, ...items!]);
    },
    interval: const Duration(seconds: 30),
    onError: store.handleError,
  );

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
    _poller.start();
  }

  @override
  void dispose() {
    _poller.stop();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) _loadMore();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final result = await store.api.notifications();
      if (!mounted) return;
      _page = 1;
      store.setNotifUnread(result.unread);
      setState(() {
        items = result.items;
        hasMore = result.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => error = store.handleError(e));
    }
  }

  Future<void> _loadMore() async {
    if (loadingMore || !hasMore || items == null) return;
    setState(() => loadingMore = true);
    try {
      final result = await store.api.notifications(page: _page + 1);
      if (!mounted) return;
      final known = {for (final n in items!) n.id};
      _page++;
      setState(() {
        items = [...items!, ...result.items.where((n) => !known.contains(n.id))];
        hasMore = result.hasMore;
      });
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<void> _markAllRead() async {
    final before = items;
    if (before == null) return;
    setState(() => items = [for (final n in before) n.copyWith(read: true)]);
    store.setNotifUnread(0);
    try {
      await store.api.markAllNotificationsRead();
    } catch (e) {
      if (!mounted) return;
      setState(() => items = before);
      store.refreshNotifUnread();
      showToast(context, store.handleError(e), error: true);
    }
  }

  void _markRead(BuyerNotification n) {
    if (n.read) return;
    setState(() => items = [for (final x in items!) x.id == n.id ? x.copyWith(read: true) : x]);
    store.setNotifUnread(store.notifUnread - 1);
    store.api.markNotificationRead(n.id).catchError((_) {
      // Roll back so the badge doesn't lie; the next poll corrects it anyway.
      if (mounted) setState(() => items = [for (final x in items!) x.id == n.id ? x.copyWith(read: false) : x]);
      store.refreshNotifUnread();
    });
  }

  Future<void> _open(BuyerNotification n) async {
    _markRead(n);
    final nav = Navigator.of(context);
    switch (n.type) {
      case 'case':
        nav.push(MaterialPageRoute(builder: (_) => const BuyerReportsScreen()));
      case 'support':
        nav.push(MaterialPageRoute(builder: (_) => const BuyerHelpScreen()));
      case 'account':
        nav.push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
      default:
        await _openOrder(n);
    }
  }

  /// Fetches the order itself, so it opens even if the orders list hasn't
  /// loaded. If it no longer exists the buyer gets a message, not a dead end.
  Future<void> _openOrder(BuyerNotification n) async {
    final number = n.orderNumber;
    if (number == null) {
      showToast(context, 'This order is no longer available.');
      return;
    }
    try {
      final order = await store.api.order(number);
      if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)));
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    return Scaffold(
      backgroundColor: BColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          ListenableBuilder(
            listenable: store,
            builder: (_, __) => TextButton(
              onPressed: store.notifUnread > 0 && list != null ? _markAllRead : null,
              child: const Text('Mark all read'),
            ),
          ),
        ],
      ),
      body: list == null
          ? (error != null
              ? ErrorState(message: error!, onRetry: _load)
              : ListView(children: List.generate(6, (_) => const _NotificationSkeleton())))
          : RefreshIndicator(
              color: BColors.brand,
              onRefresh: _load,
              child: list.isEmpty
                  ? ListView(children: const [
                      SizedBox(
                        height: 420,
                        child: EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'You\'re all caught up',
                          message: 'Order, delivery, refund and support updates will appear here.',
                        ),
                      ),
                    ])
                  : ListView.separated(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: list.length + (hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, color: BColors.divider),
                      itemBuilder: (_, i) => i == list.length
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                            )
                          : _NotificationTile(notification: list[i], onTap: () => _open(list[i])),
                    ),
            ),
    );
  }
}

IconData _iconFor(String type) => switch (type) {
      'delivery' => Icons.local_shipping_outlined,
      'refund' => Icons.currency_exchange_rounded,
      'case' => Icons.shield_outlined,
      'support' => Icons.support_agent_rounded,
      'account' => Icons.person_outline_rounded,
      _ => Icons.inventory_2_outlined,
    };

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final BuyerNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return Semantics(
      label: '${n.title}${n.read ? '' : ', unread'}',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: n.read ? Colors.white : BColors.brandSurface,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: n.read ? BColors.divider : Colors.white, shape: BoxShape.circle),
              child: Icon(_iconFor(n.type), size: 20, color: BColors.brand),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.title, style: TextStyle(fontSize: 14.5, fontWeight: n.read ? FontWeight.w600 : FontWeight.w800, color: BColors.ink, height: 1.3)),
                if (n.body != null) ...[
                  const SizedBox(height: 2),
                  Text(n.body!, maxLines: 2, overflow: TextOverflow.ellipsis, style: BText.small.copyWith(height: 1.35)),
                ],
                const SizedBox(height: 4),
                Text(chatTimeLabel(n.createdAt), style: BText.tiny),
              ]),
            ),
            if (!n.read)
              const Padding(
                padding: EdgeInsets.only(left: 10, top: 6),
                child: SizedBox(width: 9, height: 9, child: DecoratedBox(decoration: BoxDecoration(color: BColors.cta, shape: BoxShape.circle))),
              ),
          ]),
        ),
      ),
    );
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          SkeletonBox(height: 40, width: 40, radius: 20),
          SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(height: 13, width: 180),
              SizedBox(height: 8),
              SkeletonBox(height: 11),
            ]),
          ),
        ]),
      );
}
