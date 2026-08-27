// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Notification Service
// ═════════════════════════════════════════════════════════════════════════════
//
// Manages all local notifications:
// - App update reminders
// - Smart engagement notifications
// - Notification permission handling
// - Notification channel management
//
// Uses flutter_local_notifications for local scheduling (free, no backend).
// FCM integration is separate (see firebase_messaging_service.dart).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Notification channel IDs
  static const String channelMusicPlayer = 'vshots_music_player';
  static const String channelUpdates = 'vshots_updates';
  static const String channelRecommendations = 'vshots_recommendations';
  static const String channelNewMusic = 'vshots_new_music';

  // SharedPreferences keys
  static const String keyUpdateDismissed = 'update_dismissed_v';
  static const String keyUpdateReminderDate = 'update_reminder_date';
  static const String keyNotifPermissionRequested =
      'notif_permission_requested';

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _createNotificationChannels();

    _initialized = true;
    debugPrint('[NotificationService] Initialized');
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = AndroidFlutterLocalNotificationsPlugin();

    // Music player channel (for media notifications)
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        channelMusicPlayer,
        'V Shots Music Player',
        description: 'Media playback controls',
        importance: Importance.high,
        showBadge: false,
      ),
    );

    // Updates channel
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        channelUpdates,
        'V Shots Updates',
        description: 'App update notifications',
        importance: Importance.defaultImportance,
      ),
    );

    // Recommendations channel
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        channelRecommendations,
        'V Shots Recommendations',
        description: 'Personalized music recommendations',
        importance: Importance.low,
      ),
    );

    // New music channel
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        channelNewMusic,
        'V Shots New Music',
        description: 'New music releases',
        importance: Importance.low,
      ),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    debugPrint('[NotificationService] Tapped: $payload');

    // Parse payload and navigate
    // Format: "type:id" (e.g., "song:123", "artist:456", "update:")
    final parts = payload.split(':');
    if (parts.length < 2) return;

    final type = parts[0];
    final id = parts[1];

    // Dispatch to navigation handler
    // (This will be wired to the app's navigation system)
    debugPrint('[NotificationService] Navigate to $type/$id');
  }

  // ── App Update Notifications ──────────────────────────────────────────

  Future<void> showUpdateNotification(String versionName) async {
    const androidDetails = AndroidNotificationDetails(
      channelUpdates,
      'V Shots Updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      1001, // Fixed ID for update notification
      'Vshots Update Available 🎵',
      'Update to v$versionName for the latest features and improvements.',
      details,
      payload: 'update:',
    );
  }

  Future<void> cancelUpdateNotification() async {
    await _plugin.cancel(1001);
  }

  // ── Smart Notification Helpers ────────────────────────────────────────

  Future<void> showSmartNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
    String channelId = channelRecommendations,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelRecommendations,
      'V Shots Recommendations',
      importance: Importance.defaultImportance,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(id, title, body, details, payload: payload);
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  // ── Permission Handling ───────────────────────────────────────────────

  Future<bool> requestNotificationPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return true; // Non-Android or already granted

    final granted = await androidPlugin.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<bool> hasNotificationPermission() async {
    // Simplified check - actual permission is requested via FCM
    // For local notifications, we assume permission if FCM is authorized
    return true;
  }

  // ── Update Reminder Logic ─────────────────────────────────────────────

  Future<void> saveUpdateDismissed(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyUpdateDismissed, version);
    await prefs.setString(
      keyUpdateReminderDate,
      DateTime.now().toIso8601String(),
    );
  }

  Future<bool> shouldShowUpdateReminder(String currentVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedVersion = prefs.getString(keyUpdateDismissed);
    final reminderDateStr = prefs.getString(keyUpdateReminderDate);

    // If version changed, show update
    if (dismissedVersion != currentVersion) return true;

    // Check if enough time has passed (3 days)
    if (reminderDateStr != null) {
      final reminderDate = DateTime.parse(reminderDateStr);
      final daysSince = DateTime.now().difference(reminderDate).inDays;
      return daysSince >= 3;
    }

    return true;
  }
}
