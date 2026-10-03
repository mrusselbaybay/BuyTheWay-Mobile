import 'dart:async';

import 'package:flutter/material.dart';

import '../buyer_models.dart';
import '../buyer_shell.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';
import 'chat_thread_screen.dart';

/// `9:41 AM` today, `Yesterday`, otherwise `Oct 3`.
String chatTimeLabel(DateTime? at) {
  if (at == null) return '';
  final d = at.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  if (day == today) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  }
  if (today.difference(day).inDays == 1) return 'Yesterday';
  final label = formatDate(d);
  return d.year == now.year ? label.substring(0, label.lastIndexOf(',')) : label;
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, this.embedded = false});

  /// true when shown as the shell's Chat tab — then it only polls while
  /// that tab is visible.
  final bool embedded;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final store = BuyerStore.instance;
  List<ChatConversation>? items;
  String? error;
  bool archived = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // Keeps previews/unread fresh while the inbox is on screen.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_visible) _load(silent: true);
    });
    if (widget.embedded) BuyerShell.tab.addListener(_onTab);
  }

  bool get _visible => !widget.embedded || BuyerShell.tab.value == 3;

  void _onTab() {
    if (BuyerShell.tab.value == 3) _load(silent: true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    BuyerShell.tab.removeListener(_onTab);
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => error = null);
    try {
      final (list, _) = await store.api.conversations(archived: archived);
      if (!mounted) return;
      setState(() => items = list);
      store.refreshChatUnread();
    } catch (e) {
      if (mounted && !silent) setState(() => error = store.handleError(e));
    }
  }

  Future<void> _open(ChatConversation c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatThreadScreen(initial: c)));
    _load(silent: true);
  }

  Future<void> _setArchived(ChatConversation c, bool archive) async {
    setState(() => items = items?.where((i) => i.id != c.id).toList());
    try {
      await store.api.setConversationStatus(c.id, archive ? 'archived' : 'open');
      if (mounted) showToast(context, archive ? 'Chat archived' : 'Chat moved to inbox');
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
      _load(silent: true);
    }
  }

  Future<void> _delete(ChatConversation c) async {
    final ok = await confirmDialog(context,
        title: 'Delete this chat?', message: 'The conversation with ${c.name} will be removed from your inbox.', confirmLabel: 'Delete', destructive: true);
    if (!ok) return;
    setState(() => items = items?.where((i) => i.id != c.id).toList());
    try {
      await store.api.deleteConversation(c.id);
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
      _load(silent: true);
    }
  }

  void _actions(ChatConversation c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BRadius.md))),
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(archived ? Icons.unarchive_outlined : Icons.archive_outlined),
            title: Text(archived ? 'Move to inbox' : 'Archive'),
            onTap: () {
              Navigator.pop(context);
              _setArchived(c, !archived);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: BColors.error),
            title: const Text('Delete chat', style: TextStyle(color: BColors.error)),
            onTap: () {
              Navigator.pop(context);
              _delete(c);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    return Scaffold(
      backgroundColor: BColors.surface,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        surfaceTintColor: BColors.surface,
        foregroundColor: BColors.ink,
        automaticallyImplyLeading: !widget.embedded,
        title: Text(archived ? 'Archived Chats' : 'Chats', style: BText.title),
        actions: [
          IconButton(
            tooltip: archived ? 'Inbox' : 'Archived chats',
            icon: Icon(archived ? Icons.inbox_outlined : Icons.archive_outlined),
            onPressed: () {
              setState(() {
                archived = !archived;
                items = null;
              });
              _load();
            },
          ),
        ],
      ),
      body: list == null
          ? (error != null
              ? ErrorState(message: error!, onRetry: _load)
              : ListView(children: List.generate(6, (_) => const _ConversationSkeleton())))
          : RefreshIndicator(
              color: BColors.brand,
              onRefresh: _load,
              child: list.isEmpty
                  ? ListView(children: [
                      SizedBox(
                        height: 420,
                        child: EmptyState(
                          icon: Icons.chat_bubble_outline,
                          title: archived ? 'No archived chats' : 'No messages yet',
                          message: archived ? null : 'Chat with a seller from any product or order page.',
                        ),
                      ),
                    ])
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 76, color: BColors.divider),
                      itemBuilder: (_, i) => _ConversationTile(conversation: list[i], onTap: () => _open(list[i]), onLongPress: () => _actions(list[i])),
                    ),
            ),
    );
  }
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.name, this.url, this.courier = false, this.online = false, this.radius = 24});

  final String name;
  final String? url;
  final bool courier;
  final bool online;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: url != null
              ? NetImage(url, fallbackIcon: courier ? Icons.delivery_dining : Icons.storefront)
              : Container(
                  color: courier ? BColors.ctaSurface : BColors.brandSurface,
                  child: Icon(courier ? Icons.delivery_dining : Icons.storefront, color: courier ? BColors.cta : BColors.brand, size: radius),
                ),
        ),
      ),
      if (online)
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.5,
            height: radius * 0.5,
            decoration: BoxDecoration(color: BColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          ),
        ),
    ]);
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap, required this.onLongPress});

  final ChatConversation conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unread > 0;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          ChatAvatar(name: c.name, url: c.avatarUrl, courier: c.isCourier, online: c.online),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(c.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                ),
                if (c.isCourier) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: BColors.ctaSurface, borderRadius: BorderRadius.circular(2)),
                    child: const Text('Courier', style: TextStyle(fontSize: 10.5, color: BColors.cta, fontWeight: FontWeight.w700)),
                  ),
                ],
                const Spacer(),
                Text(chatTimeLabel(c.updatedAt), style: TextStyle(fontSize: 11.5, color: unread ? BColors.cta : BColors.faint)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Expanded(
                  child: Text(
                    c.preview ?? (c.productName != null ? 'About: ${c.productName}' : 'No messages yet'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: unread ? BColors.ink : BColors.muted, fontWeight: unread ? FontWeight.w600 : FontWeight.w400),
                  ),
                ),
                if (unread)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: BColors.cta, borderRadius: BorderRadius.circular(10)),
                    child: Text(c.unread > 99 ? '99+' : '${c.unread}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ConversationSkeleton extends StatelessWidget {
  const _ConversationSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          SkeletonBox(width: 48, height: 48, radius: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(height: 13, width: 140),
              SizedBox(height: 8),
              SkeletonBox(height: 12),
            ]),
          ),
        ]),
      );
}
