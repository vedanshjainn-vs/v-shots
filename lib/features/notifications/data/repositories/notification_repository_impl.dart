// ════════════════════════════════════════════════
// Project Lyra — Notification Repository Implementation
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/mapper/failure_mapper.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/notification_entities.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/remote/notification_remote_datasource.dart';
import '../models/notification_models.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({
    required this.remoteDataSource,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final NotificationRemoteDataSource remoteDataSource;
  final AppLogger _logger;

  @override
  Future<Either<Failure, List<AppNotification>>> getNotifications({int page = 1, int limit = 20}) async {
    try {
      final notifications = await remoteDataSource.getNotifications(page: page, limit: limit);
      return Right(notifications.map((n) => n.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> markAsRead(String notificationId) async {
    try {
      await remoteDataSource.markAsRead(notificationId);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> markAllAsRead() async {
    try {
      await remoteDataSource.markAllAsRead();
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> deleteNotification(String notificationId) async {
    try {
      await remoteDataSource.deleteNotification(notificationId);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async {
    try {
      final count = await remoteDataSource.getUnreadCount();
      return Right(count);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, NotificationSettings>> getSettings() async {
    try {
      final settings = await remoteDataSource.getSettings();
      return Right(settings.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, NotificationSettings>> updateSettings(NotificationSettings settings) async {
    try {
      final updated = await remoteDataSource.updateSettings(settings.toModel());
      return Right(updated.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> registerPushToken(String token) async {
    try {
      await remoteDataSource.registerPushToken(token);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Stream<List<AppNotification>> get notificationStream => const Stream.empty();
}
