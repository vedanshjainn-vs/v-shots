// ════════════════════════════════════════════════
// Project Lyra — Search Remote Data Source
// ════════════════════════════════════════════════

import '../../../../../core/logging/app_logger.dart';
import '../models/search_models.dart';

abstract class SearchRemoteDataSource {
  Future<SearchResultModel> search(String query, {String? filter, int page = 1, int limit = 20});
  Future<List<SearchSuggestionModel>> getSuggestions(String query);
  Future<SearchResultModel> searchByType(String query, String type);
  Future<SearchResultModel> voiceSearch(String audioQuery);
}

class SupabaseSearchRemoteDataSource implements SearchRemoteDataSource {
  SupabaseSearchRemoteDataSource({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  @override
  Future<SearchResultModel> search(String query, {String? filter, int page = 1, int limit = 20}) async {
    try {
      // TODO(team): Implement with Supabase full-text search.
      // final response = await supabase.rpc('search_content', params: {
      //   'p_query': query,
      //   'p_filter': filter,
      //   'p_page': page,
      //   'p_limit': limit,
      // });
      return const SearchResultModel(
        tracks: [], albums: [], artists: [], playlists: [], totalResults: 0,
      );
    } catch (e, st) {
      _logger.e('SearchRemote: search failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<SearchSuggestionModel>> getSuggestions(String query) async {
    try {
      // TODO(team): Implement with Supabase autocomplete.
      return [];
    } catch (e, st) {
      _logger.e('SearchRemote: getSuggestions failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<SearchResultModel> searchByType(String query, String type) async {
    try {
      // TODO(team): Implement type-specific search.
      return const SearchResultModel(
        tracks: [], albums: [], artists: [], playlists: [], totalResults: 0,
      );
    } catch (e, st) {
      _logger.e('SearchRemote: searchByType failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<SearchResultModel> voiceSearch(String audioQuery) async {
    try {
      // TODO(team): Implement with AI speech-to-text + search.
      return const SearchResultModel(
        tracks: [], albums: [], artists: [], playlists: [], totalResults: 0,
      );
    } catch (e, st) {
      _logger.e('SearchRemote: voiceSearch failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}
