// ════════════════════════════════════════════════
// Project Lyra — Notification Remote Data Source
// ════════════════════════════════════════════════

import '../../../../../core/logging/app_logger.dart';
import '../models/notification_models.dart';

abstract class NotificationRemoteDataSource {
  Future<List<NotificationModel>> getNotifications({int page = 1, int limit = 20});
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<void> deleteNotification(String notificationId);
  Future<int> getUnreadCount();
  Future<NotificationSettingsModel> getSettings();
  Future<NotificationSettingsModel> updateSettings(NotificationSettingsModel settings);
  Future<void> registerPushToken(String token);
}

class SupabaseNotificationRemoteDataSource implements NotificationRemoteDataSource {
  SupabaseNotificationRemoteDataSource({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  @override
  Future<List<NotificationModel>> getNotifications({int page = 1, int limit = 20}) async {
    try {
      // TODO(team): Implement with Supabase.
      // final response = await supabase.from('notifications')
      //     .select()
      //     .eq('user_id', supabase.auth.currentUser!.id)
      //     .order('created_at', ascending: false)
      //     .range((page - 1) * limit, page * limit - 1);
      return [];
    } catch (e, st) {
      _logger.e('NotificationRemote: getNotifications failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      // await supabase.from('notifications')
      //     .update({'is_read': true})
      //     .eq('id', notificationId);
      _logger.d('NotificationRemote: Marked $notificationId as read');
    } catch (e, st) {
      _logger.e('NotificationRemote: markAsRead failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      // await supabase.from('notifications')
      //     .update({'is_read': true})
      //     .eq('user_id', supabase.auth.currentUser!.id)
      //     .eq('is_read', false);
      _logger.d('NotificationRemote: Marked all as read');
    } catch (e, st) {
      _logger.e('NotificationRemote: markAllAsRead failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      // await supabase.from('notifications').delete().eq('id', notificationId);
      _logger.d('NotificationRemote: Deleted $notificationId');
    } catch (e, st) {
      _logger.e('NotificationRemote: deleteNotification failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      // final response = await supabase.from('notifications')
      //     .select('id')
      //     .eq('user_id', supabase.auth.currentUser!.id)
      //     .eq('is_read', false)
      //     .count();
      // return response.count;
      return 0;
    } catch (e, st) {
      _logger.e('NotificationRemote: getUnreadCount failed', error: e, stackTrace: st);
      return 0;
    }
  }

  @override
  Future<NotificationSettingsModel> getSettings() async {
    try {
      // TODO(team): Implement with Supabase.
      return const NotificationSettingsModel();
    } catch (e, st) {
      _logger.e('NotificationRemote: getSettings failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<NotificationSettingsModel> updateSettings(NotificationSettingsModel settings) async {
    try {
      // TODO(team): Implement with Supabase.
      return settings;
    } catch (e, st) {
      _logger.e('NotificationRemote: updateSettings failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> registerPushToken(String token) async {
    try {
      // await supabase.from('push_tokens').upsert({
      //   'user_id': supabase.auth.currentUser!.id,
      //   'token': token,
      //   'platform': 'android',
      // });
      _logger.d('NotificationRemote: Registered push token');
    } catch (e, st) {
      _logger.e('NotificationRemote: registerPushToken failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}
