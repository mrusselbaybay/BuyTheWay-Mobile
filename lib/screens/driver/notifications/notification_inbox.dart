import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../services/poller.dart';
import '../../logistics/logistics_models.dart' show LogisticsNotification, LogisticsNotificationPage;
import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';

/// The paged, polled notification list shared by the logistics staff bell and
/// the courier bell. Callers supply the endpoints and what a tap does; read
/// state lives on the server.
///
/// The screen sits ABOVE its shell, so the shell's own poll is already paused
/// while it is open — it runs its own list poll instead and reports the unread
/// count back through [onUnreadChanged]. While [isBusy] is true (a scan, photo
/// capture or upload is running somewhere in the app) the poll is skipped and
/// taps are ignored, so nothing moves under the user's hands.
class NotificationInbox extends StatefulWidget {
  /// Page 1 is the newest; the body is the API's `{data, meta}` envelope.
  final Future<Map<String, dynamic>> Function(int page) fetchPage;
  final Future<void> Function(String id) markRead;
  final Future<void> Function() markAllRead;

  /// Shell state: the unread count changed (read marks, polls).
  final ValueChanged<int> onUnreadChanged;

  /// True while a scan/capture is open or in flight anywhere in the app.
  final bool Function() isBusy;

  /// Shell's poll error path (401/403 → session-expired state). Never toasts.
  final void Function(Object error)? onPollError;

  /// A row was tapped (already marked read locally). [context] belongs to the inbox.
  final Future<void> Function(BuildContext context, LogisticsNotification notification) onOpen;

  final String emptySubtitle;

  const NotificationInbox({
    super.key,
    required this.fetchPage,
    required this.markRead,
    required this.markAllRead,
    required this.onUnreadChanged,
    required this.isBusy,
    required this.onOpen,
    required this.emptySubtitle,
    this.onPollError,
  });

  @override
  State<NotificationInbox> createState() => _NotificationInboxState();
}

class _NotificationInboxState extends State<NotificationInbox> {
  final ScrollController _scroll = ScrollController();

  List<LogisticsNotification>? _items;
  String? _error;
  bool _hasMore = false;
  bool _loadingMore = false;
  int _page = 1;
  int _unread = 0;
  ModalRoute<dynamic>? _route;

  /// Keeps new items arriving while the screen is open without disturbing the
  /// pages already loaded: new rows are only prepended, and a row read on the
  /// other app flips to read — a local read mark is never reverted.
  late final Poller _poller = Poller(
    (isActive) async {
      final page = LogisticsNotificationPage.fromApi(await widget.fetchPage(1));
      final current = _items;
      if (!isActive() || !mounted || current == null || widget.isBusy()) return;
      final fresh = {for (final n in page.items) n.id: n};
      final known = {for (final n in current) n.id};
      final next = [
        ...page.items.where((n) => !known.contains(n.id)),
        for (final n in current) (fresh[n.id]?.read ?? false) && !n.read ? n.copyWith(read: true) : n,
      ];
      _setUnread(page.unread);
      setState(() => _items = next);
    },
    interval: const Duration(seconds: 30),
    // Not while a parcel detail/scanner route covers this screen.
    shouldSkip: () => widget.isBusy() || _route?.isCurrent == false,
    onError: widget.onPollError,
  );

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
    _poller.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _poller.stop();
    _scroll.dispose();
    super.dispose();
  }

  void _setUnread(int count) {
    _unread = count < 0 ? 0 : count;
    widget.onUnreadChanged(_unread);
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) _loadMore();
  }

  Future<void> _load() async {
    final firstLoad = _items == null;
    if (firstLoad) setState(() => _error = null);
    try {
      final page = LogisticsNotificationPage.fromApi(await widget.fetchPage(1));
      if (!mounted) return;
      _page = 1;
      _setUnread(page.unread);
      setState(() {
        _items = page.items;
        _hasMore = page.hasMore;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Keep the last good list on a failed refresh; only the first load shows an error.
      if (_items == null) setState(() => _error = _message(e));
    }
  }

  Future<void> _loadMore() async {
    final current = _items;
    if (_loadingMore || !_hasMore || current == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = LogisticsNotificationPage.fromApi(await widget.fetchPage(_page + 1));
      if (!mounted) return;
      final known = {for (final n in current) n.id};
      _page++;
      setState(() {
        _items = [...current, ...page.items.where((n) => !known.contains(n.id))];
        _hasMore = page.hasMore;
      });
    } catch (_) {
      // Silent: the "load older" row stays and a scroll retries.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _message(Object e) => e is ApiException ? e.message : 'Could not reach the server. Check your connection and try again.';

  Future<void> _markAllRead() async {
    final before = _items;
    if (before == null) return;
    final unreadBefore = _unread;
    setState(() => _items = [for (final n in before) n.copyWith(read: true)]);
    _setUnread(0);
    try {
      await widget.markAllRead();
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = before);
      _setUnread(unreadBefore);
      unawaited(_poller.refreshNow());
    }
  }

  void _markRead(LogisticsNotification n) {
    if (n.read) return;
    setState(() => _items = [for (final x in _items!) x.id == n.id ? x.copyWith(read: true) : x]);
    _setUnread(_unread - 1);
    widget.markRead(n.id).catchError((_) {
      // Roll back so the badge doesn't lie; the next poll corrects it anyway.
      if (mounted) {
        setState(() => _items = [for (final x in _items!) x.id == n.id ? x.copyWith(read: false) : x]);
        _setUnread(_unread + 1);
      }
    });
  }

  Future<void> _open(LogisticsNotification n) async {
    // Never stack a detail screen on an active scan.
    if (widget.isBusy()) return;
    _markRead(n);
    await widget.onOpen(context, n);
  }

  @override
  Widget build(BuildContext context) {
    final list = _items;
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: DriverColors.textPrimary,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: _unread > 0 && list != null ? _markAllRead : null,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: list == null
          ? (_error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : ListView(children: List.generate(6, (_) => const _NotificationSkeleton())))
          : RefreshIndicator(
              color: DriverColors.primary,
              onRefresh: _load,
              child: list.isEmpty
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
                        child: DriverEmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'You\'re all caught up',
                          subtitle: widget.emptySubtitle,
                        ),
                      ),
                    ])
                  : ListView.separated(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: list.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, color: DriverColors.border),
                      itemBuilder: (_, i) => i == list.length
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: Center(
                                child: TextButton(
                                  onPressed: _loadingMore ? null : _loadMore,
                                  child: _loadingMore
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: DriverColors.primary))
                                      : const Text('Load older notifications'),
                                ),
                              ),
                            )
                          : _NotificationTile(notification: list[i], onTap: () => _open(list[i])),
                    ),
            ),
    );
  }
}

IconData _iconFor(String type) => switch (type) {
      'transfer' => Icons.compare_arrows_rounded,
      'rider' => Icons.two_wheeler_rounded,
      'money' => Icons.payments_outlined,
      'team' => Icons.group_outlined,
      'employment' => Icons.badge_outlined,
      'account' => Icons.support_agent_rounded,
      _ => Icons.inventory_2_outlined,
    };

/// "Just now", "5m ago" ... then the viewer's own locale for older dates.
String _timeLabel(BuildContext context, DateTime? at) {
  if (at == null) return '';
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return MaterialLocalizations.of(context).formatShortDate(at.toLocal());
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final LogisticsNotification notification;
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
          color: n.read ? Colors.white : DriverColors.primarySurface,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: n.read ? DriverColors.background : Colors.white, shape: BoxShape.circle),
              child: Icon(_iconFor(n.type), size: 20, color: DriverColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  n.title,
                  style: TextStyle(fontSize: 14.5, fontWeight: n.read ? FontWeight.w600 : FontWeight.w800, color: DriverColors.textPrimary, height: 1.3),
                ),
                if (n.body != null) ...[
                  const SizedBox(height: 2),
                  Text(n.body!, maxLines: 2, overflow: TextOverflow.ellipsis, style: DriverText.caption.copyWith(height: 1.35)),
                ],
                const SizedBox(height: 4),
                Text(_timeLabel(context, n.createdAt), style: DriverText.caption),
              ]),
            ),
            if (!n.read)
              const Padding(
                padding: EdgeInsets.only(left: 10, top: 6),
                child: SizedBox(width: 9, height: 9, child: DecoratedBox(decoration: BoxDecoration(color: DriverColors.primary, shape: BoxShape.circle))),
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
          DriverShimmerBox(height: 40, width: 40, radius: 20),
          SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DriverShimmerBox(height: 13, width: 180),
              SizedBox(height: 8),
              DriverShimmerBox(height: 11),
            ]),
          ),
        ]),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: DriverColors.textSecondary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: DriverText.body),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white, minimumSize: const Size(120, 44)),
              child: const Text('Try again'),
            ),
          ]),
        ),
      );
}
