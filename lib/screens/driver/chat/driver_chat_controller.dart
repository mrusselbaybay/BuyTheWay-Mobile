import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../services/api_service.dart';
import 'chat_models.dart';

/// Owns every piece of chat state for the driver/courier app — the inbox
/// list, the per-conversation message cache, pagination, search, and the
/// two poll timers — so it survives tab switches (kept alive by
/// [DriverShell]'s IndexedStack, exactly like `_assignedDeliveries`) and
/// conversation screens being pushed/popped on top.
///
/// Architecture mirrors the already-proven web pattern (useBuyerChat.js /
/// useMessaging.js): open the inbox instantly from whatever's cached, poll
/// the inbox slowly (~20s) for new-message previews, poll a fast (~5s)
/// cursor-based tick only while a specific thread is open, and send
/// optimistically with a local id so a failure can be retried without
/// duplicating on reconciliation. HTTP polling only, deliberately — see the
/// note on why this app doesn't use direct Supabase Realtime.
class DriverChatController extends ChangeNotifier {
  DriverChatController({required ApiService api, required String accessToken})
      : _api = api,
        _accessToken = accessToken;

  final ApiService _api;
  final String _accessToken;

  static const _metaPollInterval = Duration(seconds: 20);
  static const _messagePollInterval = Duration(seconds: 5);

  // ---- Inbox state ----
  List<ChatConversation> _conversations = [];
  bool loadingConversations = true;
  bool loadingMoreConversations = false;
  bool hasMoreConversations = false;
  String? conversationsError;
  int _page = 1;
  String _search = '';
  Timer? _searchDebounce;
  bool _disposed = false;

  // ---- Per-conversation message cache ----
  final Map<String, List<ChatMessage>> _messagesByConversation = {};
  final Map<String, bool> _hasMoreOlderByConversation = {};
  final Map<String, bool> loadingMessagesFor = {};
  final Map<String, String?> messagesErrorFor = {};
  // Bumped whenever a message is APPENDED to a conversation's end via the
  // poll (a real new/incoming message) — never for messages PREPENDED via
  // loadOlderMessages(). The conversation screen compares this against its
  // own last-seen value to decide whether to auto-scroll, without this
  // controller needing to know anything about scroll/DOM state itself.
  final Map<String, int> messagesAppendedTick = {};

  // ---- Poll lifecycle ----
  Timer? _metaPollTimer;
  Timer? _messagePollTimer;
  String? _activeConversationId;
  bool _inboxActive = false;
  bool _appVisible = true;
  int _localIdSequence = 0;

  // The server re-signs a fresh temporary URL for the same attachment on
  // every fetch (initial load, poll tick, older-messages page...) — see
  // MessageAttachment::contractUrl(). Passing that straight through churns
  // an Image.network's src on every ~5s poll even though nothing changed,
  // forcing a full re-download each time. Mirrors the web composer's own
  // fix (useMessaging.js's attachmentUrlCache/stabilizeMessage): cache the
  // signed URL per attachment id and keep reusing it until it's actually
  // close to expiring.
  final Map<String, String> _attachmentUrlCache = {};
  static const _signedUrlExpiryBufferMs = 60000;

  int? _signedUrlExpiryMs(String url) {
    final expires = int.tryParse(Uri.tryParse(url)?.queryParameters['expires'] ?? '');
    return (expires != null && expires > 0) ? expires * 1000 : null;
  }

  String _stabilizeAttachmentUrl(String id, String freshUrl) {
    if (id.isEmpty || freshUrl.isEmpty) return freshUrl;
    final cached = _attachmentUrlCache[id];
    if (cached != null) {
      final expiresAt = _signedUrlExpiryMs(cached);
      if (expiresAt == null || expiresAt - DateTime.now().millisecondsSinceEpoch > _signedUrlExpiryBufferMs) {
        return cached;
      }
    }
    _attachmentUrlCache[id] = freshUrl;
    return freshUrl;
  }

  ChatMessage _stabilizeMessage(ChatMessage message) {
    if (message.attachments.isEmpty) return message;
    return ChatMessage(
      id: message.id,
      senderRole: message.senderRole,
      text: message.text,
      sentAt: message.sentAt,
      readAt: message.readAt,
      status: message.status,
      localId: message.localId,
      attachments: [
        for (final a in message.attachments)
          ChatAttachment(id: a.id, url: _stabilizeAttachmentUrl(a.id, a.url), fileName: a.fileName, mimeType: a.mimeType, sizeBytes: a.sizeBytes, localBytes: a.localBytes),
      ],
    );
  }

  List<ChatConversation> get conversations => _conversations.where((c) => !c.archived).toList(growable: false);

  List<ChatConversation> get priorityConversations =>
      conversations.where((c) => c.isCurrentEmployer).toList(growable: false);

  List<ChatConversation> get normalConversations =>
      conversations.where((c) => !c.isCurrentEmployer).toList(growable: false);

  int get unreadTotal => _conversations.fold(0, (sum, c) => sum + (c.archived ? 0 : c.unreadCount));

  String get search => _search;

  List<ChatMessage> messagesFor(String conversationId) =>
      List.unmodifiable(_messagesByConversation[conversationId] ?? const []);

  bool hasMoreOlder(String conversationId) => _hasMoreOlderByConversation[conversationId] ?? false;

  ChatConversation? conversationById(String id) {
    for (final c in _conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Debounced search — mirrors the web inbox's search box: waits for a
  /// pause in typing before actually hitting the network, and cancels any
  /// still-pending request's relevance by checking `_search` hasn't moved
  /// on by the time the response lands.
  void setSearch(String value) {
    if (value == _search) return;
    _search = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      loadConversations();
    });
    _safeNotify();
  }

  /// Initial (or forced) load — shows the skeleton state. Called once on
  /// startup and by pull-to-refresh.
  Future<void> loadConversations({bool showLoading = true}) async {
    final searchAtRequest = _search;
    if (showLoading) {
      loadingConversations = true;
      conversationsError = null;
      _safeNotify();
    }

    try {
      final response = await _api.getChatConversations(
        accessToken: _accessToken,
        search: searchAtRequest,
        page: 1,
      );
      if (searchAtRequest != _search) return; // superseded by newer input

      final rows = (response['data'] as List? ?? [])
          .map((row) => ChatConversation.fromApi(Map<String, dynamic>.from(row as Map)))
          .toList();
      final meta = Map<String, dynamic>.from(response['meta'] as Map? ?? {});

      _conversations = rows;
      _page = 1;
      hasMoreConversations = (meta['currentPage'] ?? 1) < (meta['lastPage'] ?? 1);
      loadingConversations = false;
      conversationsError = null;
    } on ApiException catch (e) {
      if (searchAtRequest != _search) return;
      loadingConversations = false;
      conversationsError = e.message;
    } catch (_) {
      if (searchAtRequest != _search) return;
      loadingConversations = false;
      conversationsError = 'Could not reach the server. Check your connection and try again.';
    }
    _safeNotify();
  }

  /// Silent background refresh — used by the meta poll and by
  /// pull-to-refresh's "already have data" path. Merges in place onto
  /// existing [ChatConversation] instances where possible so a row that
  /// hasn't changed doesn't visually flicker.
  Future<void> _refreshConversationsSilently() async {
    try {
      final response = await _api.getChatConversations(accessToken: _accessToken, search: _search, page: 1);
      final rows = (response['data'] as List? ?? [])
          .map((row) => ChatConversation.fromApi(Map<String, dynamic>.from(row as Map)))
          .toList();

      final byId = {for (final c in _conversations) c.id: c};
      final merged = <ChatConversation>[];
      for (final fresh in rows) {
        final existing = byId[fresh.id];
        if (existing != null) {
          existing.applyFrom(fresh);
          merged.add(existing);
        } else {
          merged.add(fresh);
        }
      }
      _conversations = merged;
      conversationsError = null;
      _safeNotify();
    } catch (_) {
      // Silent — a failed background poll shouldn't disturb what's on screen.
    }
  }

  Future<void> loadMoreConversations() async {
    if (loadingMoreConversations || !hasMoreConversations) return;
    loadingMoreConversations = true;
    _safeNotify();

    try {
      final response = await _api.getChatConversations(
        accessToken: _accessToken,
        search: _search,
        page: _page + 1,
      );
      final rows = (response['data'] as List? ?? [])
          .map((row) => ChatConversation.fromApi(Map<String, dynamic>.from(row as Map)))
          .toList();
      final meta = Map<String, dynamic>.from(response['meta'] as Map? ?? {});

      _conversations = [..._conversations, ...rows];
      _page += 1;
      hasMoreConversations = (meta['currentPage'] ?? 1) < (meta['lastPage'] ?? 1);
    } catch (_) {
      // Leave hasMoreConversations as-is — the scroll trigger will retry.
    }
    loadingMoreConversations = false;
    _safeNotify();
  }

  /// Fetches the (separate) archived list — not cached/polled by this
  /// controller since the Archived screen is a one-off destination, not
  /// something the inbox needs to keep live.
  Future<List<ChatConversation>> loadArchivedConversations({String search = ''}) async {
    final response = await _api.getChatConversations(
      accessToken: _accessToken,
      search: search,
      status: 'archived',
      perPage: 50,
    );
    return (response['data'] as List? ?? [])
        .map((row) => ChatConversation.fromApi(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> setConversationStatus(String id, String status) async {
    final response = await _api.setChatConversationStatus(
      conversationId: id,
      accessToken: _accessToken,
      status: status,
    );
    final updated = ChatConversation.fromApi(Map<String, dynamic>.from(response['data'] as Map));

    final existing = conversationById(id);
    if (existing != null) {
      existing.applyFrom(updated);
    } else {
      _conversations.add(updated);
    }
    _safeNotify();
  }

  /// (parcelAssignmentId, contact) -> conversation id, populated the first
  /// time [startDeliveryConversation] actually resolves one over the
  /// network. A rider tapping "Message" again for the exact same delivery
  /// contact — same session, same conversation already known — has no
  /// reason to ask the server "does this exist?" a second time; the
  /// backend call, and the loading state that comes with waiting on it,
  /// is skipped entirely on that path (see [startDeliveryConversation]).
  final Map<String, String> _deliveryConversationCache = {};

  static String _deliveryConversationCacheKey(String parcelAssignmentId, String contact) => '$parcelAssignmentId:$contact';

  /// The "Message" button next to the call icon on a delivery's Buyer/
  /// Seller contact row (assigned_delivery_detail_screen.dart) — finds or
  /// creates this rider's direct thread with that contact. [contact] is
  /// 'buyer' or 'seller'.
  ///
  /// Cache-first: if this exact (delivery, contact) pairing was already
  /// resolved earlier in this session, the conversation (and its messages)
  /// are almost certainly still sitting in [conversations]/[messagesFor]
  /// from that first resolution — this returns straight from there with no
  /// network call at all, which is what makes a repeat tap instant instead
  /// of re-running the whole create-or-find round trip.
  ///
  /// On an actual first resolution, the server response already carries
  /// the thread's latest messages (see Driver\MessageController::
  /// startDeliveryConversation() on the Laravel side) — folded straight
  /// into [messagesFor] here — so the caller can open straight into a
  /// populated conversation without the extra openConversation() round
  /// trip a normal inbox-row tap would still make.
  Future<ChatConversation> startDeliveryConversation({required String parcelAssignmentId, required String contact}) async {
    final cacheKey = _deliveryConversationCacheKey(parcelAssignmentId, contact);
    final cachedId = _deliveryConversationCache[cacheKey];
    if (cachedId != null) {
      final cached = conversationById(cachedId);
      if (cached != null) return cached;
      // Fell out of `_conversations` somehow (shouldn't normally happen —
      // conversations are never removed from this list once loaded) —
      // fall through and re-resolve properly rather than returning stale data.
    }

    final response = await _api.startDeliveryConversation(
      accessToken: _accessToken,
      parcelAssignmentId: parcelAssignmentId,
      contact: contact,
    );
    final conversation = ChatConversation.fromApi(Map<String, dynamic>.from(response['data'] as Map));
    _deliveryConversationCache[cacheKey] = conversation.id;

    final existing = conversationById(conversation.id);
    if (existing != null) {
      existing.applyFrom(conversation);
    } else {
      _conversations.add(conversation);
    }

    // Populate the message cache straight from this same response instead
    // of leaving it empty for the caller's openConversation() to then fetch
    // separately — an empty existing cache is exactly what makes
    // openConversation() show its loading skeleton, so filling it here is
    // what lets the conversation screen open already-populated.
    final messagesJson = response['messages'] as List?;
    if (messagesJson != null) {
      final rows = messagesJson.map((row) => _stabilizeMessage(ChatMessage.fromApi(Map<String, dynamic>.from(row as Map)))).toList();
      _messagesByConversation[conversation.id] = rows;
      final meta = Map<String, dynamic>.from(response['meta'] as Map? ?? {});
      _hasMoreOlderByConversation[conversation.id] = meta['hasMore'] == true;
      loadingMessagesFor[conversation.id] = false;
      messagesErrorFor[conversation.id] = null;
    }

    _safeNotify();

    return existing ?? conversation;
  }

  // ---- Poll lifecycle ----

  void setInboxActive(bool active) {
    if (_inboxActive == active) return;
    _inboxActive = active;
    _syncMetaPolling();
  }

  void setAppVisible(bool visible) {
    if (_appVisible == visible) return;
    _appVisible = visible;
    _syncMetaPolling();
    _syncMessagePolling();
  }

  void _syncMetaPolling() {
    final shouldPoll = _inboxActive && _appVisible;
    if (shouldPoll && _metaPollTimer == null) {
      _metaPollTimer = Timer.periodic(_metaPollInterval, (_) => _refreshConversationsSilently());
    } else if (!shouldPoll && _metaPollTimer != null) {
      _metaPollTimer?.cancel();
      _metaPollTimer = null;
    }
  }

  void _syncMessagePolling() {
    final id = _activeConversationId;
    if (id == null) return;
    final shouldPoll = _appVisible;
    if (shouldPoll && _messagePollTimer == null) {
      _messagePollTimer = Timer.periodic(_messagePollInterval, (_) => _pollNewMessages(id));
    } else if (!shouldPoll && _messagePollTimer != null) {
      _messagePollTimer?.cancel();
      _messagePollTimer = null;
    }
  }

  // ---- Conversation (message thread) lifecycle ----

  /// Cached-then-refresh: if messages for [id] are already cached, they're
  /// returned instantly via [messagesFor] (the conversation screen renders
  /// them before this even resolves) while this quietly reconciles with the
  /// server in the background. Also starts the fast poll for as long as
  /// this thread stays open (stop with [closeConversation]).
  Future<void> openConversation(String id) async {
    _activeConversationId = id;
    _syncMessagePolling();

    final cached = _messagesByConversation[id];
    final hadCache = cached != null && cached.isNotEmpty;
    if (!hadCache) {
      loadingMessagesFor[id] = true;
      messagesErrorFor[id] = null;
      _safeNotify();
    }

    // Fetch conversation detail and messages independently instead of two
    // sequential awaits — the detail call (marks read server-side, richer
    // metadata) is structurally slower than the messages call, and text
    // should render the moment messages() resolves instead of waiting on
    // detail first (detail's own metadata, for any conversation already in
    // the inbox list, is usually already known from that list anyway).
    // Mirrors the identical fix applied to the web app's
    // useBuyerChat.js/useMessaging.js openConversation().
    await Future.wait([
      _openConversationMessages(id, hadCache),
      _openConversationDetail(id),
    ]);
  }

  Future<void> _openConversationMessages(String id, bool hadCache) async {
    try {
      final messagesResponse = await _api.getChatMessages(conversationId: id, accessToken: _accessToken);
      if (_activeConversationId != id) return;
      final rows = (messagesResponse['data'] as List? ?? [])
          .map((row) => _stabilizeMessage(ChatMessage.fromApi(Map<String, dynamic>.from(row as Map))))
          .toList();
      final meta = Map<String, dynamic>.from(messagesResponse['meta'] as Map? ?? {});

      _messagesByConversation[id] = rows;
      _hasMoreOlderByConversation[id] = meta['hasMore'] == true;
      loadingMessagesFor[id] = false;
      messagesErrorFor[id] = null;
    } on ApiException catch (e) {
      if (_activeConversationId != id) return;
      loadingMessagesFor[id] = false;
      if (!hadCache) messagesErrorFor[id] = e.message;
    } catch (_) {
      if (_activeConversationId != id) return;
      loadingMessagesFor[id] = false;
      if (!hadCache) {
        messagesErrorFor[id] = 'Could not reach the server. Check your connection and try again.';
      }
    }
    _safeNotify();
  }

  Future<void> _openConversationDetail(String id) async {
    try {
      final response = await _api.getChatConversation(id: id, accessToken: _accessToken);
      if (_activeConversationId != id) return;
      final fresh = ChatConversation.fromApi(Map<String, dynamic>.from(response['data'] as Map));
      final existing = conversationById(id);
      existing?.applyFrom(fresh);
      existing?.unreadCount = 0;
    } catch (_) {
      // Background metadata refresh — a transient miss leaves whatever
      // metadata is already showing (from the inbox list) as-is.
    }
    _safeNotify();
  }

  void closeConversation() {
    _activeConversationId = null;
    _messagePollTimer?.cancel();
    _messagePollTimer = null;
  }

  Future<void> _pollNewMessages(String id) async {
    final cached = _messagesByConversation[id];
    final newestId = (cached == null || cached.isEmpty) ? null : cached.last.id;

    try {
      final response = await _api.getChatMessages(
        conversationId: id,
        accessToken: _accessToken,
        after: newestId,
      );
      final rows = (response['data'] as List? ?? [])
          .map((row) => _stabilizeMessage(ChatMessage.fromApi(Map<String, dynamic>.from(row as Map))))
          .toList();
      if (rows.isEmpty) return;

      final existing = _messagesByConversation[id] ?? [];
      final existingIds = existing.map((m) => m.id).toSet();
      final toAppend = rows.where((m) => !existingIds.contains(m.id)).toList();
      if (toAppend.isEmpty) return;
      _messagesByConversation[id] = [...existing, ...toAppend];
      messagesAppendedTick[id] = (messagesAppendedTick[id] ?? 0) + 1;

      // A reply arrived while this thread is open — mark it read locally
      // (the next full openConversation()/inbox refresh reconciles with
      // the server's own read receipt, set when GET .../conversations/{id}
      // is called again).
      final conversation = conversationById(id);
      if (conversation != null) conversation.unreadCount = 0;

      _safeNotify();
    } catch (_) {
      // Silent — next tick retries.
    }
  }

  Future<void> loadOlderMessages(String id) async {
    if (loadingMessagesFor[id] == true || hasMoreOlder(id) == false) return;
    final cached = _messagesByConversation[id] ?? [];
    if (cached.isEmpty) return;

    loadingMessagesFor[id] = true;
    _safeNotify();

    try {
      final response = await _api.getChatMessages(
        conversationId: id,
        accessToken: _accessToken,
        before: cached.first.id,
      );
      final rows = (response['data'] as List? ?? [])
          .map((row) => _stabilizeMessage(ChatMessage.fromApi(Map<String, dynamic>.from(row as Map))))
          .toList();
      final meta = Map<String, dynamic>.from(response['meta'] as Map? ?? {});

      _messagesByConversation[id] = [...rows, ...cached];
      _hasMoreOlderByConversation[id] = meta['hasMore'] == true;
    } catch (_) {
      // Leave hasMoreOlder as-is — the "load more" affordance just retries.
    }
    loadingMessagesFor[id] = false;
    _safeNotify();
  }

  /// Optimistic send: the bubble appears immediately with
  /// [MessageStatus.sending], is swapped for the server's real message on
  /// success, or flipped to [MessageStatus.failed] (with a Retry action) on
  /// failure — never silently dropped and never duplicated once the
  /// confirmed copy lands, since it replaces the local one in place rather
  /// than being appended alongside it.
  Future<void> sendMessage(String conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}-${_localIdSequence++}';
    final myRole = _guessOwnSenderRole(conversationId);
    final optimistic = ChatMessage(
      id: localId,
      senderRole: myRole,
      text: trimmed,
      sentAt: DateTime.now(),
      status: MessageStatus.sending,
      localId: localId,
    );

    final list = _messagesByConversation.putIfAbsent(conversationId, () => []);
    list.add(optimistic);
    _safeNotify();

    try {
      final response = await _api.sendChatMessage(
        conversationId: conversationId,
        accessToken: _accessToken,
        body: trimmed,
      );
      final real = _stabilizeMessage(ChatMessage.fromApi(Map<String, dynamic>.from(response['data'] as Map)));
      final index = list.indexWhere((m) => m.localId == localId);
      if (index != -1) {
        list[index] = real;
      } else {
        list.add(real);
      }

      final conversation = conversationById(conversationId);
      if (conversation != null) {
        conversation.lastMessage = trimmed;
        conversation.lastMessageAt = real.sentAt;
        conversation.lastMessageSenderRole = myRole;
      }
    } catch (_) {
      final index = list.indexWhere((m) => m.localId == localId);
      if (index != -1) list[index].status = MessageStatus.failed;
    }
    _safeNotify();
  }

  /// Re-sends a message that previously failed, replacing that same failed
  /// bubble rather than leaving a stale copy behind. Handles both a plain
  /// text retry and an attachment retry (the bytes were kept on the failed
  /// optimistic message precisely so this doesn't need to re-prompt the
  /// rider to re-pick the file).
  Future<void> retryMessage(String conversationId, String localId) async {
    final list = _messagesByConversation[conversationId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.localId == localId);
    if (index == -1) return;

    final failed = list[index];
    list.removeAt(index);
    _safeNotify();

    if (failed.attachments.isNotEmpty) {
      final files = failed.attachments
          .where((a) => a.localBytes != null)
          .map((a) => PendingAttachment(bytes: a.localBytes!, fileName: a.fileName ?? 'file', mimeType: a.mimeType ?? 'application/octet-stream'))
          .toList();
      await sendAttachments(conversationId, files);
    } else {
      await sendMessage(conversationId, failed.text);
    }
  }

  /// Optimistic multi-attachment send: every picked file (gallery multi-select
  /// or a single camera capture) becomes one message with several
  /// attachments, exactly like the web composer — shows each file's local
  /// bytes immediately via [ChatAttachment.localBytes] while they upload one
  /// by one in the background, then sends them all as a single message once
  /// every one is staged. Mirrors [sendMessage]'s sending/sent/failed
  /// lifecycle so the same [ChatBubble] handles both.
  Future<void> sendAttachments(String conversationId, List<PendingAttachment> files) async {
    if (files.isEmpty) return;

    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}-${_localIdSequence++}';
    final myRole = _guessOwnSenderRole(conversationId);
    final optimistic = ChatMessage(
      id: localId,
      senderRole: myRole,
      text: '',
      sentAt: DateTime.now(),
      status: MessageStatus.sending,
      localId: localId,
      attachments: [
        for (final f in files)
          ChatAttachment(id: 'local-${f.fileName}', url: '', fileName: f.fileName, mimeType: f.mimeType, localBytes: f.bytes),
      ],
    );

    final list = _messagesByConversation.putIfAbsent(conversationId, () => []);
    list.add(optimistic);
    _safeNotify();

    try {
      final attachmentIds = <String>[];
      for (final f in files) {
        attachmentIds.add(await uploadAttachment(fileName: f.fileName, bytes: f.bytes));
      }
      final response = await _api.sendChatMessage(
        conversationId: conversationId,
        accessToken: _accessToken,
        attachmentIds: attachmentIds,
      );
      final real = _stabilizeMessage(ChatMessage.fromApi(Map<String, dynamic>.from(response['data'] as Map)));
      final index = list.indexWhere((m) => m.localId == localId);
      if (index != -1) {
        list[index] = real;
      } else {
        list.add(real);
      }

      final conversation = conversationById(conversationId);
      if (conversation != null) {
        conversation.lastMessage = files.length == 1 ? 'Sent an attachment' : 'Sent attachments';
        conversation.lastMessageAt = real.sentAt;
        conversation.lastMessageSenderRole = myRole;
      }
    } catch (_) {
      final index = list.indexWhere((m) => m.localId == localId);
      if (index != -1) list[index].status = MessageStatus.failed;
    }
    _safeNotify();
  }

  /// Stages a file for the currently-composed message.
  Future<String> uploadAttachment({required String fileName, Uint8List? bytes, String? filePath}) async {
    final response = await _api.uploadChatAttachment(
      accessToken: _accessToken,
      fileName: fileName,
      bytes: bytes,
      filePath: filePath,
    );
    return (Map<String, dynamic>.from(response['data'] as Map)['id'] ?? '').toString();
  }

  String _guessOwnSenderRole(String conversationId) {
    // Any prior message actually sent as 'driver'/'courier' tells us our
    // own exact role string without a separate lookup — checking for that
    // directly (rather than "not the counterparty's role") is what keeps
    // this from misreading a buyer/seller's own reply in a 'delivery'
    // thread as if it were this rider's role. Falls back to 'courier' (a
    // harmless default for optimistic-only display, corrected the instant
    // the real server response replaces it) if this is the very first
    // message in the thread.
    final existing = _messagesByConversation[conversationId] ?? const [];
    for (final m in existing.reversed) {
      if ((m.senderRole == 'driver' || m.senderRole == 'courier') && m.status == MessageStatus.sent) return m.senderRole;
    }
    return 'courier';
  }

  /// Every async method above calls this instead of `notifyListeners()`
  /// directly — an in-flight request (a poll tick, a send, a hot-restart's
  /// stray leftover call from the previous generation) can resolve after
  /// this controller is already disposed, and ChangeNotifier asserts hard
  /// on a post-dispose notify instead of just no-op'ing.
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    _metaPollTimer?.cancel();
    _messagePollTimer?.cancel();
    super.dispose();
  }
}
