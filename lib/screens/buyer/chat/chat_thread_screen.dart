import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../product/product_detail_screen.dart';
import '../widgets/buyer_widgets.dart';
import 'chat_list_screen.dart';

/// Opens the buyer↔seller thread (creating it if needed), optionally about
/// a product or an order — the "Chat" buttons on product/order pages.
void openSellerChat(BuildContext context, {required String sellerId, String? productId, String? orderNumber}) {
  final api = BuyerStore.instance.api;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ChatThreadScreen(starter: () => api.startSellerChat(sellerId: sellerId, productId: productId, orderNumber: orderNumber)),
  ));
}

void openCourierChat(BuildContext context, String orderNumber) {
  final api = BuyerStore.instance.api;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatThreadScreen(starter: () => api.startCourierChat(orderNumber))));
}

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key, this.initial, this.starter}) : assert(initial != null || starter != null);

  final ChatConversation? initial;
  final Future<ChatConversation> Function()? starter;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final store = BuyerStore.instance;
  final input = TextEditingController();
  final scroll = ScrollController();

  late ChatConversation? conversation = widget.initial;
  String? error;

  /// Oldest → newest.
  final List<ChatMessage> messages = [];
  bool loadingInitial = true;
  bool loadingOlder = false;
  bool hasMore = false;
  String? olderCursor;
  bool uploading = false;
  Timer? _poll;
  int _tempId = 0;

  @override
  void initState() {
    super.initState();
    scroll.addListener(_onScroll);
    input.addListener(() => setState(() {}));
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    input.dispose();
    scroll.dispose();
    store.refreshChatUnread();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      error = null;
      loadingInitial = true;
    });
    try {
      conversation ??= await widget.starter!();
      final (list, more, cursor) = await store.api.messages(conversation!.id);
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(list);
        hasMore = more;
        olderCursor = cursor;
        loadingInitial = false;
      });
      _markRead();
      // Delivery while open: poll for anything newer than the last message.
      _poll ??= Timer.periodic(const Duration(seconds: 4), (_) => _pollNew());
    } catch (e) {
      if (mounted) {
        setState(() {
          error = store.handleError(e);
          loadingInitial = false;
        });
      }
    }
  }

  void _markRead() {
    final c = conversation;
    if (c != null) store.api.markConversationRead(c.id).catchError((_) {});
  }

  String? get _lastServerId => messages.lastWhere((m) => !m.pending && !m.failed, orElse: () => const ChatMessage(id: '', from: '')).id.ifEmptyNull;

  bool _polling = false;

  Future<void> _pollNew() async {
    final c = conversation;
    final after = _lastServerId;
    if (c == null || _polling || after == null) return;
    _polling = true;
    try {
      final (list, _, _) = await store.api.messages(c.id, after: after);
      if (!mounted || list.isEmpty) return;
      final known = messages.map((m) => m.id).toSet();
      final fresh = list.where((m) => !known.contains(m.id)).toList();
      if (fresh.isEmpty) return;
      setState(() => messages.addAll(fresh));
      if (fresh.any((m) => !m.mine)) _markRead();
    } catch (_) {
      // Transient — the next tick retries.
    } finally {
      _polling = false;
    }
  }

  void _onScroll() {
    // reverse: true → maxScrollExtent is the top (oldest).
    if (scroll.position.pixels > scroll.position.maxScrollExtent - 300) _loadOlder();
  }

  Future<void> _loadOlder() async {
    final c = conversation;
    if (c == null || loadingOlder || !hasMore || olderCursor == null) return;
    setState(() => loadingOlder = true);
    try {
      final (list, more, cursor) = await store.api.messages(c.id, before: olderCursor);
      if (!mounted) return;
      setState(() {
        messages.insertAll(0, list);
        hasMore = more;
        olderCursor = cursor;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => loadingOlder = false);
    }
  }

  Future<void> _send({String? text, List<String> attachmentIds = const [], ChatMessage? retry}) async {
    final c = conversation;
    if (c == null) return;
    final body = (text ?? '').trim();
    if (body.isEmpty && attachmentIds.isEmpty) return;

    final temp = ChatMessage(id: 'local-${_tempId++}', from: 'buyer', text: body, at: DateTime.now(), pending: true);
    setState(() {
      if (retry != null) messages.remove(retry);
      messages.add(temp);
    });
    if (retry == null && attachmentIds.isEmpty) input.clear();
    _jumpToBottom();

    try {
      final sent = await store.api.sendMessage(c.id, text: body, attachmentIds: attachmentIds);
      if (!mounted) return;
      setState(() {
        final i = messages.indexOf(temp);
        // The poll may already have delivered it.
        if (messages.any((m) => m.id == sent.id)) {
          messages.removeAt(i);
        } else {
          messages[i] = sent;
        }
      });
    } catch (e) {
      if (!mounted) return;
      final message = store.handleError(e);
      setState(() {
        final i = messages.indexOf(temp);
        if (i >= 0) messages[i] = ChatMessage(id: temp.id, from: 'buyer', text: body, at: temp.at, failed: true);
      });
      showToast(context, message, error: true);
    }
  }

  Future<void> _attach() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: BColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BRadius.md))),
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Photo library'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
        ]),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    if (file == null || !mounted) return;
    setState(() => uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final id = await store.api.uploadChatAttachment(bytes, file.name);
      final caption = input.text;
      input.clear();
      await _send(text: caption, attachmentIds: [id]);
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  void _jumpToBottom() {
    if (scroll.hasClients) scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    return Scaffold(
      backgroundColor: BColors.background,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        surfaceTintColor: BColors.surface,
        foregroundColor: BColors.ink,
        titleSpacing: 0,
        title: c == null
            ? const Text('Chat', style: BText.title)
            : Row(children: [
                ChatAvatar(name: c.name, url: c.avatarUrl, courier: c.isCourier, online: c.online, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(c.online ? 'Active now' : (c.isCourier ? 'Your courier' : 'Seller'),
                        style: TextStyle(fontSize: 11.5, color: c.online ? BColors.success : BColors.muted)),
                  ]),
                ),
              ]),
      ),
      body: Column(children: [
        Expanded(
          child: loadingInitial
              ? const Center(child: CircularProgressIndicator(color: BColors.brand))
              : error != null && messages.isEmpty
                  ? ErrorState(message: error!, onRetry: _start)
                  : messages.isEmpty
                      ? EmptyState(
                          icon: Icons.chat_bubble_outline,
                          title: 'Start the conversation',
                          message: c?.isCourier == true
                              ? 'Ask your courier about the delivery.'
                              : 'Ask about stock, sizes, or shipping — sellers usually reply within the day.',
                        )
                      : ListView.builder(
                          controller: scroll,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          itemCount: messages.length + (loadingOlder ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == messages.length) {
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: BColors.brand))),
                              );
                            }
                            final i = messages.length - 1 - index;
                            final m = messages[i];
                            final prev = i > 0 ? messages[i - 1] : null;
                            final showDay = prev == null || !_sameDay(prev.at, m.at);
                            return Column(children: [
                              if (showDay) _DayChip(at: m.at),
                              _Bubble(message: m, onRetry: m.failed ? () => _send(text: m.text, retry: m) : null),
                            ]);
                          },
                        ),
        ),
        if (c != null && !loadingInitial) _composer(),
      ]),
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    final x = a.toLocal(), y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  Widget _composer() {
    final canSend = input.text.trim().isNotEmpty;
    return Container(
      decoration: const BoxDecoration(color: BColors.surface, border: Border(top: BorderSide(color: BColors.border))),
      padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
      child: SafeArea(
        top: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          IconButton(
            tooltip: 'Send a photo',
            onPressed: uploading ? null : _attach,
            icon: uploading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: BColors.brand))
                : const Icon(Icons.add_photo_alternate_outlined, color: BColors.brand),
          ),
          Expanded(
            child: TextField(
              controller: input,
              minLines: 1,
              maxLines: 5,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message',
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: BColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Send',
            onPressed: canSend ? () => _send(text: input.text) : null,
            icon: Icon(Icons.send_rounded, color: canSend ? BColors.cta : BColors.faint),
          ),
        ]),
      ),
    );
  }
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.at});

  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final label = at == null ? '' : (chatTimeLabel(at).contains(':') ? 'Today' : chatTimeLabel(at));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: BColors.border, borderRadius: BorderRadius.circular(10)),
          child: Text(label, style: const TextStyle(fontSize: 11, color: BColors.muted)),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onRetry});

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m.from == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          if (m.orderContext != null) _OrderCard(context: m.orderContext!),
          if (m.text != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(m.text!, textAlign: TextAlign.center, style: BText.tiny),
            ),
        ]),
      );
    }

    final mine = m.mine;
    final time = chatTimeLabel(m.at);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
            if (m.productContext != null) _ProductCard(context: m.productContext!),
            if (m.orderContext != null) _OrderCard(context: m.orderContext!),
            for (final a in m.attachments) _AttachmentView(attachment: a),
            if (m.text != null && m.text!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: mine ? BColors.brand : BColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(mine ? 12 : 2),
                    bottomRight: Radius.circular(mine ? 2 : 12),
                  ),
                ),
                child: Text(m.text!, style: TextStyle(fontSize: 14, height: 1.35, color: mine ? Colors.white : BColors.ink)),
              ),
            const SizedBox(height: 2),
            if (m.failed)
              GestureDetector(
                onTap: onRetry,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.error_outline, size: 13, color: BColors.error),
                  SizedBox(width: 3),
                  Text('Not sent · Tap to retry', style: TextStyle(fontSize: 11, color: BColors.error)),
                ]),
              )
            else
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(m.pending ? 'Sending…' : time, style: BText.tiny),
                if (mine && !m.pending) ...[
                  const SizedBox(width: 3),
                  Icon(m.readAt != null ? Icons.done_all : Icons.done, size: 13, color: m.readAt != null ? BColors.brand : BColors.faint),
                ],
              ]),
          ]),
        ),
      ),
    );
  }
}

class _AttachmentView extends StatelessWidget {
  const _AttachmentView({required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    if (a.isImage && a.url != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (_) => Dialog(
              insetPadding: const EdgeInsets.all(12),
              backgroundColor: Colors.black,
              child: InteractiveViewer(child: NetImage(a.url, fit: BoxFit.contain)),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BRadius.md),
            child: SizedBox(width: 200, height: 200, child: NetImage(a.url)),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: BColors.surface,
        borderRadius: BorderRadius.circular(BRadius.md),
        child: InkWell(
          onTap: a.url == null ? null : () => launchUrl(Uri.parse(a.url!), mode: LaunchMode.externalApplication),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon((a.mime ?? '').startsWith('video/') ? Icons.videocam_outlined : Icons.insert_drive_file_outlined, color: BColors.brand),
              const SizedBox(width: 8),
              Flexible(child: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.context});

  final Map<String, dynamic> context;

  @override
  Widget build(BuildContext ctx) {
    final id = context['id']?.toString();
    final price = context['price'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: BColors.surface,
        borderRadius: BorderRadius.circular(BRadius.md),
        child: InkWell(
          onTap: id == null ? null : () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: id))),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(BRadius.sm),
                child: SizedBox(width: 48, height: 48, child: NetImage(context['image']?.toString())),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${context['name'] ?? 'Product'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  if (price is num) Text(peso(price), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BColors.cta)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.context});

  final Map<String, dynamic> context;

  @override
  Widget build(BuildContext ctx) {
    final total = context['total'];
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(BRadius.md), border: Border.all(color: BColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(BRadius.sm),
          child: SizedBox(width: 44, height: 44, child: NetImage(context['previewImage']?.toString(), fallbackIcon: Icons.receipt_long_outlined)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Order #${context['orderNumber'] ?? ''}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            if (context['previewName'] != null) Text('${context['previewName']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.tiny),
            if (total is num) Text(peso(total), style: const TextStyle(fontSize: 12.5, color: BColors.cta, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}
