// ════════════════════════════════════════════════
// Project Lyra — Search Repository Interface
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/search_entities.dart';

typedef Result<T> = Either<Failure, T>;

abstract class SearchRepository {
  Future<Result<SearchResult>> search(String query, {String? filter, int page = 1, int limit = 20});
  Future<Result<List<SearchSuggestion>>> getSuggestions(String query);
  Future<Result<List<RecentSearch>>> getRecentSearches();
  Future<Result<void>> saveRecentSearch(String query);
  Future<Result<void>> clearRecentSearches();
  Future<Result<void>> deleteRecentSearch(String query);
  Future<Result<SearchResult>> searchByType(String query, String type);
  Future<Result<SearchResult>> voiceSearch(String audioQuery);
}
