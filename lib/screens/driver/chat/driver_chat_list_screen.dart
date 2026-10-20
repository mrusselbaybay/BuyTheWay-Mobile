import 'package:flutter/material.dart';

import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';
import 'chat_models.dart';
import 'driver_archived_conversations_screen.dart';
import 'driver_chat_controller.dart';
import 'driver_chat_conversation_screen.dart';

/// Messages tab — inbox-first: this screen only ever loads lightweight
/// conversation summaries (participant, preview, timestamp, unread count).
/// A conversation's actual message history is fetched only once the rider
/// taps it (see DriverChatConversationScreen), never up front.
///
/// [isActive] tells this screen whether it's the currently-selected bottom
/// tab — kept alive in DriverShell's IndexedStack even when not selected,
/// so this flag (not initState/dispose) is what gates the inbox meta poll.
class DriverChatListScreen extends StatefulWidget {
  final DriverChatController controller;
  final bool isActive;

  const DriverChatListScreen(
      {super.key, required this.controller, required this.isActive});

  @override
  State<DriverChatListScreen> createState() => _DriverChatListScreenState();
}

class _DriverChatListScreenState extends State<DriverChatListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.setInboxActive(widget.isActive);
    // `loadingConversations` defaults to true (so the skeleton shows
    // immediately, before this first load even starts) — gating this call
    // on "not already loading" therefore always evaluated to false and the
    // very first fetch never fired. initState() only runs once for this
    // screen's lifetime (it's kept alive by DriverShell's IndexedStack), so
    // "nothing loaded yet" is exactly the right and only guard needed here.
    if (widget.controller.conversations.isEmpty) {
      // loadConversations() calls notifyListeners() synchronously before
      // its first await (to flip the skeleton on immediately) — calling it
      // straight from initState() fires that during this very widget's
      // first build, which trips "setState() called during build" on
      // DriverShell above it. Deferring to the post-frame callback runs it
      // once this frame is safely finished.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.loadConversations();
      });
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant DriverChatListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      widget.controller.setInboxActive(widget.isActive);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      widget.controller.loadMoreConversations();
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openConversation(ChatConversation conversation) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DriverChatConversationScreen(
          controller: widget.controller, conversation: conversation),
    ));
  }

  void _openArchived() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          DriverArchivedConversationsScreen(controller: widget.controller),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: DriverColors.textPrimary,
        title: const Text('Messages',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: DriverRefreshable(
        onRefresh: () => controller.loadConversations(showLoading: false),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: _toolbar(controller),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
              sliver: _content(controller),
            ),
          ],
        ),
      ),
    );
  }

  /// Search field + archive shortcut, visually one balanced toolbar.
  Widget _toolbar(DriverChatController controller) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DriverColors.border)),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    size: 18, color: DriverColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: controller.setSearch,
                    style: DriverText.body,
                    decoration: const InputDecoration(
                      hintText: 'Search conversations',
                      hintStyle: DriverText.caption,
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      controller.setSearch('');
                    },
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: DriverColors.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _ArchiveShortcut(onTap: _openArchived),
      ],
    );
  }

  Widget _content(DriverChatController controller) {
    if (controller.loadingConversations) {
      return SliverList(
        delegate: SliverChildListDelegate([
          const SizedBox(height: 8),
          const DriverCardSkeleton(),
          const DriverCardSkeleton(),
          const DriverCardSkeleton(),
        ]),
      );
    }

    if (controller.conversationsError != null &&
        controller.conversations.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: DriverEmptyState(
            icon: Icons.wifi_off_rounded,
            title: "Couldn't load messages",
            subtitle: controller.conversationsError!,
          ),
        ),
      );
    }

    final priority = controller.priorityConversations;
    final normal = controller.normalConversations;

    if (priority.isEmpty && normal.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: DriverEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: controller.search.isNotEmpty
                ? 'No matches'
                : 'No conversations yet',
            subtitle: controller.search.isNotEmpty
                ? 'No conversations match your search.'
                : "Your employer's messages will show up here once you're hired.",
          ),
        ),
      );
    }

    final children = <Widget>[];

    if (priority.isNotEmpty) {
      children.add(
          const _SectionLabel(label: 'Priority', icon: Icons.business_rounded));
      children.add(const SizedBox(height: 8));
      for (final c in priority) {
        children.add(ChatConversationRow(
            conversation: c,
            priority: true,
            onTap: () => _openConversation(c)));
        children.add(const SizedBox(height: 8));
      }
      children.add(const SizedBox(height: 8));
    }

    if (normal.isNotEmpty) {
      children.add(
          const _SectionLabel(label: 'Messages', icon: Icons.forum_outlined));
      children.add(const SizedBox(height: 8));
      for (final c in normal) {
        children.add(ChatConversationRow(
            conversation: c,
            priority: false,
            onTap: () => _openConversation(c)));
        children.add(const SizedBox(height: 8));
      }
    }

    if (controller.loadingMoreConversations) {
      children.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: DriverColors.primary))),
      ));
    }

    return SliverList(delegate: SliverChildListDelegate(children));
  }
}

class _ArchiveShortcut extends StatelessWidget {
  final VoidCallback onTap;
  const _ArchiveShortcut({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Archived conversations',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DriverColors.border)),
          child: const Icon(Icons.archive_outlined,
              size: 19, color: DriverColors.textSecondary),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: DriverColors.textSecondary),
        const SizedBox(width: 6),
        Text(label, style: DriverText.label),
      ],
    );
  }
}

/// Small "Buyer"/"Seller" pill next to a 'delivery' row's name — see
/// [ChatConversation.employerRole].
class _RoleTag extends StatelessWidget {
  final String role;
  const _RoleTag({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(6)),
      child: Text(
        role == 'seller' ? 'Seller' : 'Buyer',
        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: DriverColors.primaryDark),
      ),
    );
  }
}

/// One inbox row — shared by the main inbox and the Archived screen so
/// both stay visually identical. [priority] adds a subtle building icon +
/// left accent, never a loud banner.
class ChatConversationRow extends StatelessWidget {
  final ChatConversation conversation;
  final bool priority;
  final VoidCallback onTap;

  const ChatConversationRow({
    super.key,
    required this.conversation,
    required this.priority,
    required this.onTap,
  });

  String _timeLabel(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount > 0;

    final borderRadius = BorderRadius.circular(16);

    // BoxDecoration refuses a borderRadius when the border's sides don't
    // share one uniform color (throws "borderRadius can only be given on
    // borders with uniform colors" — silently blanking this whole row while
    // still leaving the InkWell tappable). The priority accent needs a
    // different color on just the left edge, so it's drawn as a separate
    // clipped stripe instead of a mismatched Border side; the decoration's
    // own border stays a single uniform color on all four sides.
    return ClipRRect(
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius,
            border: Border.all(
                color: unread
                    ? DriverColors.primary.withOpacity(0.3)
                    : DriverColors.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                    width: 3,
                    color: priority ? DriverColors.primary : Colors.transparent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        ChatAvatar(
                          avatarUrl: conversation.employerAvatarUrl,
                          size: 44,
                          online: conversation.employerOnline,
                          priority: priority,
                          fallbackText: conversation.avatarInitial,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      conversation.employerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: unread
                                              ? FontWeight.w800
                                              : FontWeight.w700,
                                          fontSize: 14,
                                          color: DriverColors.textPrimary),
                                    ),
                                  ),
                                  // Badges a 'delivery' row (a specific
                                  // order's buyer/seller, via the "Message"
                                  // button on the delivery-detail screen) so
                                  // it doesn't read like just another
                                  // employer thread now that both share one
                                  // inbox.
                                  if (conversation.type == 'delivery') ...[
                                    const SizedBox(width: 6),
                                    _RoleTag(role: conversation.employerRole),
                                  ],
                                  const Spacer(),
                                  Text(_timeLabel(conversation.lastMessageAt),
                                      style: DriverText.caption),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                conversation.lastMessage?.isNotEmpty == true
                                    ? conversation.lastMessage!
                                    : 'Say hello to get started',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: unread
                                      ? DriverColors.textPrimary
                                      : DriverColors.textSecondary,
                                  fontWeight: unread
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (unread)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                                color: DriverColors.primary,
                                borderRadius: BorderRadius.circular(20)),
                            child: Text('${conversation.unreadCount}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                          )
                        else if (conversation.needsResponse)
                          const Icon(Icons.reply_rounded,
                              size: 16, color: DriverColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
