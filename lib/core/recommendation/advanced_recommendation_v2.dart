import 'dart:math';

import '../music/music_candidate.dart';
import 'music_recommendation_context.dart';
import 'taste_profile.dart';

/// Shelf objective used by the behavior-driven ranking layer.
enum RecommendationShelf {
  madeForYou,
  becauseYouListenedTo,
  quickPicks,
  trendingForYou,
  freshDiscovery,
  discovery,
}

/// Deterministic ranking layer over the existing candidate generator.
///
/// The existing TasteProfile remains the source of truth for behavioral
/// signals. This layer adds confidence-aware weighting, short/long-term
/// intent, fatigue, diversity, novelty, freshness and shelf-specific goals.
class AdvancedRecommendationV2 {
  const AdvancedRecommendationV2._();

  static double score({
    required MusicCandidate candidate,
    required TasteProfile profile,
    required RecommendationShelf shelf,
    required MusicRecommendationContext context,
    required Map<String, int> artistCounts,
    required int candidateIndex,
  }) {
    final artist = candidate.artist.trim();
    final genre = candidate.genre.trim();
    final language = candidate.language.trim();
    final title = candidate.track.title.trim();

    final artistAffinity = _norm(profile.artistAffinity[artist], 10);
    final songAffinity = _norm(profile.songAffinity[candidate.songId], 5);
    final genreAffinity = _norm(profile.genreAffinity[genre], 10);
    final languageAffinity = _norm(profile.languageAffinity[language], 10);
    final searchArtist = _searchAffinity(profile, artist, title);
    final completion = profile.artistCompletionRate[artist] ?? 0;
    final replay = profile.artistRepeatRate[artist] ?? 0;
    final skip = _norm(profile.artistSkipPenalty[artist], 5);
    final negative = _norm(profile.negativeTaste[artist], 10);
    final recentArtist = profile.shortTermArtists.contains(artist) ? 1.0 : 0.0;
    final recentGenre = profile.shortTermGenres.contains(genre) ? 1.0 : 0.0;
    final fatigue = min(1.0, (artistCounts[artist] ?? 0) / 3.0);
    final seenPenalty = context.seenStore.penalty(candidate.songId).clamp(0.0, 1.0);

    final age = candidate.track.publishedDaysAgo;
    final freshness = age == null ? 0.35 : 1.0 / (1.0 + age / 14.0);
    final recency = age == null ? 0.45 : 1.0 / (1.0 + age / 30.0);
    final quality = 0.5;
    final novelty = 1.0 - artistAffinity;
    final sourceBoost = switch (candidate.source) {
      'trending' => 1.0,
      'new_release' => 1.0,
      'recent_artist' => 0.9,
      'favorite_artist' => 0.7,
      'similar_artist' => 0.75,
      'favorite_genre' => 0.65,
      'favorite_language' => 0.55,
      'exploration' => 0.9,
      _ => 0.35,
    };

    final maturityFactor = switch (profile.maturity) {
      TasteMaturity.cold => 0.0,
      TasteMaturity.earlySignal => 0.25,
      TasteMaturity.emerging => 0.55,
      TasteMaturity.confident => 0.80,
      TasteMaturity.mature => 1.0,
    };
    final searchFactor = profile.searchAffinity.isEmpty
        ? 0.0
        : max(0.25, profile.confidenceScores['search'] ?? 0.25);
    final personalization = max(maturityFactor, searchFactor * 0.65);
    final artistConfidence = profile.confidenceScores['artist'] ?? 0.0;
    final genreConfidence = profile.confidenceScores['genre'] ?? 0.0;
    final languageConfidence = profile.confidenceScores['language'] ?? 0.0;

    var score =
        artistAffinity * 0.24 * personalization * max(0.35, artistConfidence) +
        songAffinity * 0.10 * personalization +
        genreAffinity * 0.12 * personalization * max(0.35, genreConfidence) +
        languageAffinity * 0.08 * personalization * max(0.35, languageConfidence) +
        searchArtist * 0.12 * max(personalization, searchFactor) +
        completion * 0.08 * personalization +
        replay * 0.09 * personalization +
        recentArtist * 0.07 * personalization +
        recentGenre * 0.04 * personalization +
        freshness * 0.05 +
        recency * 0.03 +
        quality * 0.03 +
        novelty * 0.04 +
        sourceBoost * 0.04;

    switch (shelf) {
      case RecommendationShelf.madeForYou:
        score += artistAffinity * 0.08 + completion * 0.04 + replay * 0.04;
      case RecommendationShelf.becauseYouListenedTo:
        final causal = candidate.seedArtist != null &&
                profile.shortTermArtists.contains(candidate.seedArtist!.trim())
            ? 1.0
            : (recentArtist * 0.6 + artistAffinity * 0.4);
        score += causal * 0.24 + recentArtist * 0.08;
      case RecommendationShelf.quickPicks:
        score += recentArtist * 0.14 + replay * 0.08 + recency * 0.08;
      case RecommendationShelf.trendingForYou:
        score += sourceBoost * 0.10 + genreAffinity * 0.08;
      case RecommendationShelf.freshDiscovery:
        score += freshness * 0.15 + novelty * 0.10 + sourceBoost * 0.05;
      case RecommendationShelf.discovery:
        score += novelty * 0.14 + freshness * 0.10 + sourceBoost * 0.06;
    }

    // Repetition/fatigue and negative behavior are always active. One skip is
    // intentionally small; repeated skips accumulate in TasteProfile.
    score -= skip * 0.16;
    score -= negative * 0.10;
    score -= fatigue * 0.13;
    score -= seenPenalty * 0.12;

    // Deterministic tie-breaker: never inject randomness into recommendation
    // ordering, especially on cold start.
    score += max(0, 0.000001 * (1000 - candidateIndex));
    return score;
  }

  static String reason({
    required MusicCandidate candidate,
    required TasteProfile profile,
    required RecommendationShelf shelf,
  }) {
    final artist = candidate.artist.trim();
    final genre = candidate.genre.trim();
    if (profile.searchAffinity.isNotEmpty &&
        (_searchAffinity(profile, artist, candidate.track.title) > 0)) {
      return 'because_search_interest';
    }
    if (profile.shortTermArtists.contains(artist)) {
      return 'because_recently_played_artist';
    }
    if (profile.artistRepeatRate[artist] != null &&
        (profile.artistRepeatRate[artist] ?? 0) > 0.25) {
      return 'because_replay';
    }
    if ((profile.artistCompletionRate[artist] ?? 0) > 0.7) {
      return 'because_high_completion';
    }
    if (genre.isNotEmpty && (profile.genreAffinity[genre] ?? 0) > 0) {
      return shelf == RecommendationShelf.freshDiscovery
          ? 'because_favorite_genre'
          : 'because_similar_genre';
    }
    if (candidate.source == 'trending') return 'because_trending_in_preferred_genre';
    if (candidate.source == 'new_release') return 'because_fresh_release';
    if (candidate.source == 'similar_artist') return 'because_similar_artist';
    return shelf == RecommendationShelf.discovery
        ? 'because_discovery_value'
        : 'because_relevant_to_taste';
  }

  static double _norm(double? value, double divisor) {
    if (value == null || value <= 0) return 0.0;
    return (value / divisor).clamp(0.0, 1.0);
  }

  static double _searchAffinity(
    TasteProfile profile,
    String artist,
    String title,
  ) {
    final direct = profile.searchAffinity[artist] ?? 0.0;
    if (direct > 0) return _norm(direct, 6);
    final normalizedArtist = artist.toLowerCase();
    final normalizedTitle = title.toLowerCase();
    var best = 0.0;
    for (final entry in profile.searchAffinity.entries) {
      final query = entry.key.toLowerCase();
      if (query.isEmpty) continue;
      if (normalizedArtist.contains(query) ||
          normalizedTitle.contains(query) ||
          query.contains(normalizedArtist)) {
        best = max(best, entry.value);
      }
    }
    return _norm(best, 6);
  }
}
