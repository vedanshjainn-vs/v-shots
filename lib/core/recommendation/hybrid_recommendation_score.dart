// ═════════════════════════════════════════════════════════════════════════
// V Shots — HybridRecommendationScore
//
// The final scoring model. Combines explicit/behavioral taste, language,
// country, freshness, popularity, vibe, and exploration into one weighted
// score, then applies penalties (duplicate, artist repetition, recently played,
// skip, wrong language, stale). All weights configurable (Phase 2 dynamic
// weighting) so behavior grows stronger than onboarding over time.
// ═════════════════════════════════════════════════════════════════════════

import '../providers/provider_models.dart';

/// A scored candidate plus a human-readable reason.
class HybridScoredTrack {
  const HybridScoredTrack({
    required this.track,
    required this.score,
    required this.reason,
    this.tasteScore = 0,
    this.similarityScore = 0,
    this.behaviorScore = 0,
    this.freshnessScore = 0,
  });

  final ProviderTrack track;
  final double score;
  final String reason;
  final double tasteScore;
  final double similarityScore;
  final double behaviorScore;
  final double freshnessScore;
}

class HybridRecommendationScore {
  HybridRecommendationScore({
    this.tasteWeight = 0.25,
    this.similarityWeight = 0.20,
    this.behaviorWeight = 0.15,
    this.languageWeight = 0.10,
    this.countryWeight = 0.05,
    this.freshnessWeight = 0.10,
    this.popularityWeight = 0.05,
    this.vibeWeight = 0.05,
    this.explorationWeight = 0.05,
  }) {
    // Phase 14: weights must sum exactly to 1.0. Validate at construction so a
    // config typo is caught immediately, never silently mis-scores.
    final sum = tasteWeight +
        similarityWeight +
        behaviorWeight +
        languageWeight +
        countryWeight +
        freshnessWeight +
        popularityWeight +
        vibeWeight +
        explorationWeight;
    assert((sum - 1.0).abs() < 0.001,
        'HybridRecommendationScore weights must sum to 1.0 (got $sum)');
  }

  final double tasteWeight;
  final double similarityWeight;
  final double behaviorWeight;
  final double languageWeight;
  final double countryWeight;
  final double freshnessWeight;
  final double popularityWeight;
  final double vibeWeight;
  final double explorationWeight;

  /// Computes a weighted score in [0,1]. Component scores are expected in
  /// [0,1]. `penalties` are subtracted before final clamp.
  double score({
    required double taste,
    required double similarity,
    required double behavior,
    required double language,
    required double country,
    required double freshness,
    required double popularity,
    required double vibe,
    required double exploration,
    double penalty = 0,
  }) {
    double s = 0;
    s += taste * tasteWeight;
    s += similarity * similarityWeight;
    s += behavior * behaviorWeight;
    s += language * languageWeight;
    s += country * countryWeight;
    s += freshness * freshnessWeight;
    s += popularity * popularityWeight;
    s += vibe * vibeWeight;
    s += exploration * explorationWeight;
    s -= penalty;
    return s.clamp(0.0, 1.0);
  }

  /// Freshness score from published-at age (Phase 14).
  static double freshnessScore(DateTime? publishedAt) {
    if (publishedAt == null) return 0.5; // unknown -> neutral
    final days = DateTime.now().difference(publishedAt).inDays;
    if (days < 1) return 1.0;
    if (days < 3) return 0.95;
    if (days < 7) return 0.85;
    if (days < 14) return 0.70;
    if (days < 30) return 0.50;
    if (days < 90) return 0.25;
    return 0.10;
  }

  /// Builds a deterministic, human-readable reason (Phase 18) without an LLM.
  static String buildReason({
    required double taste,
    required double similarity,
    required double freshness,
    required String? artist,
    required String language,
  }) {
    if (taste > 0.6) return 'Because you listen to ${artist ?? 'this style'}';
    if (similarity > 0.5) return 'Similar mood to your recent songs';
    if (freshness > 0.7) return 'New $language release matching your taste';
    return 'Discovery matching your preferences';
  }
}
