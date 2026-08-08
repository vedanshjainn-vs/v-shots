// ════════════════════════════════════════════════
// Project Lyra — Notification Service
// ════════════════════════════════════════════════
//
// Abstraction over Firebase Cloud Messaging.
// Handles push notifications, local notifications,
// and notification permissions.
// ════════════════════════════════════════════════

import 'notification_payload.dart';

/// Notification service interface.
abstract class NotificationService {
  /// Request notification permission.
  Future<bool> requestPermission();

  /// Get the FCM token for this device.
  Future<String?> getToken();

  /// Subscribe to a topic (e.g., "new-releases").
  Future<void> subscribeToTopic(String topic);

  /// Unsubscribe from a topic.
  Future<void> unsubscribeFromTopic(String topic);

  /// Initialize notification handlers.
  Future<void> initialize();

  /// Set the foreground notification presentation options.
  Future<void> setForegroundPresentationOptions({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  });

  /// Handle a notification tap.
  void onNotificationTapped(NotificationPayload payload);

  /// Register a callback for foreground messages.
  void onForegroundMessage(void Function(Map<String, dynamic> data) handler);

  /// Register a callback for background messages.
  void onBackgroundMessage(void Function(Map<String, dynamic> data) handler);

  /// Clear all notifications.
  Future<void> clearAll();
}
