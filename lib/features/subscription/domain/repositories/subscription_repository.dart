// ════════════════════════════════════════════════
// Project Lyra — Subscription Repository Interface
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/subscription_entities.dart';

typedef Result<T> = Either<Failure, T>;

abstract class SubscriptionRepository {
  Future<Result<List<SubscriptionPlan>>> getPlans();
  Future<Result<Subscription>> getCurrentSubscription();
  Future<Result<Subscription>> purchasePlan(String planId);
  Future<Result<Subscription>> restorePurchase();
  Future<Result<void>> cancelSubscription();
  Future<Result<bool>> isPremium();
  Future<Result<void>> checkTrialEligibility();
  Stream<Subscription?> get subscriptionStream;
}
