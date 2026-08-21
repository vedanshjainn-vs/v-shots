// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Notifications Service
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import '../backend/supabase_service.dart';
import '../models/notification_model.dart';

class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  // No fabricated demo content: an empty inbox stays empty.
  // (was a mock list pre-2026-08-21; removed for honesty)

  Future<List<NotificationModel>> fetchNotifications() async {
    final user = SupabaseService.currentUser;
    if (!SupabaseService.isAvailable || user == null) {
      // Honest empty state — never fabricate notifications for real users.
      return const [];
    }

    try {
      final response = await SupabaseService.client
          .from('notifications')
          .select('*, profiles:actor_id(*)')
          .eq('recipient_id', user.id)
          .order('created_at', ascending: false);

      final data = response as List<dynamic>;
      if (data.isEmpty) {
        return const [];
      }
      return data
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[NotificationsService] fetchNotifications error: $e');
      return const [];
    }
  }

  Future<void> markAllAsRead() async {
    final user = SupabaseService.currentUser;
    if (!SupabaseService.isAvailable || user == null) {
      return;
    }

    try {
      await SupabaseService.client
          .from('notifications')
          .update({'read': true}).eq('recipient_id', user.id);
    } catch (e) {
      debugPrint('[NotificationsService] markAllAsRead error: $e');
    }
  }
}
