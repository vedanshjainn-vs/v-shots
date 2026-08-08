// ════════════════════════════════════════════════
// Project Lyra — Search Entities
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_entities.freezed.dart';
part 'search_entities.g.dart';

@freezed
class SearchQuery with _$SearchQuery {
  const factory SearchQuery({
    required String query,
    String? filter,
    @Default(1) int page,
    @Default(20) int limit,
  }) = _SearchQuery;

  factory SearchQuery.fromJson(Map<String, dynamic> json) => _$SearchQueryFromJson(json);
}

@freezed
class SearchResult with _$SearchResult {
  const factory SearchResult({
    required List<SearchResultItem> tracks,
    required List<SearchResultItem> albums,
    required List<SearchResultItem> artists,
    required List<SearchResultItem> playlists,
    @Default(0) int totalResults,
    String? query,
  }) = _SearchResult;

  factory SearchResult.fromJson(Map<String, dynamic> json) => _$SearchResultFromJson(json);
}

@freezed
class SearchResultItem with _$SearchResultItem {
  const factory SearchResultItem({
    required String id,
    required String title,
    String? subtitle,
    String? imageUrl,
    required String type,
    @Default(0.0) double relevance,
  }) = _SearchResultItem;

  factory SearchResultItem.fromJson(Map<String, dynamic> json) => _$SearchResultItemFromJson(json);
}

@freezed
class SearchSuggestion with _$SearchSuggestion {
  const factory SearchSuggestion({
    required String text,
    String? imageUrl,
    String? type,
  }) = _SearchSuggestion;

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) => _$SearchSuggestionFromJson(json);
}

@freezed
class RecentSearch with _$RecentSearch {
  const factory RecentSearch({
    required String query,
    required DateTime searchedAt,
  }) = _RecentSearch;

  factory RecentSearch.fromJson(Map<String, dynamic> json) => _$RecentSearchFromJson(json);
}
