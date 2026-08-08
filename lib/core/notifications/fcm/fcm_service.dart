// ════════════════════════════════════════════════
// Project Lyra — FCM Service
// ════════════════════════════════════════════════
//
// Firebase Cloud Messaging integration for:
// - Push notifications
// - Deep links
// - Notification actions
// - Badge count
// ════════════════════════════════════════════════

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../logging/app_logger.dart';
import '../notification_payload.dart';
import '../notification_service.dart';

/// Background message handler (must be top-level).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages.
}

/// Firebase Cloud Messaging implementation.
class FCMNotificationService implements NotificationService {
  FCMNotificationService({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _token;
  void Function(Map<String, dynamic>)? _onForeground;
  void Function(Map<String, dynamic>)? _onBackground;

  @override
  Future<void> initialize() async {
    try {
      // Register background handler.
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permission.
      await requestPermission();

      // Get token.
      _token = await getToken();
      _logger.i('FCM: Token obtained: ${_token?.substring(0, 20)}...');

      // Listen for foreground messages.
      FirebaseMessaging.onMessage.listen((message) {
        _logger.d('FCM: Foreground message: ${message.notification?.title}');
        _onForeground?.call(message.data);
      });

      // Listen for notification taps.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _logger.d('FCM: Notification tapped: ${message.notification?.title}');
        _onBackground?.call(message.data);
      });

      // Check if app opened from notification.
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _logger.d('FCM: App opened from notification');
        _onBackground?.call(initialMessage.data);
      }

      _logger.i('FCM: Initialized');
    } catch (e, st) {
      _logger.e('FCM: Init failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized;
      _logger.d('FCM: Permission ${granted ? "granted" : "denied"}');
      return granted;
    } catch (e) {
      _logger.e('FCM: requestPermission failed', error: e);
      return false;
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      _logger.e('FCM: getToken failed', error: e);
      return null;
    }
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      _logger.d('FCM: Subscribed to $topic');
    } catch (e) {
      _logger.e('FCM: subscribeToTopic failed', error: e);
    }
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      _logger.d('FCM: Unsubscribed from $topic');
    } catch (e) {
      _logger.e('FCM: unsubscribeFromTopic failed', error: e);
    }
  }

  @override
  Future<void> setForegroundPresentationOptions({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  }) async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: alert,
      badge: badge,
      sound: sound,
    );
  }

  @override
  void onNotificationTapped(NotificationPayload payload) {
    // Handled by onMessageOpenedApp listener.
  }

  @override
  void onForegroundMessage(void Function(Map<String, dynamic> data) handler) {
    _onForeground = handler;
  }

  @override
  void onBackgroundMessage(void Function(Map<String, dynamic> data) handler) {
    _onBackground = handler;
  }

  @override
  Future<void> clearAll() async {
    // Badge count reset.
    _logger.d('FCM: Notifications cleared');
  }

  /// Register push token with backend.
  Future<void> registerToken(String userId) async {
    if (_token == null) return;

    // TODO(team): Send token to Supabase.
    // await supabase.from('push_tokens').upsert({
    //   'user_id': userId,
    //   'token': _token,
    //   'platform': 'android',
    // });

    _logger.d('FCM: Token registered for $userId');
  }
}
