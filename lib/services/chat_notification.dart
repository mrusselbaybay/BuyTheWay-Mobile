import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

/// Draws an Android chat notification with the sender's photo as a round
/// avatar (the system can only show the app logo for pushes it draws itself,
/// which is why chat pushes arrive data-only). Runs in the app's isolate while
/// it is open and in the background-message isolate when it is closed, so it
/// must not touch any app state.
///
/// Edge cases it absorbs: no photo, a photo that is slow / huge / not an image
/// / not https (an initials circle is drawn instead), empty sender or body.
/// [show] never throws: a missing avatar must never cost the user the message.
class ChatNotification {
  ChatNotification._();

  static const channelId = 'messages';

  static const _avatarPx = 192;
  static const _maxDownloadBytes = 3 * 1024 * 1024;
  static const _downloadTimeout = Duration(seconds: 5);
  static const _avatarBudget = Duration(seconds: 8);
  static const _brand = Color(0xFF14B8A6);

  /// One tray entry per chat: a newer message from the same conversation replaces the older.
  static Future<void> show(FlutterLocalNotificationsPlugin plugin, Map<String, dynamic> data) async {
    try {
      final name = _clean(data['senderName'] ?? data['title'], fallback: 'New message');
      final body = _clean(data['body'], fallback: 'New message');
      final conversationId = data['conversationId']?.toString();
      // Never let the picture hold up the message: past the cap we show it without one.
      final avatar = await ChatNotification.avatar(data['avatarUrl']?.toString(), name).timeout(
        _avatarBudget,
        onTimeout: () {
          debugPrint('ChatNotification: avatar timed out, showing without it');
          return null;
        },
      );
      debugPrint('ChatNotification: showing "$name" (avatar: ${avatar == null ? 'none' : '${avatar.length} bytes'})');

      final person = Person(
        name: name,
        key: conversationId,
        important: true,
        icon: avatar == null ? null : ByteArrayAndroidIcon(avatar),
      );

      await plugin.show(
        id: 'chat:${conversationId ?? name}'.hashCode & 0x7fffffff,
        title: name,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Messages',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
            largeIcon: avatar == null ? null : ByteArrayAndroidBitmap(avatar),
            styleInformation: MessagingStyleInformation(
              person,
              messages: [Message(body, DateTime.now(), person)],
            ),
          ),
        ),
        payload: jsonEncode(data),
      );
    } catch (e, stack) {
      debugPrint('ChatNotification: rich notification failed: $e\n$stack');
      // Last resort: a plain notification beats none.
      try {
        await plugin.show(
          id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
          title: _clean(data['title'], fallback: 'New message'),
          body: _clean(data['body'], fallback: ''),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(channelId, 'Messages', importance: Importance.high, priority: Priority.high),
          ),
          payload: jsonEncode(data),
        );
      } catch (e) {
        debugPrint('ChatNotification: plain fallback failed too: $e');
      }
    }
  }

  static String _clean(Object? value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  /// The sender's photo as a small round PNG, or an initials circle when there is none / it fails.
  @visibleForTesting
  static Future<Uint8List?> avatar(String? url, String name) async {
    if (url != null && url.startsWith('https://')) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(_downloadTimeout);
        final bytes = response.bodyBytes;
        if (response.statusCode == 200 && bytes.isNotEmpty && bytes.length <= _maxDownloadBytes) {
          return await roundPhoto(bytes);
        }
      } catch (e) {
        debugPrint('ChatNotification: photo unusable ($e), drawing initials');
      }
    }

    try {
      return await initialsCircle(name);
    } catch (e) {
      debugPrint('ChatNotification: could not draw initials: $e');
      return null;
    }
  }

  /// Centre-cropped, downscaled (never decode a 4000px upload at full size), clipped to a circle.
  @visibleForTesting
  static Future<Uint8List> roundPhoto(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 384);
    final image = (await codec.getNextFrame()).image;

    final side = image.width < image.height ? image.width : image.height;
    final source = Rect.fromLTWH((image.width - side) / 2, (image.height - side) / 2, side.toDouble(), side.toDouble());
    const size = _avatarPx * 1.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    canvas.clipPath(Path()..addOval(const Rect.fromLTWH(0, 0, size, size)));
    canvas.drawImageRect(image, source, const Rect.fromLTWH(0, 0, size, size), Paint()..filterQuality = FilterQuality.high);

    return _png(recorder);
  }

  @visibleForTesting
  static Future<Uint8List> initialsCircle(String name) async {
    const size = _avatarPx * 1.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, Paint()..color = _brand);

    final text = TextPainter(
      text: TextSpan(
        text: initials(name),
        style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 84, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset((size - text.width) / 2, (size - text.height) / 2));

    return _png(recorder);
  }

  static Future<Uint8List> _png(ui.PictureRecorder recorder) async {
    final image = await recorder.endRecording().toImage(_avatarPx, _avatarPx);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Up to two letters, safe for emoji and non-Latin names (works on code points, not UTF-16 units).
  @visibleForTesting
  static String initials(String name) {
    final letters = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => String.fromCharCode(word.runes.first))
        .join()
        .toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }
}
