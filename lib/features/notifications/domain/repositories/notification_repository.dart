// ════════════════════════════════════════════════
// Project Lyra — Notification Repository Interface
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/notification_entities.dart';

typedef Result<T> = Either<Failure, T>;

abstract class NotificationRepository {
  Future<Result<List<AppNotification>>> getNotifications({int page = 1, int limit = 20});
  Future<Result<void>> markAsRead(String notificationId);
  Future<Result<void>> markAllAsRead();
  Future<Result<void>> deleteNotification(String notificationId);
  Future<Result<int>> getUnreadCount();
  Future<Result<NotificationSettings>> getSettings();
  Future<Result<NotificationSettings>> updateSettings(NotificationSettings settings);
  Future<Result<void>> registerPushToken(String token);
  Stream<List<AppNotification>> get notificationStream;
}
