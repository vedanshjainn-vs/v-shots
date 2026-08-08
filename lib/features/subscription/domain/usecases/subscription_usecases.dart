// ════════════════════════════════════════════════
// Project Lyra — Subscription Use Cases
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/subscription_entities.dart';
import '../repositories/subscription_repository.dart';

class GetPlans implements UseCase<List<SubscriptionPlan>, NoParams> {
  const GetPlans(this.repository);
  final SubscriptionRepository repository;
  @override
  Future<Either<Failure, List<SubscriptionPlan>>> call(NoParams params) => repository.getPlans();
}

class GetCurrentSubscription implements UseCase<Subscription, NoParams> {
  const GetCurrentSubscription(this.repository);
  final SubscriptionRepository repository;
  @override
  Future<Either<Failure, Subscription>> call(NoParams params) =>
      repository.getCurrentSubscription();
}

class PurchasePlan implements UseCase<Subscription, String> {
  const PurchasePlan(this.repository);
  final SubscriptionRepository repository;
  @override
  Future<Either<Failure, Subscription>> call(String planId) =>
      repository.purchasePlan(planId);
}

class RestorePurchase implements UseCase<Subscription, NoParams> {
  const RestorePurchase(this.repository);
  final SubscriptionRepository repository;
  @override
  Future<Either<Failure, Subscription>> call(NoParams params) =>
      repository.restorePurchase();
}

class CancelSubscription implements UseCaseVoid<NoParams> {
  const CancelSubscription(this.repository);
  final SubscriptionRepository repository;
  @override
  Future<Either<Failure, void>> call(NoParams params) => repository.cancelSubscription();
}

class IsPremium implements UseCase<bool, NoParams> {
  const IsPremium(this.repository);
  final SubscriptionRepository repository;
  @override
  Future<Either<Failure, bool>> call(NoParams params) => repository.isPremium();
}
