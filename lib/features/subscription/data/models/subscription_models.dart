// ════════════════════════════════════════════════
// Project Lyra — Subscription Data Models
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/subscription_entities.dart';

part 'subscription_models.freezed.dart';
part 'subscription_models.g.dart';

@freezed
class SubscriptionPlanModel with _$SubscriptionPlanModel {
  const factory SubscriptionPlanModel({
    required String id,
    required String name,
    required String description,
    required double price,
    required String currency,
    required String period,
    @Default([]) List<String> features,
    @Default(false) bool isPopular,
    String? productId,
  }) = _SubscriptionPlanModel;

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) => _$SubscriptionPlanModelFromJson(json);
}

@freezed
class SubscriptionModel with _$SubscriptionModel {
  const factory SubscriptionModel({
    required String id,
    required String planId,
    required String planName,
    required String status,
    String? startDate,
    String? endDate,
    String? trialEndDate,
    @Default(true) bool autoRenew,
    String? receipt,
  }) = _SubscriptionModel;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) => _$SubscriptionModelFromJson(json);
}

/// Entity conversion extensions.
extension SubscriptionPlanModelX on SubscriptionPlanModel {
  SubscriptionPlan toEntity() => SubscriptionPlan(
        id: id, name: name, description: description,
        price: price, currency: currency, period: period,
        features: features, isPopular: isPopular, productId: productId,
      );
}

extension SubscriptionModelX on SubscriptionModel {
  Subscription toEntity() => Subscription(
        id: id, planId: planId, planName: planName,
        status: SubscriptionStatus.values.byName(status),
        startDate: startDate != null ? DateTime.tryParse(startDate!) : null,
        endDate: endDate != null ? DateTime.tryParse(endDate!) : null,
        trialEndDate: trialEndDate != null ? DateTime.tryParse(trialEndDate!) : null,
        autoRenew: autoRenew, receipt: receipt,
      );
}
