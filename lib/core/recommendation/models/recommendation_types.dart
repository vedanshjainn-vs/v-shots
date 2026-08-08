// ════════════════════════════════════════════════
// Project Lyra — Recommendation Types
// ════════════════════════════════════════════════
//
// Data models for the recommendation engine.
// Interfaces only — no implementation yet.
// ════════════════════════════════════════════════

import '../../enums/content_type.dart';

/// Context for generating recommendations.
class RecommendationContext {
  const RecommendationContext({
    this.userId,
    this.currentTime,
    this.mood,
    this.activity,
    this.recentlyPlayed = const [],
    this.likedGenres = const [],
    this.likedArtists = const [],
    this.excludeIds = const [],
    this.limit = 20,
    this.metadata = const {},
  });

  final String? userId;
  final DateTime? currentTime;
  final String? mood;
  final String? activity;
  final List<String> recentlyPlayed;
  final List<String> likedGenres;
  final List<String> likedArtists;
  final List<String> excludeIds;
  final int limit;
  final Map<String, dynamic> metadata;
}

/// A single recommended item.
class RecommendedItem {
  const RecommendedItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.artUrl,
    required this.score,
    this.reason,
    this.metadata = const {},
  });

  final String id;
  final ContentType type;
  final String title;
  final String? subtitle;
  final String? artUrl;
  final double score;
  final String? reason;
  final Map<String, dynamic> metadata;
}

/// Result of a recommendation request.
class RecommendationResult {
  const RecommendationResult({
    required this.items,
    this.algorithm,
    this.context,
    this.metadata = const {},
  });

  final List<RecommendedItem> items;
  final String? algorithm;
  final RecommendationContext? context;
  final Map<String, dynamic> metadata;

  bool get isEmpty => items.isEmpty;
  int get count => items.length;
}

/// Strategy for generating recommendations.
enum RecommendationStrategy {
  /// Content-based filtering (similar items).
  contentBased,

  /// Collaborative filtering (users like you).
  collaborative,

  /// AI-powered (LLM-based).
  aiPowered,

  /// Trending/popular items.
  trending,

  /// Editorial/curated.
  curated,

  /// Hybrid (combination of strategies).
  hybrid,
}

/// Interface for recommendation service.
abstract class RecommendationService {
  /// Get personalized recommendations.
  Future<RecommendationResult> getRecommendations(RecommendationContext context);

  /// Get similar items to a given item.
  Future<RecommendationResult> getSimilar({
    required String itemId,
    required ContentType itemType,
    int limit = 10,
  });

  /// Get trending items.
  Future<RecommendationResult> getTrending({
    ContentType? type,
    String? genre,
    int limit = 20,
  });

  /// Get items for the user's "For You" feed.
  Future<RecommendationResult> getForYouFeed({
    required String userId,
    int page = 1,
    int limit = 20,
  });
}

/// Interface for feed ranking engine.
abstract class FeedRankingEngine {
  /// Rank a list of items for the user's feed.
  Future<List<RecommendedItem>> rank({
    required List<RecommendedItem> items,
    required RecommendationContext context,
  });

  /// Re-rank items based on user interaction.
  Future<List<RecommendedItem>> reRank({
    required List<RecommendedItem> items,
    required String interactionType,
    required String interactionTargetId,
  });
}
