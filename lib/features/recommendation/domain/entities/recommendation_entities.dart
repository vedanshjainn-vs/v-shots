// ════════════════════════════════════════════════
// Project Lyra — Recommendation Entities
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'recommendation_entities.freezed.dart';
part 'recommendation_entities.g.dart';

@freezed
class Recommendation with _$Recommendation {
  const factory Recommendation({
    required String id,
    required String title,
    String? subtitle,
    String? imageUrl,
    required String contentType,
    required double score,
    String? reason,
    @Default({}) Map<String, dynamic> metadata,
  }) = _Recommendation;

  factory Recommendation.fromJson(Map<String, dynamic> json) => _$RecommendationFromJson(json);
}

@freezed
class RecommendationFeed with _$RecommendationFeed {
  const factory RecommendationFeed({
    required List<Recommendation> items,
    String? algorithm,
    DateTime? generatedAt,
  }) = _RecommendationFeed;

  factory RecommendationFeed.fromJson(Map<String, dynamic> json) => _$RecommendationFeedFromJson(json);
}

@freezed
class RecommendationContext with _$RecommendationContext {
  const factory RecommendationContext({
    String? mood,
    String? activity,
    @Default([]) List<String> recentGenres,
    @Default([]) List<String> recentArtists,
    @Default(20) int limit,
  }) = _RecommendationContext;

  factory RecommendationContext.fromJson(Map<String, dynamic> json) => _$RecommendationContextFromJson(json);
}
