// ════════════════════════════════════════════════
// Project Lyra — Recommendation Data Models
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/recommendation_entities.dart';

part 'recommendation_models.freezed.dart';
part 'recommendation_models.g.dart';

@freezed
class RecommendationModel with _$RecommendationModel {
  const factory RecommendationModel({
    required String id,
    required String title,
    String? subtitle,
    String? imageUrl,
    required String contentType,
    required double score,
    String? reason,
    @Default({}) Map<String, dynamic> metadata,
  }) = _RecommendationModel;

  factory RecommendationModel.fromJson(Map<String, dynamic> json) => _$RecommendationModelFromJson(json);
}

@freezed
class RecommendationFeedModel with _$RecommendationFeedModel {
  const factory RecommendationFeedModel({
    @Default([]) List<RecommendationModel> items,
    String? algorithm,
    String? generatedAt,
  }) = _RecommendationFeedModel;

  factory RecommendationFeedModel.fromJson(Map<String, dynamic> json) => _$RecommendationFeedModelFromJson(json);
}

/// Entity conversion extensions.
extension RecommendationModelX on RecommendationModel {
  Recommendation toEntity() => Recommendation(
        id: id, title: title, subtitle: subtitle, imageUrl: imageUrl,
        contentType: contentType, score: score, reason: reason,
        metadata: metadata,
      );
}

extension RecommendationFeedModelX on RecommendationFeedModel {
  RecommendationFeed toEntity() => RecommendationFeed(
        items: items.map((i) => i.toEntity()).toList(),
        algorithm: algorithm,
        generatedAt: generatedAt != null ? DateTime.tryParse(generatedAt!) : null,
      );
}
