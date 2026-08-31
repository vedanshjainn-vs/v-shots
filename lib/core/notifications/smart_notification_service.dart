// ════════════════════════════════════════════════════════════════════════════
// V Shots — Smart Notification Service
// ════════════════════════════════════════════════════════════════════════════
// Android system scheduling — no in-process Timer, so schedules survive app
// process death. Rules: 4–8h gap, max 3/day, no spam, smart content.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../storage/local_library.dart';
import 'notification_service.dart';

class SmartNotificationService with WidgetsBindingObserver {
  SmartNotificationService._();
  static final SmartNotificationService instance = SmartNotificationService._();

  static const int maxNotificationsPerDay = 3;
  static const int minHoursBetweenNotifications = 4;
  static const int maxHoursBetweenNotifications = 8;
  static const int daysToScheduleAhead = 7;
  static const int _scheduleIdBase = 20000;

  static const String keyLastNotificationTime = 'last_smart_notification_time';
  static const String keyScheduleVersion = 'smart_notification_schedule_v3';

  bool _initialized = false;
  bool _rebuilding = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    try {
      tz_data.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.name));
    } catch (e) {
      debugPrint('[SmartNotif] Timezone setup failed: $e');
    }

    await _rebuildSchedule();
    debugPrint('[SmartNotif] Initialized — system scheduling active');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Foreground activity means the user is not a win-back candidate.
      // Do this asynchronously so lifecycle callbacks never block Flutter.
      markAppActive();
    }
  }

  Future<void> markAppActive() async {
    if (!_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_active_at', DateTime.now().toIso8601String());
    await _rebuildSchedule();
  }

  Future<void> _rebuildSchedule() async {
    if (!_initialized || _rebuilding) return;
    _rebuilding = true;
    try {
      await NotificationService.instance.cancelSmartNotifications();

      final prefs = await SharedPreferences.getInstance();
      final lastSentRaw = prefs.getString(keyLastNotificationTime);
      final lastSent =
          lastSentRaw == null ? null : DateTime.tryParse(lastSentRaw);

      var cursor = tz.TZDateTime.now(tz.local).add(const Duration(hours: 4));
      if (lastSent != null) {
        final nextAllowed = lastSent.add(
          const Duration(hours: minHoursBetweenNotifications),
        );
        final nextAllowedTz = tz.TZDateTime.from(nextAllowed, tz.local);
        if (nextAllowedTz.isAfter(cursor)) cursor = nextAllowedTz;
      }

      final random = Random();
      var notificationId = _scheduleIdBase;
      var dayKey = _calendarKey(cursor);
      var dayCount = 0;
      var scheduled = 0;
      final maxToSchedule = daysToScheduleAhead * maxNotificationsPerDay;

      while (scheduled < maxToSchedule) {
        final currentDay = _calendarKey(cursor);
        if (currentDay != dayKey) {
          dayKey = currentDay;
          dayCount = 0;
        }

        if (dayCount >= maxNotificationsPerDay) {
          cursor = _startOfNextDay(cursor).add(const Duration(hours: 8));
          continue;
        }

        final item = _generateSmartNotification(random, prefs);
        if (item == null) break;

        if (!cursor.isAfter(tz.TZDateTime.now(tz.local))) {
          cursor = cursor.add(const Duration(minutes: 1));
          continue;
        }

        await NotificationService.instance.scheduleSmartNotification(
          id: notificationId++,
          title: item.title,
          body: item.body,
          payload: item.payload,
          scheduledDate: cursor,
        );
        dayCount++;
        scheduled++;

        final gap = minHoursBetweenNotifications +
            random.nextInt(maxHoursBetweenNotifications -
                minHoursBetweenNotifications +
                1);
        cursor = cursor.add(Duration(hours: gap));
      }

      await prefs.setString(keyScheduleVersion, DateTime.now().toIso8601String());
      debugPrint('[SmartNotif] Scheduled $scheduled notifications');
    } finally {
      _rebuilding = false;
    }
  }

  _SmartNotification? _generateSmartNotification(
    Random random,
    SharedPreferences prefs,
  ) {
    final recent = LocalLibrary.instance.recentlyPlayed.value;
    final lastActiveRaw = prefs.getString('last_active_at');
    final lastActive =
        lastActiveRaw == null ? null : DateTime.tryParse(lastActiveRaw);

    if (lastActive != null &&
        DateTime.now().difference(lastActive).inDays >= 2) {
      return _SmartNotification(
        title: 'Your music is waiting 🎧',
        body: 'Come back and discover something new on V Shots.',
        payload: 'recommendation:',
      );
    }

    if (recent.isNotEmpty && random.nextBool()) {
      final track = recent[random.nextInt(recent.length)];
      final title = (track['title'] ?? 'your music').toString();
      final trackId = (track['id'] ?? '').toString();
      return _SmartNotification(
        title: 'Continue listening 🎵',
        body: 'Pick up where you left off with $title.',
        payload: 'song:$trackId',
      );
    }

    if (random.nextBool()) {
      return _SmartNotification(
        title: 'Trending right now 🔥',
        body: 'See what everyone is listening to on V Shots.',
        payload: 'trending:',
      );
    }

    return _SmartNotification(
      title: 'New music just dropped 🎶',
      body: 'Fresh tracks are waiting for you on V Shots.',
      payload: 'new_music:',
    );
  }

  String _calendarKey(tz.TZDateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  tz.TZDateTime _startOfNextDay(tz.TZDateTime d) =>
      tz.TZDateTime(tz.local, d.year, d.month, d.day + 1);

  Future<void> showTestNotification() async {
    await NotificationService.instance.showSmartNotification(
      id: 29999,
      title: 'V Shots notifications are working ✅',
      body: 'Background notification scheduling is active.',
      payload: 'recommendation:',
    );
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

class _SmartNotification {
  final String title;
  final String body;
  final String payload;

  _SmartNotification({
    required this.title,
    required this.body,
    required this.payload,
  });
}
