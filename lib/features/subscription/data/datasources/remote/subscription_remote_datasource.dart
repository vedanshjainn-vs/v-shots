// ════════════════════════════════════════════════
// Project Lyra — Subscription Remote Data Source
// ════════════════════════════════════════════════

import '../../../../../core/logging/app_logger.dart';
import '../models/subscription_models.dart';

abstract class SubscriptionRemoteDataSource {
  Future<List<SubscriptionPlanModel>> getPlans();
  Future<SubscriptionModel?> getCurrentSubscription();
  Future<SubscriptionModel> purchasePlan(String planId);
  Future<SubscriptionModel> restorePurchase();
  Future<void> cancelSubscription();
  Future<bool> isPremium();
}

class SupabaseSubscriptionRemoteDataSource implements SubscriptionRemoteDataSource {
  SupabaseSubscriptionRemoteDataSource({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  @override
  Future<List<SubscriptionPlanModel>> getPlans() async {
    try {
      // TODO(team): Implement with Supabase.
      // final response = await supabase.from('subscription_plans').select().eq('is_active', true);
      // return (response as List).map((r) => SubscriptionPlanModel.fromJson(r)).toList();
      return [];
    } catch (e, st) {
      _logger.e('SubscriptionRemote: getPlans failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<SubscriptionModel?> getCurrentSubscription() async {
    try {
      // TODO(team): Implement with Supabase.
      // final response = await supabase.from('subscriptions')
      //     .select()
      //     .eq('user_id', supabase.auth.currentUser!.id)
      //     .eq('status', 'active')
      //     .maybeSingle();
      return null;
    } catch (e, st) {
      _logger.e('SubscriptionRemote: getCurrentSubscription failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<SubscriptionModel> purchasePlan(String planId) async {
    try {
      // TODO(team): Implement with RevenueCat + Supabase.
      throw UnimplementedError('Purchase not implemented');
    } catch (e, st) {
      _logger.e('SubscriptionRemote: purchasePlan failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<SubscriptionModel> restorePurchase() async {
    try {
      // TODO(team): Implement with RevenueCat restore.
      throw UnimplementedError('Restore not implemented');
    } catch (e, st) {
      _logger.e('SubscriptionRemote: restorePurchase failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> cancelSubscription() async {
    try {
      // TODO(team): Implement with RevenueCat + Supabase.
      _logger.d('SubscriptionRemote: Cancelled subscription');
    } catch (e, st) {
      _logger.e('SubscriptionRemote: cancelSubscription failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<bool> isPremium() async {
    try {
      final subscription = await getCurrentSubscription();
      return subscription != null && (subscription.status == 'active' || subscription.status == 'trial');
    } catch (e) {
      return false;
    }
  }
}
