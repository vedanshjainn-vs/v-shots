// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Firebase Cloud Messaging Service
// ═════════════════════════════════════════════════════════════════════════════
//
// Handles push notifications via Firebase Cloud Messaging (FCM).
// Uses Firebase free tier (1M messages/month).
//
// Responsibilities:
// - FCM token management
// - Background message handling
// - Foreground message display
// - Token sync with backend
// - Deep link routing from notifications

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../backend/supabase_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages here
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class FirebaseMessagingService {
  FirebaseMessagingService._();
  static final FirebaseMessagingService instance = FirebaseMessagingService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[FCM] User granted permission');
      } else {
        debugPrint('[FCM] User declined or has not accepted permission');
        return;
      }

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Get initial token
      final token = await _messaging.getToken();
      debugPrint('[FCM] Token: $token');

      if (token != null) {
        await _syncTokenWithBackend(token);
      }

      // Listen for token refresh
      _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
        debugPrint('[FCM] Token refreshed: $token');
        await _syncTokenWithBackend(token);
      });

      // Handle foreground messages
      _messageSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );

      // Handle notification taps (when app is in background/terminated)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      _initialized = true;
      debugPrint('[FCM] Initialized');
    } catch (e) {
      debugPrint('[FCM] Initialization failed: $e');
    }
  }

  Future<void> _syncTokenWithBackend(String token) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;

      // Store token in Supabase
      await SupabaseService.client.from('user_devices').upsert({
        'user_id': user.id,
        'fcm_token': token,
        'platform': 'android',
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('[FCM] Token synced with backend');
    } catch (e) {
      debugPrint('[FCM] Token sync failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message: ${message.messageId}');

    // Show local notification for foreground messages
    if (message.notification != null) {
      final notification = message.notification!;
      final data = message.data;

      NotificationService.instance.showSmartNotification(
        id: message.hashCode,
        title: notification.title ?? 'V Shots',
        body: notification.body ?? '',
        payload: data['payload']?.toString() ?? '',
        channelId: _getChannelIdForType(data['type']?.toString()),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped: ${message.messageId}');

    final data = message.data;
    final payload = data['payload'] ?? '';

    // Route to appropriate screen
    // Format: "type:id" (e.g., "song:123", "artist:456")
    debugPrint('[FCM] Navigate to: $payload');
  }

  String _getChannelIdForType(String? type) {
    switch (type) {
      case 'new_music':
        return NotificationService.channelNewMusic;
      case 'recommendation':
        return NotificationService.channelRecommendations;
      case 'update':
        return NotificationService.channelUpdates;
      default:
        return NotificationService.channelRecommendations;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      debugPrint('[FCM] Token deleted');
    } catch (e) {
      debugPrint('[FCM] Token deletion failed: $e');
    }
  }

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }
}
