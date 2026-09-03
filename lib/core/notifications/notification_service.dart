import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializing;

  static const String channelMusicPlayer = 'vshots_music_player';
  static const String channelUpdates = 'vshots_updates';
  static const String channelRecommendations = 'vshots_recommendations';
  static const String channelNewMusic = 'vshots_new_music';
  static const String keyUpdateDismissed = 'update_dismissed_v';
  static const String keyUpdateReminderDate = 'update_reminder_date';
  static const String keyNotifPermissionRequested =
      'notif_permission_requested';
  static const int smartNotificationIdStart = 20000;
  static const int smartNotificationIdEnd = 20999;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initializeOnce();
  }

  Future<void> _initializeOnce() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
        ),
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      await _createNotificationChannels();

      // IMPORTANT: do not call public hasNotificationPermission() here.
      // That method calls initialize(), which would await this very Future and
      // deadlock the boot sequence. Permission checks during initialization
      // must use the platform implementation directly.
      final granted = await _readNotificationPermission();
      if (!granted) {
        final requested = await _requestNotificationPermissionInternal();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(keyNotifPermissionRequested, requested);
      }

      _initialized = true;
      debugPrint(
        '[NotificationService] Initialized; permissionInitially=$granted',
      );
    } catch (e, stack) {
      // Failure-tolerant init (Requirement #11 / #21): notification setup must
      // NEVER be able to prevent the Flutter UI from starting. main() awaits
      // this inside a Future.wait; rethrowing here would surface out of
      // runApp()'s startup and cause a black screen. We log and mark
      // uninitialized so the app still launches and only notifications are
      // unavailable.
      debugPrint('[NotificationService] initialize failed: $e');
      debugPrint('$stack');
      _initialized = false;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _createNotificationChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        channelMusicPlayer,
        'V Shots Music Player',
        description: 'Media playback controls',
        importance: Importance.low,
        showBadge: false,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        channelUpdates,
        'V Shots Updates',
        description: 'App update notifications',
        importance: Importance.defaultImportance,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        channelRecommendations,
        'V Shots Recommendations',
        description: 'Personalized music recommendations',
        importance: Importance.defaultImportance,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        channelNewMusic,
        'V Shots New Music',
        description: 'New music releases',
        importance: Importance.defaultImportance,
      ),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationService] Tapped: ${response.payload ?? ''}');
    // Navigation/playback is intentionally handled by the app router when it
    // is ready. The notification itself must never be discarded just because
    // a payload is absent.
  }

  Future<void> scheduleSmartNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
    required tz.TZDateTime scheduledDate,
  }) async {
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      channelRecommendations,
      'V Shots Recommendations',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> cancelSmartNotifications() async {
    await initialize();
    for (var id = smartNotificationIdStart;
        id <= smartNotificationIdEnd;
        id++) {
      await _plugin.cancel(id);
    }
  }

  Future<void> showSmartNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
    String channelId = channelRecommendations,
  }) async {
    await initialize();
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == channelNewMusic
          ? 'V Shots New Music'
          : 'V Shots Recommendations',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    await initialize();
    await _plugin.cancel(id);
  }

  Future<bool> _requestNotificationPermissionInternal() async {
    var granted = true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      granted = (await android.requestNotificationsPermission()) ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      granted =
          await ios.requestPermissions(alert: true, badge: true, sound: true) ??
              granted;
    }
    return granted;
  }

  Future<bool> requestNotificationPermission() async {
    await initialize();
    return _requestNotificationPermissionInternal();
  }

  Future<bool> _readNotificationPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  Future<bool> hasNotificationPermission() async {
    await initialize();
    return _readNotificationPermission();
  }

  Future<void> showUpdateNotification(String versionName) async {
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      channelUpdates,
      'V Shots Updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.show(
      1001,
      'V Shots Update Available 🎵',
      'Update to v$versionName for the latest features and improvements.',
      const NotificationDetails(android: androidDetails),
      payload: 'update:',
    );
  }

  Future<void> cancelUpdateNotification() async {
    await initialize();
    await _plugin.cancel(1001);
  }

  Future<void> saveUpdateDismissed(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyUpdateDismissed, version);
    await prefs.setString(
      keyUpdateReminderDate,
      DateTime.now().toIso8601String(),
    );
  }

  Future<bool> shouldShowUpdateReminder(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedVersion = prefs.getString(keyUpdateDismissed);
    final reminderDateStr = prefs.getString(keyUpdateReminderDate);
    if (dismissedVersion != version) return true;
    if (reminderDateStr == null) return true;
    final reminderDate = DateTime.tryParse(reminderDateStr);
    if (reminderDate == null) return true;
    return DateTime.now().difference(reminderDate).inDays >= 3;
  }
}
