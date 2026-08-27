// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Notification Preferences Service
// ═════════════════════════════════════════════════════════════════════════════
//
// Manages user notification preferences and syncs with backend.
// Uses Supabase (existing infrastructure, free tier).

import 'package:flutter/foundation.dart';
<<<<<<< HEAD
=======

>>>>>>> 3f91a8f (fix: format all files + add rewarded ad button on home page)
import '../backend/supabase_service.dart';
import '../models/notification_preferences_model.dart';

class NotificationPreferencesService {
  NotificationPreferencesService._();
  static final NotificationPreferencesService instance =
      NotificationPreferencesService._();

  NotificationPreferences? _cached;

  Future<NotificationPreferences?> getPreferences() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;

    // Return cached if available
    if (_cached != null && _cached!.userId == user.id) {
      return _cached;
    }

    try {
      final response = await SupabaseService.client
          .from('notification_preferences')
          .select()
          .eq('user_id', user.id)
          .single();

<<<<<<< HEAD
      _cached =
          NotificationPreferences.fromJson(response as Map<String, dynamic>);
=======
      _cached = NotificationPreferences.fromJson(
        response as Map<String, dynamic>,
      );
>>>>>>> 3f91a8f (fix: format all files + add rewarded ad button on home page)
      return _cached;
    } catch (e) {
      debugPrint('[NotifPrefs] Fetch failed: $e');
      return null;
    }
  }

  Future<bool> updatePreferences({
    bool? notificationsEnabled,
    bool? newMusicEnabled,
    bool? recommendationsEnabled,
    bool? trendingEnabled,
    bool? winbackEnabled,
    bool? updateNotificationsEnabled,
    String? preferredTime,
    String? timezone,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) return false;

    final prefs = await getPreferences();

<<<<<<< HEAD
    final updated = prefs?.copyWith(
=======
    final updated =
        prefs?.copyWith(
>>>>>>> 3f91a8f (fix: format all files + add rewarded ad button on home page)
          notificationsEnabled: notificationsEnabled,
          newMusicEnabled: newMusicEnabled,
          recommendationsEnabled: recommendationsEnabled,
          trendingEnabled: trendingEnabled,
          winbackEnabled: winbackEnabled,
          updateNotificationsEnabled: updateNotificationsEnabled,
          preferredTime: preferredTime,
          timezone: timezone,
        ) ??
        NotificationPreferences(
          userId: user.id,
          notificationsEnabled: notificationsEnabled ?? true,
          newMusicEnabled: newMusicEnabled ?? true,
          recommendationsEnabled: recommendationsEnabled ?? true,
          trendingEnabled: trendingEnabled ?? true,
          winbackEnabled: winbackEnabled ?? true,
          updateNotificationsEnabled: updateNotificationsEnabled ?? true,
          preferredTime: preferredTime,
          timezone: timezone,
          updatedAt: DateTime.now(),
        );

    try {
      await SupabaseService.client
          .from('notification_preferences')
          .upsert(updated.toJson());

      _cached = updated;
      debugPrint('[NotifPrefs] Updated');
      return true;
    } catch (e) {
      debugPrint('[NotifPrefs] Update failed: $e');
      return false;
    }
  }

  /// Check if a specific notification type is enabled
  Future<bool> isTypeEnabled(String type) async {
    final prefs = await getPreferences();
    if (prefs == null) return true; // Default to enabled
    if (!prefs.notificationsEnabled) return false;

    switch (type) {
      case 'new_music':
        return prefs.newMusicEnabled;
      case 'recommendation':
        return prefs.recommendationsEnabled;
      case 'trending':
        return prefs.trendingEnabled;
      case 'winback':
        return prefs.winbackEnabled;
      case 'update':
        return prefs.updateNotificationsEnabled;
      default:
        return true;
    }
  }
}
