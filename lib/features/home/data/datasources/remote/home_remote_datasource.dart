// ════════════════════════════════════════════════
// Project Lyra — Home Remote Data Source
// ════════════════════════════════════════════════

import '../../../core/logging/app_logger.dart';
import '../models/home_models.dart';

/// Remote data source for home feed.
///
/// Fetches personalized feed from Supabase.
abstract class HomeRemoteDataSource {
  Future<HomeFeedModel> getFeed({int page = 1, int limit = 20});
  Future<List<HomeItemModel>> getRecommendations({int limit = 20});
  Future<List<HomeItemModel>> getContinueListening();
  Future<List<BannerModel>> getBanners();
  Future<List<HomeItemModel>> getTrending({String? contentType, int limit = 20});
  Future<List<HomeItemModel>> getNewReleases({int limit = 20});
}

/// Supabase implementation of [HomeRemoteDataSource].
class SupabaseHomeRemoteDataSource implements HomeRemoteDataSource {
  SupabaseHomeRemoteDataSource({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  @override
  Future<HomeFeedModel> getFeed({int page = 1, int limit = 20}) async {
    try {
      // TODO(team): Implement with Supabase.
      // final response = await supabase.rpc('get_home_feed', params: {
      //   'p_page': page,
      //   'p_limit': limit,
      // });
      // return HomeFeedModel.fromJson(response);

      // Placeholder: Return empty feed until Supabase is connected.
      return const HomeFeedModel(sections: [], banners: []);
    } catch (e, st) {
      _logger.e('HomeRemote: getFeed failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<HomeItemModel>> getRecommendations({int limit = 20}) async {
    try {
      // TODO(team): Implement with Supabase RPC or Edge Function.
      return [];
    } catch (e, st) {
      _logger.e('HomeRemote: getRecommendations failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<HomeItemModel>> getContinueListening() async {
    try {
      // TODO(team): Implement with Supabase query on listening_history.
      return [];
    } catch (e, st) {
      _logger.e('HomeRemote: getContinueListening failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<BannerModel>> getBanners() async {
    try {
      // TODO(team): Implement with Supabase query on banners table.
      // final response = await supabase
      //     .from('banners')
      //     .select()
      //     .eq('is_active', true)
      //     .order('priority', ascending: true)
      //     .limit(10);
      // return (response as List).map((r) => BannerModel.fromJson(r)).toList();
      return [];
    } catch (e, st) {
      _logger.e('HomeRemote: getBanners failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<HomeItemModel>> getTrending({String? contentType, int limit = 20}) async {
    try {
      // TODO(team): Implement with Supabase query on trending view.
      return [];
    } catch (e, st) {
      _logger.e('HomeRemote: getTrending failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<HomeItemModel>> getNewReleases({int limit = 20}) async {
    try {
      // TODO(team): Implement with Supabase query on albums table.
      return [];
    } catch (e, st) {
      _logger.e('HomeRemote: getNewReleases failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}
