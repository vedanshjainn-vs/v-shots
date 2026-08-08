// ════════════════════════════════════════════════
// Project Lyra — Recommendation Remote Data Source
// ════════════════════════════════════════════════

import '../../../../../core/logging/app_logger.dart';
import '../models/recommendation_models.dart';

abstract class RecommendationRemoteDataSource {
  Future<RecommendationFeedModel> getRecommendations({Map<String, dynamic>? context});
  Future<List<RecommendationModel>> getSimilar({required String itemId, required String contentType, int limit = 10});
  Future<void> recordInteraction({required String itemId, required String interactionType});
  Future<void> dismissRecommendation(String recommendationId);
  Future<List<RecommendationModel>> getTrending({String? contentType, int limit = 20});
}

class SupabaseRecommendationRemoteDataSource implements RecommendationRemoteDataSource {
  SupabaseRecommendationRemoteDataSource({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  @override
  Future<RecommendationFeedModel> getRecommendations({Map<String, dynamic>? context}) async {
    try {
      // TODO(team): Implement with Supabase Edge Function (AI-powered).
      // final response = await supabase.functions.invoke('get-recommendations', body: context);
      return const RecommendationFeedModel(items: []);
    } catch (e, st) {
      _logger.e('RecommendationRemote: getRecommendations failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<RecommendationModel>> getSimilar({required String itemId, required String contentType, int limit = 10}) async {
    try {
      // TODO(team): Implement with Supabase RPC.
      return [];
    } catch (e, st) {
      _logger.e('RecommendationRemote: getSimilar failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> recordInteraction({required String itemId, required String interactionType}) async {
    try {
      // await supabase.from('interactions').insert({
      //   'user_id': supabase.auth.currentUser!.id,
      //   'item_id': itemId,
      //   'interaction_type': interactionType,
      //   'timestamp': DateTime.now().toIso8601String(),
      // });
      _logger.d('RecommendationRemote: Recorded interaction $interactionType for $itemId');
    } catch (e, st) {
      _logger.e('RecommendationRemote: recordInteraction failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> dismissRecommendation(String recommendationId) async {
    try {
      _logger.d('RecommendationRemote: Dismissed $recommendationId');
    } catch (e, st) {
      _logger.e('RecommendationRemote: dismissRecommendation failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<List<RecommendationModel>> getTrending({String? contentType, int limit = 20}) async {
    try {
      // TODO(team): Implement with Supabase query on trending view.
      return [];
    } catch (e, st) {
      _logger.e('RecommendationRemote: getTrending failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}
