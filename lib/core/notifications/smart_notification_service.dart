// ════════════════════════════════════════════════════════════════════════════
// V Shots — Smart Notification Service
// ════════════════════════════════════════════════════════════════════════════
//
// Schedules local notifications based on user activity patterns.
// Sends personalized notifications at optimal times.
//
// Notification types:
// - New music releases
// - Trending songs
// - Personalized recommendations
// - Continue listening reminders
// - Win-back notifications (inactive users)

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/local_library.dart';
import 'notification_service.dart';

class SmartNotificationService {
  SmartNotificationService._();
  static final SmartNotificationService instance = SmartNotificationService._();

  bool _initialized = false;
  Timer? _scheduledTimer;

  // SharedPreferences keys
  static const String keyLastNotificationTime = 'last_smart_notification_time';
  static const String keyNotificationCount = 'smart_notification_count';
  static const String keyUserActiveHours = 'user_active_hours';

  // Notification frequency limits
  static const int maxNotificationsPerDay = 3;
  static const int minHoursBetweenNotifications = 4;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('[SmartNotif] Initialized');

    // Schedule first notification after a delay
    _scheduleNextNotification();
  }

  void _scheduleNextNotification() {
    // Cancel any existing timer
    _scheduledTimer?.cancel();

    // Schedule next notification in 4-8 hours
    final hours = 4 + Random().nextInt(5); // 4-8 hours
    _scheduledTimer = Timer(Duration(hours: hours), () async {
      await _sendSmartNotification();
      _scheduleNextNotification(); // Schedule next one
    });

    debugPrint('[SmartNotif] Next notification in $hours hours');
  }

  Future<void> _sendSmartNotification() async {
    // Check frequency limits
    if (!await _canSendNotification()) {
      debugPrint('[SmartNotif] Cannot send: frequency limit reached');
      return;
    }

    // Get notification type based on user activity
    final notification = await _generateSmartNotification();
    if (notification == null) return;

    // Send notification
    await NotificationService.instance.showSmartNotification(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      payload: notification.payload,
      channelId: NotificationService.channelRecommendations,
    );

    // Update tracking
    await _updateNotificationTracking();

    debugPrint('[SmartNotif] Sent: ${notification.title}');
  }

  Future<bool> _canSendNotification() async {
    final prefs = await SharedPreferences.getInstance();

    // Check daily count
    final count = prefs.getInt(keyNotificationCount) ?? 0;
    final lastTime = prefs.getString(keyLastNotificationTime);

    if (count >= maxNotificationsPerDay) {
      // Reset count if it's a new day
      if (lastTime != null) {
        final last = DateTime.parse(lastTime);
        final now = DateTime.now();
        if (now.day != last.day) {
          await prefs.setInt(keyNotificationCount, 0);
        } else {
          return false; // Daily limit reached
        }
      }
    }

    // Check minimum hours between notifications
    if (lastTime != null) {
      final last = DateTime.parse(lastTime);
      final hoursSince = DateTime.now().difference(last).inHours;
      if (hoursSince < minHoursBetweenNotifications) {
        return false; // Too soon
      }
    }

    return true;
  }

  Future<_SmartNotification?> _generateSmartNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final recentlyPlayed = LocalLibrary.instance.recentlyPlayed.value;

    // Different notification types based on user activity
    final rand = Random();
    final type = rand.nextInt(4);

    switch (type) {
      case 0: // Continue listening
        if (recentlyPlayed.isEmpty) return null;
        final track = recentlyPlayed[rand.nextInt(recentlyPlayed.length)];
        return _SmartNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Continue listening 🎵',
          body:
              'Pick up where you left off with ${track['title'] ?? 'your music'}',
          payload: 'song:${track['id'] ?? ''}',
        );

      case 1: // New music
        return _SmartNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'New music just dropped 🎶',
          body: 'Discover fresh tracks waiting for you on V Shots',
          payload: 'trending:',
        );

      case 2: // Trending
        return _SmartNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Trending right now 🔥',
          body: 'These songs are getting everyone hooked',
          payload: 'trending:',
        );

      case 3: // Win-back (if inactive)
        final lastActive = prefs.getString('last_active_at');
        if (lastActive != null) {
          final last = DateTime.parse(lastActive);
          final daysInactive = DateTime.now().difference(last).inDays;
          if (daysInactive >= 2) {
            return _SmartNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: 'Your music is waiting ',
              body: 'Come back and discover something new',
              payload: 'recommendation:',
            );
          }
        }
        return null;

      default:
        return null;
    }
  }

  Future<void> _updateNotificationTracking() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(keyNotificationCount) ?? 0;

    await prefs.setInt(keyNotificationCount, count + 1);
    await prefs.setString(
      keyLastNotificationTime,
      DateTime.now().toIso8601String(),
    );
  }

  void dispose() {
    _scheduledTimer?.cancel();
  }
}

class _SmartNotification {
  final int id;
  final String title;
  final String body;
  final String payload;

  _SmartNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });
}
