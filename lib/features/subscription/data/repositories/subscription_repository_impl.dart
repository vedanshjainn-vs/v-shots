// ════════════════════════════════════════════════
// Project Lyra — Subscription Repository Implementation
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/mapper/failure_mapper.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/subscription_entities.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/remote/subscription_remote_datasource.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl({
    required this.remoteDataSource,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final SubscriptionRemoteDataSource remoteDataSource;
  final AppLogger _logger;

  @override
  Future<Either<Failure, List<SubscriptionPlan>>> getPlans() async {
    try {
      final plans = await remoteDataSource.getPlans();
      return Right(plans.map((p) => p.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, Subscription>> getCurrentSubscription() async {
    try {
      final subscription = await remoteDataSource.getCurrentSubscription();
      if (subscription == null) {
        return const Left(NotFoundFailure(message: 'No active subscription'));
      }
      return Right(subscription.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, Subscription>> purchasePlan(String planId) async {
    try {
      final subscription = await remoteDataSource.purchasePlan(planId);
      return Right(subscription.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, Subscription>> restorePurchase() async {
    try {
      final subscription = await remoteDataSource.restorePurchase();
      return Right(subscription.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> cancelSubscription() async {
    try {
      await remoteDataSource.cancelSubscription();
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, bool>> isPremium() async {
    try {
      final isPremium = await remoteDataSource.isPremium();
      return Right(isPremium);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> checkTrialEligibility() async {
    // TODO(team): Implement trial eligibility check.
    return const Right(null);
  }

  @override
  Stream<Subscription?> get subscriptionStream => const Stream.empty();
}
