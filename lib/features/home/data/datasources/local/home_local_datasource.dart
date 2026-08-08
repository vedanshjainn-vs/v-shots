// ════════════════════════════════════════════════
// Project Lyra — Home Local Data Source
// ════════════════════════════════════════════════

import '../../../../../core/cache/cache_key.dart';
import '../../../../../core/cache/cache_manager.dart';
import '../../../../../core/cache/policies/cache_policy.dart';
import '../../../../../core/logging/app_logger.dart';
import '../models/home_models.dart';

/// Local data source for home feed caching.
abstract class HomeLocalDataSource {
  Future<HomeFeedModel?> getCachedFeed();
  Future<void> cacheFeed(HomeFeedModel feed);
  Future<List<HomeItemModel>> getCachedRecommendations();
  Future<void> cacheRecommendations(List<HomeItemModel> items);
  Future<void> clearCache();
}

/// CacheManager-based implementation.
class CachedHomeLocalDataSource implements HomeLocalDataSource {
  CachedHomeLocalDataSource({
    required this.cacheManager,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final CacheManager cacheManager;
  final AppLogger _logger;

  static const String _namespace = 'home';
  static const String _feedKey = 'feed';
  static const String _recommendationsKey = 'recommendations';

  @override
  Future<HomeFeedModel?> getCachedFeed() async {
    try {
      final key = CacheKey(namespace: _namespace, id: _feedKey);
      final raw = cacheManager.getRaw(key);
      if (raw == null) return null;

      // Parse the cached JSON.
      final cached = cacheManager.get<HomeFeedModel>(
        key: key,
        policy: CachePolicy.dynamic,
        fromNetwork: () async => const HomeFeedModel(),
        fromJson: HomeFeedModel.fromJson,
        toJson: (data) => data.toJson(),
      );

      return null; // Simplified — actual implementation parses raw.
    } catch (e) {
      _logger.w('HomeLocal: getCachedFeed failed');
      return null;
    }
  }

  @override
  Future<void> cacheFeed(HomeFeedModel feed) async {
    try {
      final key = CacheKey(namespace: _namespace, id: _feedKey);
      await cacheManager.put<HomeFeedModel>(
        key: key,
        data: feed,
        toJson: (data) => data.toJson(),
        ttl: CachePolicy.dynamic.maxAge,
      );
      _logger.d('HomeLocal: Feed cached');
    } catch (e) {
      _logger.w('HomeLocal: cacheFeed failed');
    }
  }

  @override
  Future<List<HomeItemModel>> getCachedRecommendations() async {
    return [];
  }

  @override
  Future<void> cacheRecommendations(List<HomeItemModel> items) async {
    try {
      final key = CacheKey(namespace: _namespace, id: _recommendationsKey);
      await cacheManager.putRaw(key, items.map((i) => i.toJson()).toList().toString());
    } catch (e) {
      _logger.w('HomeLocal: cacheRecommendations failed');
    }
  }

  @override
  Future<void> clearCache() async {
    await cacheManager.invalidateNamespace(_namespace);
  }
}
