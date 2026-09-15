/// Real chat models backing the driver/courier app's Messages tab —
/// GET/POST `/api/driver/messages/*` (Driver\MessageController on the
/// Laravel side). Replaces the old mock ChatThread/ChatMessage in
/// driver_models.dart.
///
/// There is exactly one conversation type here: 'roster' — the rider's
/// thread with the logistics company currently (or previously) employing
/// them. The only two possible senders are this rider (`sender_role`
/// 'driver' or 'courier', matching whichever role this profile actually
/// is) and 'logistics'.
library;

import 'dart:typed_data';

enum MessageStatus { sending, sent, failed }

class ChatAttachment {
  final String id;
  final String url;
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;

  /// Client-only bytes for an optimistic attachment's local preview —
  /// never set on an attachment parsed from the API. Lets a failed
  /// send be retried (and an image thumbnail shown) without re-prompting
  /// the rider to re-pick the file.
  final Uint8List? localBytes;

  const ChatAttachment({
    required this.id,
    required this.url,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
    this.localBytes,
  });

  bool get isImage => (mimeType ?? '').startsWith('image/');

  bool get isVideo => (mimeType ?? '').startsWith('video/');

  // The Laravel side (MessageAttachment::toContractArray()) sends back
  // {id, name, url, mime, size} — matching those exact keys (not
  // 'mime_type'/'type') is what lets isImage/isVideo actually recognize the
  // attachment instead of silently falling back to a plain file-name chip.
  factory ChatAttachment.fromApi(Map<String, dynamic> json) => ChatAttachment(
        id: (json['id'] ?? '').toString(),
        url: (json['url'] ?? '').toString(),
        fileName: json['name']?.toString() ?? json['file_name']?.toString(),
        mimeType: json['mime']?.toString() ?? json['mime_type']?.toString() ?? json['type']?.toString(),
        sizeBytes: json['size'] is int ? json['size'] as int : int.tryParse('${json['size'] ?? json['size_bytes'] ?? ''}'),
      );
}

/// The order a message's "Inquire about a certain parcel" card points at
/// (Order::messagePreview() on the Laravel side) — item count/total/a
/// thumbnail, enough to render a self-contained card without a follow-up
/// request.
class MessageOrderContext {
  final String id;
  final String orderNumber;
  final int itemCount;
  final double total;
  final String? previewName;
  final String? previewImage;

  const MessageOrderContext({
    required this.id,
    required this.orderNumber,
    required this.itemCount,
    required this.total,
    this.previewName,
    this.previewImage,
  });

  factory MessageOrderContext.fromApi(Map<String, dynamic> json) => MessageOrderContext(
        id: (json['id'] ?? '').toString(),
        orderNumber: (json['orderNumber'] ?? '').toString(),
        itemCount: (json['itemCount'] as num? ?? 0).toInt(),
        total: (json['total'] as num? ?? 0).toDouble(),
        previewName: json['previewName']?.toString(),
        previewImage: json['previewImage']?.toString(),
      );
}

/// The specific product (if any) a message's inquiry card names — the same
/// message can carry a productContext alongside its orderContext (the
/// buyer picked one line item out of a multi-item order).
class MessageProductContext {
  final String id;
  final String name;
  final double price;
  final String? image;
  final int? quantity;
  final String? trackingNumber;

  const MessageProductContext({
    required this.id,
    required this.name,
    required this.price,
    this.image,
    this.quantity,
    this.trackingNumber,
  });

  factory MessageProductContext.fromApi(Map<String, dynamic> json) => MessageProductContext(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        price: (json['price'] as num? ?? 0).toDouble(),
        image: json['image']?.toString(),
        quantity: (json['quantity'] as num?)?.toInt(),
        trackingNumber: json['trackingNumber']?.toString(),
      );
}

class ChatMessage {
  final String id;
  final String senderRole; // 'logistics' | 'driver' | 'courier' | 'buyer' | 'seller'
  /// 'text' | 'attachment' | 'inquiry' | 'system' — an 'inquiry' message
  /// (the buyer's "Message Courier"/"Inquire about a certain parcel" card)
  /// has no body text at all, only [orderContext]/[productContext].
  final String? type;
  final String text;
  final List<ChatAttachment> attachments;
  final MessageOrderContext? orderContext;
  final MessageProductContext? productContext;
  final DateTime sentAt;
  final DateTime? readAt;

  /// Local-only optimistic-send state — never comes from the API. A
  /// message is [MessageStatus.sent] the instant it's parsed from a real
  /// server response.
  MessageStatus status;

  /// Set only on a still-optimistic (not yet server-confirmed) message, so
  /// a retry/failure can find and replace this exact instance.
  final String? localId;

  ChatMessage({
    required this.id,
    required this.senderRole,
    required this.text,
    required this.sentAt,
    this.type,
    this.attachments = const [],
    this.orderContext,
    this.productContext,
    this.readAt,
    this.status = MessageStatus.sent,
    this.localId,
  });

  /// Whether this rider (not the conversation's counterparty) sent it. A
  /// 'roster' thread's other participant sends as 'logistics'; a
  /// 'delivery' thread's sends as 'buyer' or 'seller' — checking "is this
  /// rider's own role" instead of "isn't 'logistics'" is what keeps a
  /// buyer/seller's own reply from misrendering as if the rider sent it.
  bool get fromDriver => senderRole == 'driver' || senderRole == 'courier';

  /// A pure "Inquire about a certain parcel" card — no typed text, just
  /// whichever order/product it points at. Rendered as one self-contained
  /// card instead of an empty bubble (see ChatBubble).
  bool get isInquiry => text.isEmpty && attachments.isEmpty && (orderContext != null || productContext != null);

  factory ChatMessage.fromApi(Map<String, dynamic> json) => ChatMessage(
        id: (json['id'] ?? '').toString(),
        senderRole: (json['from'] ?? '').toString(),
        type: json['type']?.toString(),
        text: (json['text'] ?? '').toString(),
        attachments: (json['attachments'] as List? ?? [])
            .map((a) => ChatAttachment.fromApi(Map<String, dynamic>.from(a as Map)))
            .toList(),
        orderContext: json['orderContext'] is Map ? MessageOrderContext.fromApi(Map<String, dynamic>.from(json['orderContext'] as Map)) : null,
        productContext: json['productContext'] is Map ? MessageProductContext.fromApi(Map<String, dynamic>.from(json['productContext'] as Map)) : null,
        sentAt: DateTime.tryParse('${json['at']}')?.toLocal() ?? DateTime.now(),
        readAt: json['read_at'] != null ? DateTime.tryParse('${json['read_at']}')?.toLocal() : null,
        status: MessageStatus.sent,
      );
}

/// A file picked (gallery or camera) and awaiting upload — carries its own
/// bytes/mimeType so [DriverChatController.sendAttachments] doesn't need to
/// re-touch the picker, and so a failed send can be retried from the same
/// bytes.
class PendingAttachment {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  const PendingAttachment({required this.bytes, required this.fileName, required this.mimeType});

  bool get isVideo => AttachmentPolicy.videoTypes.contains(mimeType);

  /// Same allow-list/size check the server (`UploadMessageAttachmentRequest`)
  /// enforces, and the same one the web composer already runs before
  /// upload (`useMessaging.js`'s `validateAttachment`) — checked client-side
  /// too so a rejected file fails instantly with a clear reason instead of
  /// spending the upload round-trip only to be bounced by the server.
  String? validate() {
    if (!AttachmentPolicy.allowedTypes.contains(mimeType)) {
      return 'Only photos, videos, or PDF files can be attached.';
    }
    final maxBytes = isVideo ? AttachmentPolicy.maxVideoBytes : AttachmentPolicy.maxFileBytes;
    if (bytes.length > maxBytes) {
      return isVideo ? 'Videos must be 50MB or smaller.' : 'Files must be 10MB or smaller.';
    }
    return null;
  }
}

/// Mirrors `UploadMessageAttachmentRequest`'s server-side rules (and the web
/// composer's own pre-upload check) so an attachment picked on mobile is
/// validated against the exact same allow-list and size caps.
class AttachmentPolicy {
  AttachmentPolicy._();

  static const videoTypes = {'video/mp4', 'video/webm', 'video/quicktime'};

  static const allowedTypes = {
    'image/png', 'image/jpeg', 'image/webp', 'application/pdf', ...videoTypes,
  };

  static const maxFileBytes = 10 * 1024 * 1024; // 10MB
  static const maxVideoBytes = 50 * 1024 * 1024; // 50MB
}

class ChatConversation {
  final String id;
  /// 'roster' (this rider's employer) or 'delivery' (a specific delivery's
  /// buyer/seller — see [DriverChatController.startDeliveryConversation]).
  final String type;
  final String employerName;
  String? employerAvatarUrl;
  bool employerOnline;
  /// 'logistics' on a 'roster' thread, 'buyer'/'seller' on a 'delivery'
  /// thread — lets the inbox row badge who this thread is actually with,
  /// now that it isn't always an employer.
  final String employerRole;
  String? lastMessage;
  DateTime? lastMessageAt;
  String? lastMessageSenderRole;
  int unreadCount;
  bool archived;
  final bool isCurrentEmployer;
  String status;

  ChatConversation({
    required this.id,
    required this.employerName,
    required this.employerOnline,
    required this.isCurrentEmployer,
    required this.status,
    this.type = 'roster',
    this.employerRole = 'logistics',
    this.employerAvatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderRole,
    this.unreadCount = 0,
    this.archived = false,
  });

  /// Whether it's this rider's turn to reply — the counterparty sent last
  /// and the thread is still open. "Sent by the counterparty" is just "not
  /// sent by this rider" (whose own sender_role is 'driver' or 'courier'),
  /// which holds for a 'logistics' counterparty exactly as much as a
  /// 'buyer'/'seller' one, so this needs no per-type branching.
  bool get needsResponse =>
      status == 'open' && lastMessageSenderRole != null && lastMessageSenderRole != 'driver' && lastMessageSenderRole != 'courier';

  String get avatarInitial {
    final trimmed = employerName.trim();
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  }

  factory ChatConversation.fromApi(Map<String, dynamic> json) {
    final employer = Map<String, dynamic>.from(json['employer'] as Map? ?? {});
    final lastMessageAtRaw = json['last_message_at'];

    return ChatConversation(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'roster').toString(),
      employerName: (employer['name'] ?? 'Logistics Company').toString(),
      employerAvatarUrl: (employer['avatarUrl'] as String?)?.isNotEmpty == true ? employer['avatarUrl'] as String : null,
      employerRole: (employer['role'] ?? 'logistics').toString(),
      employerOnline: employer['online'] == true,
      isCurrentEmployer: json['isCurrentEmployer'] == true,
      status: (json['status'] ?? 'open').toString(),
      lastMessage: json['last_message']?.toString(),
      lastMessageAt: lastMessageAtRaw != null ? DateTime.tryParse('$lastMessageAtRaw')?.toLocal() : null,
      lastMessageSenderRole: json['last_message_sender_role']?.toString(),
      unreadCount: (json['unread'] as num? ?? 0).toInt(),
      archived: json['archived'] == true,
    );
  }

  /// Applies a fresh server copy onto this same instance in place — used by
  /// the poll/refresh path so a conversation row already on screen updates
  /// without losing widget identity (no list-flicker from a full replace).
  void applyFrom(ChatConversation other) {
    employerAvatarUrl = other.employerAvatarUrl;
    employerOnline = other.employerOnline;
    lastMessage = other.lastMessage;
    lastMessageAt = other.lastMessageAt;
    lastMessageSenderRole = other.lastMessageSenderRole;
    unreadCount = other.unreadCount;
    archived = other.archived;
    status = other.status;
  }
}
