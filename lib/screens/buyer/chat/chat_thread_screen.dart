import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../cart/cart_screen.dart';
import '../catalog/store_screen.dart';
import '../orders/order_detail_screen.dart';
import '../product/product_detail_screen.dart';
import '../widgets/buyer_widgets.dart';
import 'chat_assistant.dart';
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

/// The product the next message is "asking about" (web: the composer's
/// "Asking about" chip). Attached to the next send, then cleared.
class _Asking {
  const _Asking({required this.id, required this.name, this.image, this.variantId});

  final String id;
  final String name;
  final String? image;
  final String? variantId;
}

const _fallbackProductQuestions = ['Is this item available?', 'Do you have another size or color?', 'Can you send an actual photo?'];
const _fallbackOrderQuestions = ['When will my order be shipped?', 'I received the wrong item. What should I do?'];

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
  static const _maxPhotos = 4;
  final List<XFile> drafts = [];
  Timer? _poll;
  int _tempId = 0;

  // Shop assistant (web: suggestions row, "More quick questions", message Menu).
  List<QuickQuestion> quick = const [];
  List<QuickQuestion> menuQuestions = const [];
  String? _menuOpenId; // null = default (welcome message open), 'closed', or a message id
  _Asking? asking;
  bool _askingSeeded = false;
  _Subject? subject;

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
      _loadExtras();
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

  /// Header details (rating / courier company / blocked), the "asking about"
  /// product and the assistant's questions — fetched after the messages so
  /// they never delay them.
  Future<void> _loadExtras() async {
    final id = conversation?.id;
    if (id == null) return;
    try {
      final fresh = await store.api.conversation(id);
      if (!mounted) return;
      setState(() {
        conversation = fresh;
        if (!_askingSeeded && fresh.productId != null && fresh.orderNumber == null) {
          asking = _Asking(id: fresh.productId!, name: fresh.productName ?? 'Product', image: fresh.productImage);
        }
        if (subject == null) {
          if (fresh.orderNumber != null) {
            subject = _Subject.order(orderNumber: fresh.orderNumber!, title: fresh.orderName ?? '#${fresh.orderNumber}', image: fresh.orderImage, status: fresh.orderStatus);
          } else if (fresh.productId != null) {
            subject = _Subject.product(productId: fresh.productId!, title: fresh.productName ?? 'Product', image: fresh.productImage, price: fresh.productPrice, oldPrice: fresh.productOldPrice);
          }
        }
        _askingSeeded = true;
      });
    } catch (_) {}
    final c = conversation;
    if (c == null || !c.isSeller || c.readOnly) return;
    try {
      final results = await Future.wait([store.api.quickQuestions(id), store.api.quickQuestions(id, menu: true)]);
      if (mounted) {
        setState(() {
          quick = results[0];
          menuQuestions = results[1];
        });
      }
    } catch (_) {}
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

  Future<void> _send({
    String? text,
    List<String> attachmentIds = const [],
    ChatMessage? retry,
    String? quickKey,
    String? orderId,
    String? productId,
    String? variantId,
    bool contactSeller = false,
  }) async {
    final c = conversation;
    if (c == null) return;
    final body = (text ?? '').trim();
    if (body.isEmpty && attachmentIds.isEmpty) return;

    // The "Asking about" product rides along with the message, then clears.
    final about = asking;
    // A message is about a product OR an order, never both.
    final sub = subject;
    if (orderId == null && sub != null && sub.isOrder) orderId = sub.orderId;
    if (orderId == null) {
      productId ??= about?.id;
      variantId ??= about?.variantId;
    }

    final temp = ChatMessage(id: 'local-${_tempId++}', from: 'buyer', text: body, at: DateTime.now(), pending: true);
    setState(() {
      if (retry != null) messages.remove(retry);
      messages.add(temp);
      asking = null;
    });
    if (retry == null && attachmentIds.isEmpty && quickKey == null && !contactSeller) input.clear();
    _jumpToBottom();

    try {
      final (sent, auto) = await store.api.sendMessage(
        c.id,
        text: body,
        attachmentIds: attachmentIds,
        quickQuestionKey: quickKey,
        orderId: orderId,
        productId: productId,
        variantId: variantId,
        contactSeller: contactSeller,
      );
      if (!mounted) return;
      setState(() {
        final i = messages.indexOf(temp);
        // The poll may already have delivered it.
        if (messages.any((m) => m.id == sent.id)) {
          messages.removeAt(i);
        } else {
          messages[i] = sent;
        }
        if (auto != null && !messages.any((m) => m.id == auto.id)) messages.add(auto);
      });
      if (auto != null) _jumpToBottom();
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
    final room = _maxPhotos - drafts.length;
    final picker = ImagePicker();
    final List<XFile> picked;
    if (source == ImageSource.camera || room < 2) {
      final one = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      picked = one == null ? [] : [one];
    } else {
      picked = await picker.pickMultiImage(maxWidth: 1600, imageQuality: 80, limit: room);
    }
    if (picked.isEmpty || !mounted) return;
    setState(() => drafts.addAll(picked.take(room)));
    if (picked.length > room) showToast(context, 'Up to $_maxPhotos photos per message.');
  }

  /// Uploads the staged photos, then sends them with the typed caption.
  Future<void> _submit() async {
    if (drafts.isEmpty) return _send(text: input.text);
    setState(() => uploading = true);
    try {
      final files = [...drafts];
      final ids = await Future.wait([
        for (final f in files) f.readAsBytes().then((bytes) => store.api.uploadChatAttachment(bytes, f.name)),
      ]);
      if (!mounted) return;
      final caption = input.text;
      input.clear();
      setState(drafts.clear);
      await _send(text: caption, attachmentIds: ids);
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  // ---------------- Shop assistant ----------------

  /// Web `selectQuestion`: stock → pick a product; order question → pick an
  /// order; otherwise send it as a canned question. A question with no key
  /// (the built-in fallbacks) just fills the message box.
  Future<void> _selectQuestion(QuickQuestion q) async {
    final id = conversation?.id;
    if (id == null) return;
    if (q.key.isEmpty) {
      input.text = q.question;
      input.selection = TextSelection.collapsed(offset: q.question.length);
      return;
    }
    ChatPick? pick;
    if (q.isStock) {
      pick = await pickProduct(context, id);
      if (pick == null) return;
    } else if (q.needsOrder) {
      pick = await pickOrderItem(context, id);
      if (pick == null) return;
    }
    if (!mounted) return;
    setState(() {
      if (pick?.orderId != null) {
        // Asking about an order replaces any product at the top.
        subject = _Subject.order(orderNumber: pick!.orderNumber ?? '', title: pick.productName ?? '#${pick.orderNumber}', image: pick.productImage, status: pick.orderStatus, orderId: pick.orderId);
        asking = null;
      } else if (pick?.productId != null) {
        _setProductSubject(pick!);
      }
      _menuOpenId = 'closed';
    });
    _send(text: q.question, quickKey: q.key, orderId: pick?.orderId ?? q.orderId, productId: pick?.productId, variantId: pick?.variantId);
  }

  void _contactSeller() {
    setState(() {
      _menuOpenId = 'closed';
    });
    _send(text: "I'd like to chat with the seller.", contactSeller: true);
  }

  /// Change (or set) the product the next message asks about.
  Future<void> _changeAsking() async {
    final id = conversation?.id;
    if (id == null) return;
    final pick = await pickProduct(context, id);
    if (pick == null || pick.productId == null || !mounted) return;
    setState(() => _setProductSubject(pick));
  }

  /// The composer's circle "+": switch what the next messages are about.
  Future<void> _openAskMenu() async {
    final id = conversation?.id;
    if (id == null) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: BColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: BColors.border, borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Align(alignment: Alignment.centerLeft, child: Text('Ask about', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BColors.ink))),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined, color: BColors.brand),
            title: const Text('Product', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Pick something from this shop', style: BText.tiny),
            trailing: const Icon(Icons.chevron_right_rounded, color: BColors.faint),
            onTap: () => Navigator.pop(context, 'product'),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined, color: BColors.brand),
            title: const Text('Order', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('One of your orders with this shop', style: BText.tiny),
            trailing: const Icon(Icons.chevron_right_rounded, color: BColors.faint),
            onTap: () => Navigator.pop(context, 'order'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'product') return _changeAsking();
    final pick = await pickActiveOrder(context, id);
    if (pick == null || pick.orderId == null || !mounted) return;
    setState(() {
      subject = _Subject.order(orderNumber: pick.orderNumber ?? '', title: pick.productName ?? '#${pick.orderNumber}', image: pick.productImage, status: pick.orderStatus, orderId: pick.orderId);
      asking = null;
    });
  }

  /// Asking about a product replaces any order at the top.
  void _setProductSubject(ChatPick pick) {
    asking = _Asking(id: pick.productId!, name: pick.productName ?? 'Product', image: pick.productImage, variantId: pick.variantId);
    subject = _Subject.product(productId: pick.productId!, title: pick.productName ?? 'Product', image: pick.productImage, price: pick.productPrice);
  }

  bool _menuOpenFor(ChatMessage m) => _menuOpenId == m.id || (m.source == 'auto_reply_welcome' && _menuOpenId == null);

  Future<void> _addStockReplyToCart(Map<String, dynamic> ctx) async {
    final productId = ctx['id']?.toString();
    if (productId == null) return;
    if ((ctx['stock'] as num? ?? 0) <= 0) {
      showToast(context, 'This variant is out of stock.', error: true);
      return;
    }
    try {
      final product = await store.api.product(productId);
      if (!mounted) return;
      if (product == null) {
        showToast(context, 'This product is no longer available.', error: true);
        return;
      }
      final variantId = ctx['variantId']?.toString();
      final variant = variantId == null ? null : product.variants.where((v) => v.id == variantId).firstOrNull;
      final r = store.addToCart(product, variant, 1);
      showToast(
        context,
        r.ok ? '${r.message} · ${product.name}' : r.message,
        error: !r.ok,
        icon: r.ok ? Icons.shopping_cart_rounded : null,
        action: r.ok
            ? SnackBarAction(
                label: 'View cart',
                textColor: const Color(0xFF86EFAC),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen(standalone: true))),
              )
            : null,
      );
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    }
  }

  // ---------------- Navigation / thread actions ----------------

  void _visitShop() {
    final c = conversation;
    if (c == null || !c.isSeller || c.counterpartId == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoreScreen(storeId: c.counterpartId!, name: c.name, logo: c.avatarUrl)));
  }

  Future<void> _viewSubject() async {
    final x = subject;
    if (x == null) return;
    if (!x.isOrder) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: x.productId!)));
      return;
    }
    try {
      final order = await store.api.order(x.orderNumber!);
      if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)));
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    }
  }

  Future<void> _toggleBlock() async {
    final c = conversation;
    if (c == null || c.counterpartId == null) return;
    if (!c.blocked) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Block ${c.name}?'),
          content: const Text("You won't see their products and can't message them about new purchases. You can unblock anytime."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Block', style: TextStyle(color: BColors.error))),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      c.blocked ? await store.api.unblockShop(c.counterpartId!) : await store.api.blockShop(c.counterpartId!);
      if (!mounted) return;
      setState(() {
        conversation = c.copyWith(blocked: !c.blocked);
        if (!c.blocked) {
          quick = const [];
          menuQuestions = const [];
        }
      });
      if (c.blocked) _loadExtras();
      showToast(context, c.blocked ? '${c.name} unblocked.' : '${c.name} blocked.');
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    }
  }

  Future<void> _toggleArchive() async {
    final c = conversation;
    if (c == null) return;
    try {
      await store.api.setConversationStatus(c.id, c.archived ? 'open' : 'archived');
      if (!mounted) return;
      showToast(context, c.archived ? 'Moved back to your inbox.' : 'Conversation archived.');
      if (c.archived) {
        setState(() => conversation = c.copyWith(archived: false));
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    }
  }

  Future<void> _toggleResolved() async {
    final c = conversation;
    if (c == null) return;
    final next = c.status == 'resolved' ? 'open' : 'resolved';
    try {
      await store.api.setConversationStatus(c.id, next);
      if (!mounted) return;
      setState(() => conversation = c.copyWith(status: next));
      showToast(context, next == 'resolved' ? 'Marked as resolved.' : 'Conversation reopened.');
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
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
        title: c == null ? const Text('Chat', style: BText.title) : _ThreadHeader(conversation: c),
        actions: c == null
            ? null
            : [
                if (c.isSeller && c.counterpartId != null) IconButton(tooltip: 'Visit shop', onPressed: _visitShop, icon: const Icon(Icons.storefront_outlined)),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert_rounded),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (v) {
                    switch (v) {
                      case 'shop':
                        _visitShop();
                      case 'block':
                        _toggleBlock();
                      case 'archive':
                        _toggleArchive();
                      case 'resolve':
                        _toggleResolved();
                    }
                  },
                  itemBuilder: (_) => [
                    if (c.isSeller) const PopupMenuItem(value: 'shop', child: _MenuRow(Icons.storefront_outlined, 'Visit store')),
                    if (c.isSeller)
                      PopupMenuItem(
                        value: 'block',
                        child: _MenuRow(c.blocked ? Icons.lock_open_rounded : Icons.block_rounded, c.blocked ? 'Unblock shop' : 'Block shop', danger: !c.blocked),
                      ),
                    PopupMenuItem(
                      value: 'archive',
                      child: _MenuRow(c.archived ? Icons.unarchive_outlined : Icons.archive_outlined, c.archived ? 'Unarchive conversation' : 'Archive conversation'),
                    ),
                    if (c.type == 'direct')
                      PopupMenuItem(value: 'resolve', child: _MenuRow(Icons.check_circle_outline_rounded, c.status == 'resolved' ? 'Reopen conversation' : 'Mark as resolved')),
                  ],
                ),
              ],
      ),
      body: Column(children: [
        if (subject != null) _SubjectStrip(subject: subject!, onView: _viewSubject),
        Expanded(
          child: loadingInitial
              ? const Center(child: CircularProgressIndicator(color: BColors.brand))
              : error != null && messages.isEmpty
                  ? ErrorState(message: error!, onRetry: _start)
                  : messages.isEmpty
                      ? EmptyState(
                          icon: Icons.chat_bubble_outline,
                          title: 'Start the conversation',
                          message: c?.isCourier == true ? 'Ask your courier about the delivery.' : 'Start the conversation with ${c?.name ?? 'the shop'}. Your first message gets things going.',
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
                              _Bubble(
                                message: m,
                                onRetry: m.failed ? () => _send(text: m.text, retry: m) : null,
                                assistant: m.isAutomatic && c?.isSeller == true
                                    ? AssistantActions(
                                        questions: menuQuestions,
                                        menuOpen: _menuOpenFor(m),
                                        onToggleMenu: () => setState(() => _menuOpenId = _menuOpenFor(m) ? 'closed' : m.id),
                                        onSelect: _selectQuestion,
                                        onContact: _contactSeller,
                                        onAddToCart: m.quickQuestionKey == 'stock_availability' && m.productContext != null ? () => _addStockReplyToCart(m.productContext!) : null,
                                      )
                                    : null,
                              ),
                            ]);
                          },
                        ),
        ),
        if (c != null && !loadingInitial)
          if (c.blocked)
            _NoticeBar(icon: Icons.block_rounded, text: 'You blocked this shop. Unblock to send messages.', action: 'Unblock', onAction: _toggleBlock)
          else if (c.locked)
            _NoticeBar(icon: Icons.lock_outline_rounded, text: c.lockReason ?? 'This conversation is closed.')
          else
            _composer(c),
      ]),
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    final x = a.toLocal(), y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  /// Suggestions (web `suggestions`): the context's quick questions, or the
  /// built-in fallbacks when the shop has none configured.
  List<QuickQuestion> get _suggestions {
    if (quick.isNotEmpty) return quick;
    final texts = subject?.isOrder == true ? _fallbackOrderQuestions : _fallbackProductQuestions;
    return [for (final t in texts) QuickQuestion(key: '', question: t, contextType: 'general')];
  }

  Widget _composer(ChatConversation c) {
    final canSend = (input.text.trim().isNotEmpty || drafts.isNotEmpty) && !uploading;
    final showTools = c.isSeller && input.text.isEmpty;
    return Container(
      decoration: const BoxDecoration(color: BColors.surface, border: Border(top: BorderSide(color: BColors.border))),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (subject?.isOrder == true)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 14, color: BColors.faint),
                SizedBox(width: 6),
                Expanded(child: Text('Returns and refunds are requested from your order, not by chat.', style: BText.tiny)),
              ]),
            ),
          if (drafts.isNotEmpty)
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                itemCount: drafts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(clipBehavior: Clip.none, children: [
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(drafts[i].path), width: 64, height: 64, fit: BoxFit.cover, cacheWidth: 192)),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: uploading ? null : () => setState(() => drafts.removeAt(i)),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(color: BColors.ink, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          if (asking != null) _AskingChip(asking: asking!, onChange: _changeAsking, onClear: () => setState(() => asking = null)),
          if (showTools) ...[
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                children: [
                  for (final q in _suggestions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(q.question),
                        onPressed: () => _selectQuestion(q),
                        backgroundColor: BColors.surface,
                        visualDensity: VisualDensity.compact,
                        side: const BorderSide(color: BColors.border),
                        labelStyle: const TextStyle(fontSize: 12.5, color: BColors.ink),
                      ),
                    ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 6, 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              IconButton(
                tooltip: 'Send a photo',
                onPressed: uploading || drafts.length >= _maxPhotos ? null : _attach,
                icon: uploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: BColors.brand))
                    : const Icon(Icons.add_photo_alternate_outlined, color: BColors.brand),
              ),
              if (c.isSeller)
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 7),
                  child: Tooltip(
                    message: 'Ask about a product or order',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _openAskMenu,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: BColors.brand, width: 1.6)),
                        child: const Icon(Icons.add_rounded, size: 22, color: BColors.brand),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: input,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Message ${c.name}',
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: BColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Send',
                onPressed: canSend ? _submit : null,
                icon: Icon(Icons.send_rounded, color: canSend ? BColors.cta : BColors.faint),
              ),
            ]),
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

// ============================================================
// Messages
// ============================================================

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onRetry, this.assistant});

  final ChatMessage message;
  final VoidCallback? onRetry;

  /// Menu / Add to cart / Chat with seller, under an automatic reply.
  final Widget? assistant;

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
    final auto = m.isAutomatic;
    final time = chatTimeLabel(m.at);
    final fg = mine ? Colors.white : BColors.ink;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (auto ? 0.88 : 0.78)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
            if (m.orderContext != null) _OrderCard(context: m.orderContext!),
            if (m.attachments.isNotEmpty)
              Wrap(
                alignment: mine ? WrapAlignment.end : WrapAlignment.start,
                spacing: 4,
                runSpacing: 4,
                children: [for (final a in m.attachments) _AttachmentView(attachment: a, size: m.attachments.length > 1 ? 130 : 200)],
              ),
            if ((m.text != null && m.text!.isNotEmpty) || m.productContext != null)
              Container(
                padding: auto ? const EdgeInsets.fromLTRB(16, 14, 16, 14) : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: mine ? BColors.brand : BColors.surface,
                  border: mine ? null : Border.all(color: BColors.border),
                  borderRadius: auto
                      ? BorderRadius.circular(16)
                      : BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(mine ? 14 : 4),
                          bottomRight: Radius.circular(mine ? 4 : 14),
                        ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (auto)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        m.source == 'auto_reply_welcome' ? 'SHOP ASSISTANT' : 'AUTOMATIC REPLY',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: BColors.brand),
                      ),
                    ),
                  if (m.productContext != null) _ProductReference(context: m.productContext!, onDark: mine),
                  if (m.text != null && m.text!.isNotEmpty) Text(m.text!, style: TextStyle(fontSize: auto ? 15 : 14, height: auto ? 1.5 : 1.35, color: fg)),
                ]),
              ),
            if (assistant != null) Padding(padding: const EdgeInsets.only(top: 2), child: assistant),
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
  const _AttachmentView({required this.attachment, this.size = 200});

  final ChatAttachment attachment;
  final double size;

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
            child: SizedBox(width: size, height: size, child: NetImage(a.url)),
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

/// The product a message is about, shown inside its bubble (web `msg-product-reference`).
class _ProductReference extends StatelessWidget {
  const _ProductReference({required this.context, required this.onDark});

  final Map<String, dynamic> context;
  final bool onDark;

  @override
  Widget build(BuildContext ctx) {
    final id = context['id']?.toString();
    final variant = context['variant'];
    final detail = variant is Map && variant.isNotEmpty ? variant.values.join(' / ') : null;
    final fg = onDark ? Colors.white : BColors.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: id == null ? null : () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: id))),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: onDark ? Colors.white.withValues(alpha: 0.14) : BColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 44, height: 44, child: NetImage(context['image']?.toString())),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Product inquiry', style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.72))),
                Text('${context['name'] ?? 'Product'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
                if (detail != null) Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: fg.withValues(alpha: 0.72))),
              ]),
            ),
          ]),
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
    final status = context['status']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(BRadius.md), border: Border.all(color: BColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(BRadius.sm),
          child: SizedBox(width: 48, height: 48, child: NetImage(context['previewImage']?.toString(), fallbackIcon: Icons.receipt_long_outlined)),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Order #${context['orderNumber'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              if (status != null && status.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(10)),
                  child: Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: BColors.brand)),
                ),
              ],
            ]),
            if (context['previewName'] != null) Text('${context['previewName']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.tiny),
            if (total is num) Text(peso(total), style: const TextStyle(fontSize: 12.5, color: BColors.cta, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

// ============================================================
// Header / strips / composer parts
// ============================================================

/// Avatar, name and a presence line: "Online | ★ 4.8 · 120 ratings" for a
/// shop, "Online | <logistics company>" for a courier.
class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final online = c.online;
    final Widget? detail = c.isCourier
        ? (c.courierCompany == null ? null : _Detail(Icons.local_shipping_rounded, c.courierCompany!))
        : (c.isSeller && c.rating != null
            ? _Detail(Icons.star_rounded, c.rating!.toStringAsFixed(1), iconColor: BColors.warning)
            : null);
    return Row(children: [
      ChatAvatar(name: c.name, url: c.avatarUrl, courier: c.isCourier, radius: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 1),
          Row(children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? BColors.success : BColors.faint)),
            const SizedBox(width: 5),
            Text(online ? 'Online' : 'Offline', style: TextStyle(fontSize: 11.5, color: online ? BColors.success : BColors.muted)),
            if (detail != null) ...[
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('|', style: TextStyle(fontSize: 11.5, color: BColors.border))),
              Flexible(child: detail),
            ],
            if (c.status == 'resolved') ...[
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('|', style: TextStyle(fontSize: 11.5, color: BColors.border))),
              const Text('Resolved', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: BColors.brand)),
            ],
          ]),
        ]),
      ),
    ]);
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.icon, this.text, {this.iconColor = BColors.brand});

  final IconData icon;
  final String text;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 3),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: BColors.muted))),
      ]);
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.danger = false});

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 20, color: danger ? BColors.error : BColors.ink),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: danger ? BColors.error : BColors.ink)),
      ]);
}

class _StripShell extends StatelessWidget {
  const _StripShell({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: BColors.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: BColors.divider), bottom: BorderSide(color: BColors.border))),
            child: child,
          ),
        ),
      );
}

/// What the buyer is currently asking about - one slot, product OR order -
/// pinned above the messages. Choosing the other kind replaces it.
class _Subject {
  const _Subject.product({required this.productId, required this.title, this.image, this.price, this.oldPrice})
      : orderNumber = null,
        orderId = null,
        status = null;
  const _Subject.order({required this.orderNumber, required this.title, this.image, this.status, this.orderId})
      : productId = null,
        price = null,
        oldPrice = null;

  final String? productId;
  final String? orderNumber;
  final String? orderId;
  final String title;
  final String? image;
  final double? price;
  final double? oldPrice;
  final String? status;

  bool get isOrder => orderNumber != null;
}

class _SubjectStrip extends StatelessWidget {
  const _SubjectStrip({required this.subject, required this.onView});

  final _Subject subject;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final x = subject;
    return _StripShell(
      onTap: onView,
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: x.isOrder ? 64 : 44, height: 44, child: NetImage(x.image, fallbackIcon: x.isOrder ? Icons.inventory_2_outlined : Icons.image_outlined)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(x.isOrder ? 'ABOUT ORDER' : 'ABOUT PRODUCT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: BColors.faint)),
            Row(children: [
              Flexible(child: Text(x.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800))),
              if (x.status != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(10)),
                  child: Text(x.status!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: BColors.brand)),
                ),
              ],
            ]),
            if (x.price != null)
              Row(children: [
                Text(peso(x.price!), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: BColors.cta)),
                if (x.oldPrice != null) ...[
                  const SizedBox(width: 6),
                  Text(peso(x.oldPrice!), style: const TextStyle(fontSize: 11.5, color: BColors.faint, decoration: TextDecoration.lineThrough)),
                ],
              ]),
          ]),
        ),
        const Text('View', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BColors.brand)),
        const Icon(Icons.chevron_right_rounded, color: BColors.faint),
      ]),
    );
  }
}

/// "Asking about <product>" with Change and remove — the next message carries it.
class _AskingChip extends StatelessWidget {
  const _AskingChip({required this.asking, required this.onChange, required this.onClear});

  final _Asking asking;
  final VoidCallback onChange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        padding: const EdgeInsets.fromLTRB(6, 6, 2, 6),
        decoration: BoxDecoration(color: BColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: BColors.border)),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 32, height: 32, child: NetImage(asking.image))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Asking about', style: TextStyle(fontSize: 11, color: BColors.muted)),
              Text(asking.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BColors.ink)),
            ]),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Change', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: "Don't attach ${asking.name}",
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 18, color: BColors.muted),
          ),
        ]),
      );
}

class _NoticeBar extends StatelessWidget {
  const _NoticeBar({required this.icon, required this.text, this.action, this.onAction});

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: BColors.surface, border: Border(top: BorderSide(color: BColors.border))),
        padding: EdgeInsets.fromLTRB(16, 12, 12, MediaQuery.paddingOf(context).bottom + 12),
        child: Row(children: [
          Icon(icon, size: 20, color: BColors.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: BColors.muted))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ]),
      );
}
