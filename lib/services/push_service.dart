import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'chat_notification.dart';

/// Where a tapped push should land. Shells watch [PushService.pendingTap].
class PushTap {
  const PushTap({required this.kind, this.conversationId, this.notificationId});

  /// 'message' (open chat) or 'notification' (open the bell inbox).
  final String kind;
  final String? conversationId;
  final String? notificationId;

  bool get isMessage => kind == 'message';

  factory PushTap.fromData(Map<String, dynamic> data) => PushTap(
        kind: data['kind']?.toString() == 'message' ? 'message' : 'notification',
        conversationId: data['conversationId']?.toString(),
        notificationId: data['notificationId']?.toString(),
      );
}

/// Runs in its own isolate when a push arrives with the app in the background or
/// killed. Pushes with a `notification` block are drawn by the system itself. Chat
/// pushes are data-only (so we can show the sender's photo) and are drawn here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    ui.DartPluginRegistrant.ensureInitialized();
    await Firebase.initializeApp();

    if (message.notification == null && message.data['kind'] == 'message') {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      await ChatNotification.show(plugin, message.data);
    }
  } catch (_) {}
}

/// Push notifications for every role in the app (buyer, driver/courier,
/// logistics). The server decides who gets what; this class only:
///  - asks for permission and registers this phone's FCM token for whoever is
///    signed in ([register]) and removes it on sign-out ([unregister]);
///  - shows pushes that arrive while the app is open (the system only draws
///    them itself when the app is closed or in the background);
///  - turns a tap into a [PushTap] for the shell to navigate on.
///
/// Push is a bonus: every method swallows its own errors, and the app works
/// exactly as before if Firebase isn't set up (e.g. iOS has no config yet).
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  static const _channelMessages = 'messages';
  static const _channelNotifications = 'notifications';
  static const _tokenPrefKey = 'push_fcm_token';

  final ValueNotifier<PushTap?> pendingTap = ValueNotifier<PushTap?>(null);

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void>? _initFuture;

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Call once from main() (don't await it: startup must not wait on Firebase).
  /// register()/unregister() wait for it. Never throws.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    if (!_supported) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (response) => _onLocalTap(response.payload),
      );

      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelMessages,
        'Messages',
        description: 'New chat messages',
        importance: Importance.high,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelNotifications,
        'Notifications',
        description: 'Orders, deliveries, account and support updates',
        importance: Importance.high,
      ));

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => pendingTap.value = PushTap.fromData(m.data));
      // The classic registration token is what the server's FCM HTTP v1 sender targets. v17 deprecates
      // getToken/onTokenRefresh in favour of Installation IDs, which we haven't verified against v1 sends.
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen((token) => unawaited(_registerToken(token)));

      // Cold start: the app was launched by tapping a push (system-drawn one, or one we drew).
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) pendingTap.value = PushTap.fromData(initial.data);
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) _onLocalTap(launch!.notificationResponse?.payload);

      _ready = true;
    } catch (e) {
      debugPrint('Push unavailable: $e');
    }
  }

  /// Ask permission (Android 13+/iOS) and register this phone for the signed-in user.
  /// Safe to call on every launch; the server treats it as idempotent.
  Future<void> register(String? authToken) async {
    await _initFuture;
    if (!_ready || authToken == null || authToken.isEmpty) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // iOS only hands out an FCM token once Apple has issued the APNs token (a few seconds after
      // permission is granted). Without it getToken() fails, so wait briefly. The iOS simulator
      // never gets one, so there we simply skip push instead of failing.
      if (Platform.isIOS && !await _waitForApnsToken()) return;

      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token, authToken: authToken);
    } catch (e) {
      debugPrint('Push register failed: $e');
    }
  }

  Future<bool> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      if (await FirebaseMessaging.instance.getAPNSToken() != null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// Stop this phone receiving the signed-out user's pushes. Must run BEFORE the session
  /// token is cleared (the server needs it). Capped at 3s so sign-out never hangs.
  Future<void> unregister({String? authToken}) async {
    await _initFuture;
    if (!_ready) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final auth = authToken ?? prefs.getString('auth_token');
      final token = prefs.getString(_tokenPrefKey);
      if (auth == null || token == null) return;

      await prefs.remove(_tokenPrefKey);
      await http
          .delete(
            Uri.parse('${ApiService.baseUrl}/push/devices'),
            headers: _headers(auth),
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Best effort: a stale token is dropped by the server when FCM reports it gone,
      // and re-assigned if someone else signs in on this phone.
    }
  }

  void clearTap() => pendingTap.value = null;

  // ---------------------------------------------------------------- internals

  Future<void> _registerToken(String token, {String? authToken}) async {
    final prefs = await SharedPreferences.getInstance();
    // onTokenRefresh path: only re-register while someone is signed in.
    final auth = authToken ?? prefs.getString('auth_token');
    if (auth == null || auth.isEmpty) return;

    final response = await http
        .post(
          Uri.parse('${ApiService.baseUrl}/push/devices'),
          headers: _headers(auth),
          body: jsonEncode({'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await prefs.setString(_tokenPrefKey, token);
    }
  }

  Map<String, String> _headers(String auth) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $auth',
      };

  /// The system only draws pushes itself when the app is not in the foreground.
  Future<void> _showForeground(RemoteMessage message) async {
    debugPrint('Push: foreground message kind=${message.data['kind']} hasNotificationBlock=${message.notification != null}');
    final notification = message.notification;
    if (notification == null) {
      // Data-only chat push (Android): drawn by us, with the sender's photo.
      if (message.data['kind'] == 'message') await ChatNotification.show(_local, message.data);
      return;
    }

    final isMessage = message.data['kind'] == 'message';
    // One tray entry per chat, like the server's collapse tag.
    final key = isMessage ? 'chat:${message.data['conversationId']}' : (message.messageId ?? '${DateTime.now().microsecondsSinceEpoch}');

    await _local.show(
      id: key.hashCode & 0x7fffffff,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          isMessage ? _channelMessages : _channelNotifications,
          isMessage ? 'Messages' : 'Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onLocalTap(String? payload) {
    try {
      final data = payload == null ? <String, dynamic>{} : (jsonDecode(payload) as Map<String, dynamic>);
      pendingTap.value = PushTap.fromData(data);
    } catch (_) {
      pendingTap.value = const PushTap(kind: 'notification');
    }
  }
}
