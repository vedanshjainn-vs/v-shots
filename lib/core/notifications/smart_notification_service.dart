// ════════════════════════════════════════════════════════════════════════════
// V Shots — Smart Notification Service
// ════════════════════════════════════════════════════════════════════════════
//
// Uses Android system scheduled notifications instead of an in-process Timer.
// This is important because a Dart Timer dies when Android kills the app.
//
// Rules:
//   • 4–8 hours between notifications
//   • maximum 3 smart notifications per calendar day
//   • Continue Listening / New Music / Trending / Win-back
//   • schedules survive app process death and device idle mode
//   • schedules are rebuilt whenever the app starts/returns to foreground
//
// No backend is required for these local engagement notifications.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../storage/local_library.dart';
import 'notification_service.dart';

class SmartNotificationService {
  SmartNotificationService._();
  static final SmartNotificationService instance = SmartNotificationService._();

  static const int maxNotificationsPerDay = 3;
  static const int minHoursBetweenNotifications = 4;
  static const int maxHoursBetweenNotifications = 8;
  static const int daysToScheduleAhead = 7;

  static const int _scheduleIdBase = 20000;
  static const String keyLastNotificationTime = 'last_smart_notification_time';
  static const String keyNotificationCount = 'smart_notification_count';
  static const String keyScheduleVersion = 'smart_notification_schedule_v2';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      tz_data.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.name));
    } catch (e) {
      // Keep timezone package's UTC fallback rather than crashing app startup.
      debugPrint('[SmartNotif] Timezone setup failed: $e');
    }

    await _rebuildSchedule();
    debugPrint('[SmartNotif] Initialized with system scheduling');
  }

  /// Call this when the app becomes active. It records activity so win-back
  /// notifications are not scheduled for an actively returning user.
  Future<void> markAppActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_active_at', DateTime.now().toIso8601String());
    await _rebuildSchedule();
  }

  /// Rebuilds future notifications. This is safe to call repeatedly and is
  /// deliberately idempotent: old smart notifications are cancelled first.
  Future<void> _rebuildSchedule() async {
    if (!_initialized) return;

    final notificationService = NotificationService.instance;
    await notificationService.cancelSmartNotifications();

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastSentRaw = prefs.getString(keyLastNotificationTime);
    final lastSent = lastSentRaw == null ? null : DateTime.tryParse(lastSentRaw);

    // Do not create a notification inside the first four hours after a smart
    // notification was actually delivered.
    var cursor = tz.TZDateTime.now(tz.local).add(const Duration(hours: 4));
    if (lastSent != null) {
      final minNext = lastSent.add(
        const Duration(hours: minHoursBetweenNotifications),
      );
      final minNextTz = tz.TZDateTime.from(minNext, tz.local);
      if (minNextTz.isAfter(cursor)) cursor = minNextTz;
    }

    var id = _scheduleIdBase;
    var dayKey = _calendarKey(cursor);
    var countForDay = 0;
    var scheduledTotal = 0;
    final random = Random();

    while (scheduledTotal < daysToScheduleAhead * maxNotificationsPerDay) {
      final currentDay = _calendarKey(cursor);
      if (currentDay != dayKey) {
        dayKey = currentDay;
        countForDay = 0;
      }

      if (countForDay >= maxNotificationsPerDay) {
        cursor = _startOfNextDay(cursor).add(const Duration(hours: 8));
        continue;
      }

      final notification = await _generateSmartNotification(random, prefs);
      if (notification == null) {
        // No eligible content yet. Re-check on next app activity instead of
        // scheduling a generic/spammy message.
        break;
      }

      final scheduled = cursor;
      if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) break;

      await notificationService.scheduleSmartNotification(
        id: id++,
        title: notification.title,
        body: notification.body,
        payload: notification.payload,
        scheduledDate: scheduled,
      );

      countForDay++;
      scheduledTotal++;

      // Randomized 4–8 hour gap. This guarantees the minimum 4-hour rule.
      cursor = scheduled.add(
        Duration(
          hours: minHoursBetweenNotifications +
              random.nextInt(maxHoursBetweenNotifications -
                  minHoursBetweenNotifications +
                  1),
        ),
      );
    }

    await prefs.setString(keyScheduleVersion, DateTime.now().toIso8601String());
    debugPrint('[SmartNotif] Scheduled $scheduledTotal future notifications');
  }

  Future<_SmartNotification?> _generateSmartNotification(
    Random random,
    SharedPreferences prefs,
  ) async {
    final recentlyPlayed = LocalLibrary.instance.recentlyPlayed.value;
    final lastActiveRaw = prefs.getString('last_active_at');
    final lastActive =
        lastActiveRaw == null ? null : DateTime.tryParse(lastActiveRaw);

    // Win-back has priority once the user has genuinely been away for 2+ days.
    if (lastActive != null && DateTime.now().difference(lastActive).inDays >= 2) {
      return _SmartNotification(
        id: DateTime.now().millisecondsSinceEpoch,
        title: 'Your music is waiting 🎧',
        body: 'Come back and discover something new on V Shots.',
        payload: 'recommendation:',
      );
    }

    // Prefer a real recently-played track whenever available.
    if (recentlyPlayed.isNotEmpty && random.nextBool()) {
      final track = recentlyPlayed[random.nextInt(recentlyPlayed.length)];
      final title = (track['title'] ?? 'your music').toString();
      final id = (track['id'] ?? '').toString();
      return _SmartNotification(
        id: DateTime.now().millisecondsSinceEpoch,
        title: 'Continue listening 🎵',
        body: 'Pick up where you left off with $title.',
        payload: 'song:$id',
      );
    }

    if (random.nextBool()) {
      return _SmartNotification(
        id: DateTime.now().millisecondsSinceEpoch,
        title: 'Trending right now 🔥',
        body: 'See what everyone is listening to on V Shots.',
        payload: 'trending:',
      );
    }

    return _SmartNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: 'New music just dropped 🎶',
      body: 'Fresh tracks are waiting for you on V Shots.',
      payload: 'new_music:',
    );
  }

  String _calendarKey(tz.TZDateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  tz.TZDateTime _startOfNextDay(tz.TZDateTime date) =>
      tz.TZDateTime(tz.local, date.year, date.month, date.day + 1);

  /// Public test hook used by QA/debug builds. Production scheduling never
  /// calls this; it deliberately sends a test notification immediately.
  Future<void> showTestNotification() async {
    await NotificationService.instance.showSmartNotification(
      id: 29999,
      title: 'V Shots notifications are working ✅',
      body: 'Background notification scheduling is active.',
      payload: 'recommendation:',
    );
  }

  void dispose() {
    // No Dart Timer to dispose. Android owns the scheduled alarms.
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
