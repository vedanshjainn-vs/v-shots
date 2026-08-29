// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Notification History & Frequency Control
// ═════════════════════════════════════════════════════════════════════════════
//
// Tracks notification history to prevent spam and duplicates.
// Uses Supabase (existing infrastructure, free tier).
//
// Features:
// - Duplicate prevention (same content within cooldown period)
// - Frequency limiting (max N notifications per day)
// - User engagement tracking (opens/clicks)
// - Smart cooldown based on user interaction

import 'package:flutter/foundation.dart';

import '../backend/supabase_service.dart';

class NotificationHistoryService {
  NotificationHistoryService._();
  static final NotificationHistoryService instance =
      NotificationHistoryService._();

  // Frequency limits
  static const int maxMarketingPerDay = 1;
  static const int minHoursBetweenNotifications = 4;
  static const int cooldownDaysForDuplicate = 7;

  Future<bool> shouldSendNotification({
    required String userId,
    required String type,
    required String contentId,
  }) async {
    try {
      final response = await SupabaseService.client
          .from('notification_history')
          .select()
          .eq('user_id', userId)
          .eq('notification_type', type)
          .eq('content_id', contentId)
          .order('sent_at', ascending: false)
          .limit(1);

      final history = response as List<dynamic>;

      if (history.isEmpty) return true;

      final lastSent = DateTime.parse(history.first['sent_at'] as String);
      final daysSince = DateTime.now().difference(lastSent).inDays;

      // Check cooldown for duplicate content
      if (daysSince < cooldownDaysForDuplicate) {
        debugPrint('[NotifHistory] Duplicate prevented: $type/$contentId');
        return false;
      }

      // Check daily frequency limit
      final todayCount = await _getTodayCount(userId, type);
      if (todayCount >= maxMarketingPerDay) {
        debugPrint('[NotifHistory] Daily limit reached: $type');
        return false;
      }

      // Check minimum hours between notifications
      final hoursSince = DateTime.now().difference(lastSent).inHours;
      if (hoursSince < minHoursBetweenNotifications) {
        debugPrint('[NotifHistory] Too soon: $type (${hoursSince}h)');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[NotifHistory] Check failed: $e');
      return true; // Allow if check fails (fail-safe)
    }
  }

  Future<int> _getTodayCount(String userId, String type) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final response = await SupabaseService.client
          .from('notification_history')
          .select('id')
          .eq('user_id', userId)
          .eq('notification_type', type)
          .gte('sent_at', todayStart.toIso8601String());

      final count = (response as List<dynamic>).length;
      return count;
    } catch (e) {
      debugPrint('[NotifHistory] Count failed: $e');
      return 0;
    }
  }

  Future<void> recordSent({
    required String userId,
    required String type,
    required String contentId,
    required String title,
    required String body,
  }) async {
    try {
      await SupabaseService.client.from('notification_history').insert({
        'user_id': userId,
        'notification_type': type,
        'content_id': contentId,
        'title': title,
        'body': body,
        'sent_at': DateTime.now().toIso8601String(),
        'opened_at': null,
        'clicked': false,
      });

      debugPrint('[NotifHistory] Recorded: $type/$contentId');
    } catch (e) {
      debugPrint('[NotifHistory] Record failed: $e');
    }
  }

  Future<void> recordOpened(String notificationId) async {
    try {
      await SupabaseService.client.from('notification_history').update({
        'opened_at': DateTime.now().toIso8601String(),
        'clicked': true,
      }).eq('id', notificationId);
    } catch (e) {
      debugPrint('[NotifHistory] Opened record failed: $e');
    }
  }

  /// Get user's engagement score (0.0 to 1.0)
  Future<double> getEngagementScore(String userId) async {
    try {
      final response = await SupabaseService.client
          .from('notification_history')
          .select('clicked')
          .eq('user_id', userId)
          .order('sent_at', ascending: false)
          .limit(20);

      final history = response as List<dynamic>;
      if (history.isEmpty) return 0.5; // Default neutral score

      int clicks = 0;
      for (final record in history) {
        if (record['clicked'] == true) clicks++;
      }

      return clicks / history.length;
    } catch (e) {
      debugPrint('[NotifHistory] Engagement score failed: $e');
      return 0.5;
    }
  }
}
