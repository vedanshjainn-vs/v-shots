// ════════════════════════════════════════════════
// Project Lyra — Notification Use Cases
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/notification_entities.dart';
import '../repositories/notification_repository.dart';

class GetNotifications implements UseCase<List<AppNotification>, PageParams> {
  const GetNotifications(this.repository);
  final NotificationRepository repository;
  @override
  Future<Either<Failure, List<AppNotification>>> call(PageParams params) =>
      repository.getNotifications(page: params.page, limit: params.limit);
}

class MarkNotificationAsRead implements UseCaseVoid<String> {
  const MarkNotificationAsRead(this.repository);
  final NotificationRepository repository;
  @override
  Future<Either<Failure, void>> call(String id) => repository.markAsRead(id);
}

class MarkAllNotificationsAsRead implements UseCaseVoid<NoParams> {
  const MarkAllNotificationsAsRead(this.repository);
  final NotificationRepository repository;
  @override
  Future<Either<Failure, void>> call(NoParams params) => repository.markAllAsRead();
}

class GetUnreadCount implements UseCase<int, NoParams> {
  const GetUnreadCount(this.repository);
  final NotificationRepository repository;
  @override
  Future<Either<Failure, int>> call(NoParams params) => repository.getUnreadCount();
}

class UpdateNotificationSettings implements UseCase<NotificationSettings, NotificationSettings> {
  const UpdateNotificationSettings(this.repository);
  final NotificationRepository repository;
  @override
  Future<Either<Failure, NotificationSettings>> call(NotificationSettings settings) =>
      repository.updateSettings(settings);
}
