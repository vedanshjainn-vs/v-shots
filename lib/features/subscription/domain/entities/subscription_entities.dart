// ════════════════════════════════════════════════
// Project Lyra — Subscription Entities
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'subscription_entities.freezed.dart';
part 'subscription_entities.g.dart';

@freezed
class SubscriptionPlan with _$SubscriptionPlan {
  const factory SubscriptionPlan({
    required String id,
    required String name,
    required String description,
    required double price,
    required String currency,
    required String period,
    @Default([]) List<String> features,
    @Default(false) bool isPopular,
    String? productId,
  }) = _SubscriptionPlan;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) => _$SubscriptionPlanFromJson(json);
}

@freezed
class Subscription with _$Subscription {
  const factory Subscription({
    required String id,
    required String planId,
    required String planName,
    required SubscriptionStatus status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? trialEndDate,
    @Default(false) bool autoRenew,
    String? receipt,
  }) = _Subscription;

  factory Subscription.fromJson(Map<String, dynamic> json) => _$SubscriptionFromJson(json);
}

@freezed
class Receipt with _$Receipt {
  const factory Receipt({
    required String id,
    required String productId,
    required String transactionId,
    required DateTime purchaseDate,
    DateTime? expiryDate,
    @Default({}) Map<String, dynamic> rawData,
  }) = _Receipt;

  factory Receipt.fromJson(Map<String, dynamic> json) => _$ReceiptFromJson(json);
}

enum SubscriptionStatus {
  active,
  expired,
  cancelled,
  trial,
  gracePeriod,
}
