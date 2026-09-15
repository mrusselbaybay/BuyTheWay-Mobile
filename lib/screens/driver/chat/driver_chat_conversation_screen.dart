import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';
import 'chat_models.dart';
import 'driver_chat_controller.dart';

/// A single conversation — the rider's thread with their employer. Loads
/// only once opened (cached-then-refresh via [DriverChatController.
/// openConversation]), paginates older history on scroll-to-top, sends
/// optimistically, and keeps the fast (~5s) message poll running for as
/// long as this screen stays open.
class DriverChatConversationScreen extends StatefulWidget {
  final DriverChatController controller;
  final ChatConversation conversation;

  const DriverChatConversationScreen({super.key, required this.controller, required this.conversation});

  @override
  State<DriverChatConversationScreen> createState() => _DriverChatConversationScreenState();
}

class _DriverChatConversationScreenState extends State<DriverChatConversationScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _updatingStatus = false;
  int _lastAppendedTick = 0;

  static const _quickReplies = ['On my way', 'Got it', "I'm here", 'Thank you!'];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    // Deferred for the same reason as DriverChatListScreen's initial
    // loadConversations() call — openConversation() notifies synchronously
    // before its first await when nothing's cached yet, which would trip
    // "setState() called during build" if this screen is ever pushed
    // during another widget's build rather than from a plain tap handler.
    // Scrolls to the bottom once messages are loaded/rendered — opening an
    // existing conversation should start at the latest message, not the
    // top (harmless no-op if content is already short enough to not
    // scroll, or if messages were already cached and this just reaffirms
    // the position).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await widget.controller.openConversation(widget.conversation.id);
      if (mounted) _scrollToBottom();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.closeConversation();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;

    // A poll-received message was appended to this thread (never fired for
    // loadOlderMessages()'s prepended history — see messagesAppendedTick's
    // docblock). Only auto-scroll if already near the bottom, so a rider
    // reading older messages isn't yanked back down by an incoming one.
    final tick = widget.controller.messagesAppendedTick[widget.conversation.id] ?? 0;
    if (tick != _lastAppendedTick) {
      _lastAppendedTick = tick;
      if (_isNearBottom()) _scrollToBottom();
    }

    setState(() {});
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 80;
  }

  void _onScroll() {
    // Reading top-to-bottom in a normal (non-reversed) ListView, so "near
    // the top" is what should trigger loading older history.
    if (_scrollController.hasClients && _scrollController.position.pixels < 120) {
      widget.controller.loadOlderMessages(widget.conversation.id);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send([String? presetText]) async {
    final text = (presetText ?? _inputController.text).trim();
    if (text.isEmpty || _sending) return;

    _inputController.clear();
    setState(() => _sending = true);
    _scrollToBottom();
    await widget.controller.sendMessage(widget.conversation.id, text);
    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _retry(String localId) async {
    await widget.controller.retryMessage(widget.conversation.id, localId);
    _scrollToBottom();
  }

  static const _maxGalleryAttachments = 10;

  Future<void> _pickAttachment() async {
    final source = await showModalBottomSheet<_AttachSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AttachmentSourceSheet(),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = <PendingAttachment>[];

    try {
      switch (source) {
        case _AttachSource.gallery:
          final xFiles = await picker.pickMultipleMedia(imageQuality: 85, maxWidth: 1600, limit: _maxGalleryAttachments);
          for (final x in xFiles) {
            picked.add(PendingAttachment(bytes: await x.readAsBytes(), fileName: x.name, mimeType: x.mimeType ?? _guessMimeType(x.name)));
          }
        case _AttachSource.cameraPhoto:
          final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600);
          if (x != null) picked.add(PendingAttachment(bytes: await x.readAsBytes(), fileName: x.name, mimeType: x.mimeType ?? 'image/jpeg'));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access the camera or photo library.'), behavior: SnackBarBehavior.floating, backgroundColor: DriverColors.error),
        );
      }
      return;
    }

    if (picked.isEmpty) return;

    // Same allow-list/size caps the server enforces (and the web composer
    // already checks before upload) — reject instantly instead of spending
    // the upload round-trip only to be bounced by the server.
    final files = <PendingAttachment>[];
    String? rejectionReason;
    for (final f in picked) {
      final error = f.validate();
      if (error == null) {
        files.add(f);
      } else {
        rejectionReason ??= error;
      }
    }

    if (rejectionReason != null && mounted) {
      final skipped = picked.length - files.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(files.isEmpty ? rejectionReason : '$rejectionReason ($skipped file${skipped == 1 ? '' : 's'} skipped)'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: DriverColors.error,
        ),
      );
    }

    if (files.isEmpty) return;
    _scrollToBottom();
    await widget.controller.sendAttachments(widget.conversation.id, files);
    _scrollToBottom();
  }

  String _guessMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    const map = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'gif': 'image/gif', 'webp': 'image/webp', 'heic': 'image/heic',
      'mp4': 'video/mp4', 'mov': 'video/quicktime', 'm4v': 'video/x-m4v', '3gp': 'video/3gpp',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  Future<void> _toggleArchive() async {
    if (_updatingStatus) return;
    final archiving = !widget.conversation.archived;

    final confirmed = await DriverConfirmDialog.show(
      context,
      icon: archiving ? Icons.archive_rounded : Icons.unarchive_rounded,
      accent: DriverColors.primary,
      title: archiving ? 'Archive this conversation?' : 'Unarchive this conversation?',
      message: archiving
          ? "It'll move out of your inbox into Archived. You can bring it back anytime."
          : "It'll move back into your main inbox.",
      confirmLabel: archiving ? 'Archive' : 'Unarchive',
      confirmIcon: archiving ? Icons.archive_rounded : Icons.unarchive_rounded,
    );
    if (confirmed != true) return;

    setState(() => _updatingStatus = true);
    try {
      await widget.controller.setConversationStatus(widget.conversation.id, archiving ? 'archived' : 'open');
      if (!mounted) return;
      DriverTopNotification.show(context, message: archiving ? 'Conversation archived.' : 'Conversation moved back to inbox.');
      if (archiving) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this conversation.'), behavior: SnackBarBehavior.floating, backgroundColor: DriverColors.error),
        );
      }
    }
    if (mounted) setState(() => _updatingStatus = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final id = widget.conversation.id;
    // Prefer the live, possibly-updated instance from the controller's list
    // (e.g. online status flipped since this screen was opened) with the
    // constructor's copy as a fallback for a just-created conversation.
    final conversation = controller.conversationById(id) ?? widget.conversation;
    final messages = controller.messagesFor(id);
    final loading = controller.loadingMessagesFor[id] == true && messages.isEmpty;
    final error = controller.messagesErrorFor[id];

    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: DriverColors.textPrimary,
        titleSpacing: 0,
        title: Row(
          children: [
            ChatAvatar(avatarUrl: conversation.employerAvatarUrl, size: 34, online: conversation.employerOnline, priority: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(conversation.employerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(conversation.employerOnline ? 'Online' : 'Offline', style: TextStyle(fontSize: 11, color: conversation.employerOnline ? DriverColors.success : DriverColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _updatingStatus ? null : _toggleArchive,
            icon: Icon(conversation.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
            tooltip: conversation.archived ? 'Unarchive' : 'Archive',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _body(loading, error, messages)),
          if (!conversation.archived) ...[
            _quickReplyRow(),
            _composer(),
          ] else
            _archivedNotice(),
        ],
      ),
    );
  }

  Widget _body(bool loading, String? error, List<ChatMessage> messages) {
    if (loading) {
      return const DriverChatSkeleton();
    }

    if (error != null && messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DriverEmptyState(icon: Icons.wifi_off_rounded, title: "Couldn't load messages", subtitle: error),
        ),
      );
    }

    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: DriverEmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'Say hello', subtitle: 'Start the conversation with your employer.'),
        ),
      );
    }

    final hasMore = widget.controller.hasMoreOlder(widget.conversation.id);
    const verticalPadding = 14.0 + 8.0; // matches the ListView's own top+bottom padding below

    return DriverRefreshable(
      onRefresh: () => widget.controller.openConversation(widget.conversation.id),
      // LayoutBuilder + a min-height bottom-aligned Column as the ListView's
      // single child — the standard Flutter chat-thread trick. A short
      // conversation's messages sit at the bottom of the viewport (like a
      // real chat thread) instead of stacking from the top with empty space
      // below, while the ListView/_scrollController itself (pagination,
      // scroll-position preservation on load-older) is completely
      // untouched — it still just scrolls this one child once content
      // actually exceeds the viewport.
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: (constraints.maxHeight - verticalPadding).clamp(0, double.infinity)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (hasMore)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: DriverColors.primary))),
                      ),
                    ...messages.map((m) => ChatBubble(message: m, onRetry: m.localId != null ? () => _retry(m.localId!) : null)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _archivedNotice() {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            const Icon(Icons.archive_outlined, size: 16, color: DriverColors.primaryDark),
            const SizedBox(width: 8),
            const Expanded(child: Text('This conversation is archived.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: DriverColors.primaryDark))),
            TextButton(onPressed: _toggleArchive, child: const Text('Unarchive')),
          ],
        ),
      ),
    );
  }

  Widget _quickReplyRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final reply = _quickReplies[i];
          return OutlinedButton(
            onPressed: () => _send(reply),
            style: OutlinedButton.styleFrom(
              foregroundColor: DriverColors.primaryDark,
              side: BorderSide(color: DriverColors.primary.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(reply, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          );
        },
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: _pickAttachment,
            icon: const Icon(Icons.add_photo_alternate_outlined, color: DriverColors.primary),
          ),
          Expanded(
            child: TextField(
              controller: _inputController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type a message',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: DriverColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: DriverColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: DriverColors.primary, width: 1.4)),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(gradient: LinearGradient(colors: DriverColors.primaryGradient), shape: BoxShape.circle),
            child: IconButton(onPressed: _sending ? null : () => _send(), icon: const Icon(Icons.send_rounded, color: Colors.white, size: 19)),
          ),
        ],
      ),
    );
  }
}

enum _AttachSource { gallery, cameraPhoto }

/// Bottom sheet asking where the attachment should come from — the device's
/// photo library (multi-select, images and videos together) or the camera
/// (a single photo capture).
class _AttachmentSourceSheet extends StatelessWidget {
  const _AttachmentSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Row(
                children: [
                  Text('Add attachment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: DriverColors.textPrimary)),
                ],
              ),
            ),
            _option(context, icon: Icons.photo_library_rounded, label: 'Photo Library', subtitle: 'Choose multiple photos or videos', source: _AttachSource.gallery),
            _divider(),
            _option(context, icon: Icons.camera_alt_rounded, label: 'Take Photo', source: _AttachSource.cameraPhoto),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: DriverColors.border);

  Widget _option(BuildContext context, {required IconData icon, required String label, String? subtitle, required _AttachSource source}) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(source),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: DriverColors.primary, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DriverColors.textPrimary)),
                  if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 11.5, color: DriverColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
