// ════════════════════════════════════════════════
// Project Lyra — Search Data Models
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/search_entities.dart';

part 'search_models.freezed.dart';
part 'search_models.g.dart';

@freezed
class SearchResultModel with _$SearchResultModel {
  const factory SearchResultModel({
    @Default([]) List<SearchResultItemModel> tracks,
    @Default([]) List<SearchResultItemModel> albums,
    @Default([]) List<SearchResultItemModel> artists,
    @Default([]) List<SearchResultItemModel> playlists,
    @Default(0) int totalResults,
    String? query,
  }) = _SearchResultModel;

  factory SearchResultModel.fromJson(Map<String, dynamic> json) => _$SearchResultModelFromJson(json);
}

@freezed
class SearchResultItemModel with _$SearchResultItemModel {
  const factory SearchResultItemModel({
    required String id,
    required String title,
    String? subtitle,
    String? imageUrl,
    required String type,
    @Default(0.0) double relevance,
  }) = _SearchResultItemModel;

  factory SearchResultItemModel.fromJson(Map<String, dynamic> json) => _$SearchResultItemModelFromJson(json);
}

@freezed
class SearchSuggestionModel with _$SearchSuggestionModel {
  const factory SearchSuggestionModel({
    required String text,
    String? imageUrl,
    String? type,
  }) = _SearchSuggestionModel;

  factory SearchSuggestionModel.fromJson(Map<String, dynamic> json) => _$SearchSuggestionModelFromJson(json);
}

/// Entity conversion extensions.
extension SearchResultModelX on SearchResultModel {
  SearchResult toEntity() => SearchResult(
        tracks: tracks.map((i) => i.toEntity()).toList(),
        albums: albums.map((i) => i.toEntity()).toList(),
        artists: artists.map((i) => i.toEntity()).toList(),
        playlists: playlists.map((i) => i.toEntity()).toList(),
        totalResults: totalResults,
        query: query,
      );
}

extension SearchResultItemModelX on SearchResultItemModel {
  SearchResultItem toEntity() => SearchResultItem(
        id: id, title: title, subtitle: subtitle, imageUrl: imageUrl,
        type: type, relevance: relevance,
      );
}

extension SearchSuggestionModelX on SearchSuggestionModel {
  SearchSuggestion toEntity() => SearchSuggestion(text: text, imageUrl: imageUrl, type: type);
}
