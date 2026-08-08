// ════════════════════════════════════════════════
// Project Lyra — Search Local Data Source
// ════════════════════════════════════════════════

import '../../../../../core/logging/app_logger.dart';
import '../../../../../core/storage/local_storage.dart';
import '../models/search_models.dart';

abstract class SearchLocalDataSource {
  Future<List<RecentSearch>> getRecentSearches();
  Future<void> saveRecentSearch(String query);
  Future<void> deleteRecentSearch(String query);
  Future<void> clearRecentSearches();
  Future<List<SearchResultItemModel>> getCachedResults(String query);
  Future<void> cacheResults(String query, List<SearchResultItemModel> results);
}

class HiveSearchLocalDataSource implements SearchLocalDataSource {
  HiveSearchLocalDataSource({required this.localStorage, AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final LocalStorage localStorage;
  final AppLogger _logger;

  static const String _recentKey = 'recent_searches';
  static const int _maxRecentSearches = 20;

  @override
  Future<List<RecentSearch>> getRecentSearches() async {
    try {
      final searches = await localStorage.getStringList(_recentKey) ?? [];
      return searches.map((s) {
        final parts = s.split('|');
        return RecentSearch(
          query: parts[0],
          searchedAt: DateTime.tryParse(parts.length > 1 ? parts[1] : '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      _logger.w('SearchLocal: getRecentSearches failed');
      return [];
    }
  }

  @override
  Future<void> saveRecentSearch(String query) async {
    try {
      final searches = await localStorage.getStringList(_recentKey) ?? [];
      // Remove if already exists.
      searches.removeWhere((s) => s.startsWith('$query|'));
      // Add to front.
      searches.insert(0, '$query|${DateTime.now().toIso8601String()}');
      // Trim to max.
      if (searches.length > _maxRecentSearches) {
        searches.removeRange(_maxRecentSearches, searches.length);
      }
      await localStorage.setStringList(_recentKey, searches);
    } catch (e) {
      _logger.w('SearchLocal: saveRecentSearch failed');
    }
  }

  @override
  Future<void> deleteRecentSearch(String query) async {
    try {
      final searches = await localStorage.getStringList(_recentKey) ?? [];
      searches.removeWhere((s) => s.startsWith('$query|'));
      await localStorage.setStringList(_recentKey, searches);
    } catch (e) {
      _logger.w('SearchLocal: deleteRecentSearch failed');
    }
  }

  @override
  Future<void> clearRecentSearches() async {
    await localStorage.remove(_recentKey);
  }

  @override
  Future<List<SearchResultItemModel>> getCachedResults(String query) async {
    // TODO(team): Implement search result caching.
    return [];
  }

  @override
  Future<void> cacheResults(String query, List<SearchResultItemModel> results) async {
    // TODO(team): Implement search result caching.
  }
}
