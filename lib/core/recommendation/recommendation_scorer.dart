// ═════════════════════════════════════════════════════════════════════════
// V Shots — Recommendation Engine: Scoring (V2 Engine)
// ═════════════════════════════════════════════════════════════════════════
//
// Multi-objective weighted ranking model:
//   Score = UserAffinity + ArtistAffinity + SearchAffinity + GenreAffinity
//         + LanguageAffinity + Recency + Similarity + CompletionProbability
//         + ReplaySignal + Popularity + ContextMatch + Novelty + OfficialBoost
//         + Freshness - SkipPenalty - RepetitionPenalty
// ═════════════════════════════════════════════════════════════════════════

import 'dart:math';

import '../providers/provider_models.dart';
import 'genre_classifier.dart';
import 'recommendation_config.dart';
import 'signal_event.dart';
import 'signal_store.dart';
import 'taste_profile.dart';

/// A scored candidate track with full metadata and explainable reason.
class ScoredTrack {
  const ScoredTrack({
    required this.track,
    required this.score,
    required this.genreTags,
    this.reason,
    this.debugBreakdown,
  });

  final ProviderTrack track;
  final double score;
  final Set<String> genreTags;
  final String? reason;
  final Map<String, double>? debugBreakdown;
}

class RecommendationScorer {
  RecommendationScorer({
    this.config = RecommendationConfig.defaultConfig,
    GenreClassifier? genreClassifier,
  }) : _genres = genreClassifier ?? GenreClassifier.instance;

  final RecommendationConfig config;
  final GenreClassifier _genres;

  ScoredTrack score(
    ProviderTrack track,
    TasteProfile profile, {
    required String? sourceQuery,
    required bool isTrendingOrNewSource,
    bool debug = false,
  }) {
    final tags = _genres.classify(
      title: track.title,
      artist: track.artist,
      sourceQuery: sourceQuery,
    );

    final userAffinity = profile.artistAffinity[track.artist] ?? 0.0;
    final artistAffinity = userAffinity;

    // Search affinity: check if candidate artist or title matches recent search queries
    final searchAffinity = _searchAffinityScore(track, profile);

    // Genre & Language affinities
    final genreAffinity = _genreAffinityScore(tags, profile);
    final languageAffinity = _languageAffinityScore(track, profile);

    final recency = _recencyScore(track.artist);
    final similarity = _similarityScore(tags, profile);
    final completionProbability = _completionProbabilityScore(track.artist, profile);
    final replaySignal = profile.artistRepeatRate[track.artist] ?? 0.0;
    final popularity = _popularityScore(isTrendingOrNewSource);
    final contextMatch = _contextMatchScore(tags);
    final novelty = _noveltyScore(track.artist, profile);
    final officialBoost = track.isOfficial ? 1.0 : 0.0;
    final freshness = isTrendingOrNewSource ? 0.8 : 0.4;
    final skipPenalty = profile.artistSkipPenalty[track.artist] ?? 0.0;
    const repetitionPenalty = 0.0;

    final total = config.weightUserAffinity * userAffinity +
        config.weightArtistAffinity * artistAffinity +
        config.weightSearchAffinity * searchAffinity +
        config.weightGenreAffinity * genreAffinity +
        config.weightLanguageAffinity * languageAffinity +
        config.weightRecency * recency +
        config.weightSimilarity * similarity +
        config.weightCompletionProbability * completionProbability +
        config.weightReplaySignal * replaySignal +
        config.weightPopularity * popularity +
        config.weightContextMatch * contextMatch +
        config.weightNovelty * novelty +
        config.weightOfficialBoost * officialBoost +
        config.weightFreshness * freshness -
        config.weightSkipPenalty * skipPenalty -
        config.weightRepetitionPenalty * repetitionPenalty;

    final reason = _determineReason(
      track,
      profile,
      tags,
      isTrendingOrNewSource: isTrendingOrNewSource,
      searchAffinity: searchAffinity,
      completionRate: completionProbability,
      replaySignal: replaySignal,
    );

    return ScoredTrack(
      track: track,
      score: total,
      genreTags: tags,
      reason: reason,
      debugBreakdown: debug
          ? {
              'userAffinity': userAffinity,
              'artistAffinity': artistAffinity,
              'searchAffinity': searchAffinity,
              'genreAffinity': genreAffinity,
              'languageAffinity': languageAffinity,
              'recency': recency,
              'similarity': similarity,
              'completionProbability': completionProbability,
              'replaySignal': replaySignal,
              'popularity': popularity,
              'contextMatch': contextMatch,
              'novelty': novelty,
              'officialBoost': officialBoost,
              'freshness': freshness,
              'skipPenalty': skipPenalty,
              'repetitionPenalty': repetitionPenalty,
            }
          : null,
    );
  }

  double _searchAffinityScore(ProviderTrack track, TasteProfile profile) {
    if (profile.searchAffinity.isEmpty) return 0.0;
    final artistLower = track.artist.toLowerCase();
    final titleLower = track.title.toLowerCase();
    for (final entry in profile.searchAffinity.entries) {
      final q = entry.key.toLowerCase();
      if (artistLower.contains(q) || titleLower.contains(q) || q.contains(artistLower)) {
        return min(3.0, entry.value / 4.0);
      }
    }
    return 0.0;
  }

  double _genreAffinityScore(Set<String> tags, TasteProfile profile) {
    if (tags.isEmpty || profile.genreAffinity.isEmpty) return 0.0;
    var sum = 0.0;
    for (final tag in tags) {
      sum += profile.genreAffinity[tag] ?? 0.0;
    }
    return min(2.5, sum / 5.0);
  }

  double _languageAffinityScore(ProviderTrack track, TasteProfile profile) {
    if (profile.languageAffinity.isEmpty) return 0.0;
    final text = '${track.title} ${track.artist}';
    final detected = _genres.detectLanguages(text);
    var sum = 0.0;
    for (final lang in detected) {
      sum += profile.languageAffinity[lang] ?? 0.0;
    }
    return min(2.0, sum / 5.0);
  }

  double _recencyScore(String artist) {
    final events = SignalStore.instance.events
        .where((e) => e.artist == artist && e.type != SignalType.skip)
        .toList();
    if (events.isEmpty) return 0.0;
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final hoursAgo =
        DateTime.now().difference(events.first.timestamp).inMinutes / 60.0;
    return (1.0 - (hoursAgo / (24 * 7)).clamp(0.0, 1.0));
  }

  double _similarityScore(Set<String> candidateTags, TasteProfile profile) {
    if (candidateTags.isEmpty || profile.genreAffinity.isEmpty) return 0.0;
    final topGenres = profile.topGenres.take(3).toSet();
    return _genres.similarity(candidateTags, topGenres);
  }

  double _completionProbabilityScore(String artist, TasteProfile profile) {
    final recorded = profile.artistCompletionRate[artist];
    if (recorded != null) return recorded;
    final relevant = SignalStore.instance.events.where(
      (e) =>
          e.artist == artist &&
          (e.type == SignalType.completed || e.type == SignalType.skip),
    );
    if (relevant.isEmpty) return 0.5;
    final completions =
        relevant.where((e) => e.type == SignalType.completed).length;
    return completions / relevant.length;
  }

  double _popularityScore(bool isTrendingOrNewSource) =>
      isTrendingOrNewSource ? 1.0 : 0.0;

  double _contextMatchScore(Set<String> tags) {
    final hour = DateTime.now().hour;
    final isNight = hour >= 22 || hour < 5;
    final isEvening = hour >= 17 && hour < 22;

    if (isNight && (tags.contains('Chill') || tags.contains('Sad'))) {
      return 1.0;
    }
    if (isEvening && (tags.contains('Romantic') || tags.contains('RnB'))) {
      return 1.0;
    }
    if (!isNight && !isEvening && tags.contains('Workout')) {
      return 1.0;
    }
    return 0.0;
  }

  double _noveltyScore(String artist, TasteProfile profile) {
    final affinity = profile.artistAffinity[artist] ?? 0.0;
    if (affinity <= 0) return 1.0;
    return (1.0 / (1.0 + affinity)).clamp(0.0, 1.0);
  }

  String _determineReason(
    ProviderTrack track,
    TasteProfile profile,
    Set<String> tags, {
    required bool isTrendingOrNewSource,
    required double searchAffinity,
    required double completionRate,
    required double replaySignal,
  }) {
    if (searchAffinity > 0.5) {
      return 'because_search_interest';
    }
    if (replaySignal > 0.3) {
      return 'because_frequently_replayed';
    }
    final artistAffinity = profile.artistAffinity[track.artist] ?? 0.0;
    if (artistAffinity > 3.0) {
      return 'because_recently_played_artist';
    }
    if (completionRate > 0.75) {
      return 'because_high_completion';
    }
    if (tags.any(profile.topGenres.take(2).contains)) {
      return 'because_favorite_genre';
    }
    if (isTrendingOrNewSource) {
      return 'because_trending_in_preferred_genre';
    }
    return 'similar_to_your_taste';
  }
}
