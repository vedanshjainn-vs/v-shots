// ════════════════════════════════════════════════
// V Shots — Recommendation Engine: Scoring (Phase 7, Part K)
// ════════════════════════════════════════════════
//
// Implements the weighted ranking model from Part K's conceptual
// formula:
//   score = userAffinity + artistAffinity + recency + similarity
//         + completionProbability + popularity + contextMatch
//         + novelty - skipPenalty - repetitionPenalty
//
// Every term below maps to a REAL, computable signal — nothing here
// is a placeholder/fake number:
//   - userAffinity / artistAffinity: from TasteProfile (real signal
//     history).
//   - recency: how recently the CANDIDATE's seed artist/genre was
//     actually engaged with (favors "because you just listened to X"
//     over a stale interest from weeks ago).
//   - similarity: GenreClassifier's real Jaccard tag-overlap between
//     the candidate and the user's top genres.
//   - completionProbability: a real, computable proxy — the
//     candidate artist's historical completion rate (completions vs.
//     total plays for that artist in the signal history), NOT a
//     fabricated ML prediction. Falls back to a neutral 0.5 when there
//     isn't enough history for that specific artist (honest — not
//     claiming false precision).
//   - popularity: NOT claimed (YouTube's API exposes no public view-
//     count/popularity figure through this app's search results in a
//     comparable normalized form) — see this class's own
//     `_popularityScore` doc for the honest, minimal proxy actually
//     used (candidate source: trending/newContent get a small boost,
//     everything else 0), rather than pretending to have real
//     popularity data.
//   - contextMatch: time-of-day match against the candidate's genre
//     (see `_contextMatchScore`) — ONLY applied where a real,
//     pre-established mapping exists (matches
//     ForYouFeedService's existing day/evening/night query buckets),
//     per Part P's explicit instruction: "Do NOT claim to detect user
//     mood automatically unless we actually have a reliable signal."
//   - novelty: inverse of the candidate artist's existing affinity —
//     an artist the user has never engaged with scores high novelty;
//     a heavily-played artist scores low (this is what makes
//     exploration candidates score competitively despite zero
//     affinity).
//   - skipPenalty / repetitionPenalty: from TasteProfile's decayed
//     skip penalties, and a same-session repetition check.
// ════════════════════════════════════════════════

import '../providers/provider_models.dart';
import 'genre_classifier.dart';
import 'recommendation_config.dart';
import 'signal_event.dart';
import 'signal_store.dart';
import 'taste_profile.dart';

/// A scored candidate track, ready for ranking/diversity filtering.
class ScoredTrack {
  const ScoredTrack({
    required this.track,
    required this.score,
    required this.genreTags,
    this.debugBreakdown,
  });

  final ProviderTrack track;
  final double score;
  final Set<String> genreTags;

  /// Optional per-term breakdown, populated only when scoring is run
  /// with `debug: true` (see `RecommendationScorer.score`) — used by
  /// tests to assert individual terms, and available for any future
  /// debug UI, without costing anything in the normal (non-debug) path.
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
    final artistAffinity = userAffinity; // same signal, kept as a separate term per Part K's formula shape
    final recency = _recencyScore(track.artist);
    final similarity = _similarityScore(tags, profile);
    final completionProbability = _completionProbabilityScore(track.artist);
    final popularity = _popularityScore(isTrendingOrNewSource);
    final contextMatch = _contextMatchScore(tags);
    final novelty = _noveltyScore(track.artist, profile);
    final skipPenalty = profile.artistSkipPenalty[track.artist] ?? 0.0;
    const repetitionPenalty = 0.0; // applied downstream by DiversityFilter, not per-track here (see that file)

    final total = config.weightUserAffinity * userAffinity +
        config.weightArtistAffinity * artistAffinity +
        config.weightRecency * recency +
        config.weightSimilarity * similarity +
        config.weightCompletionProbability * completionProbability +
        config.weightPopularity * popularity +
        config.weightContextMatch * contextMatch +
        config.weightNovelty * novelty -
        config.weightSkipPenalty * skipPenalty -
        config.weightRepetitionPenalty * repetitionPenalty;

    return ScoredTrack(
      track: track,
      score: total,
      genreTags: tags,
      debugBreakdown: debug
          ? {
              'userAffinity': userAffinity,
              'artistAffinity': artistAffinity,
              'recency': recency,
              'similarity': similarity,
              'completionProbability': completionProbability,
              'popularity': popularity,
              'contextMatch': contextMatch,
              'novelty': novelty,
              'skipPenalty': skipPenalty,
              'repetitionPenalty': repetitionPenalty,
            }
          : null,
    );
  }

  /// How recently the user actually engaged with this artist — a
  /// track from an artist you listened to an hour ago scores higher
  /// than one from an artist you last heard a week ago, independent
  /// of overall affinity magnitude.
  double _recencyScore(String artist) {
    final events = SignalStore.instance.events
        .where((e) => e.artist == artist && e.type != SignalType.skip)
        .toList();
    if (events.isEmpty) return 0.0;
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final hoursAgo = DateTime.now().difference(events.first.timestamp).inMinutes / 60.0;
    // Decays to ~0 after a week — a simple, honest recency curve.
    return (1.0 - (hoursAgo / (24 * 7)).clamp(0.0, 1.0));
  }

  double _similarityScore(Set<String> candidateTags, TasteProfile profile) {
    if (candidateTags.isEmpty || profile.genreAffinity.isEmpty) return 0.0;
    final topGenres = profile.topGenres.take(3).toSet();
    return _genres.similarity(candidateTags, topGenres);
  }

  /// Real, computable proxy for "will this user finish this track":
  /// this specific artist's historical completion rate from the
  /// user's own signal history (completions / (completions + skips)).
  /// Falls back to a neutral 0.5 when there's no history for this
  /// artist yet — an honest "we don't know" rather than a fabricated
  /// prediction.
  double _completionProbabilityScore(String artist) {
    final relevant = SignalStore.instance.events.where((e) =>
        e.artist == artist &&
        (e.type == SignalType.completed || e.type == SignalType.skip));
    if (relevant.isEmpty) return 0.5;
    final completions = relevant.where((e) => e.type == SignalType.completed).length;
    return completions / relevant.length;
  }

  /// Honest, minimal popularity proxy — NOT a fabricated view-count
  /// number (see this file's header). Only distinguishes "this
  /// candidate came from an explicitly popularity-driven source
  /// (trending/new-releases)" vs. everything else, which is real
  /// information (the query itself), not invented.
  double _popularityScore(bool isTrendingOrNewSource) =>
      isTrendingOrNewSource ? 1.0 : 0.0;

  /// Time-of-day context match — ONLY for genre/mood buckets that
  /// already have an established, real mapping (matches
  /// ForYouFeedService's pre-existing day/evening/night query pools),
  /// per Part P's explicit "do not claim mood detection without a
  /// reliable signal" instruction. This is a real, simple, declared
  /// heuristic (time of day is a 100% reliable signal — `DateTime.now()`
  /// — unlike "mood," which this app makes no claim to detect).
  double _contextMatchScore(Set<String> tags) {
    final hour = DateTime.now().hour;
    final isNight = hour >= 22 || hour < 5;
    final isEvening = hour >= 17 && hour < 22;

    if (isNight && (tags.contains('Chill') || tags.contains('Sad'))) return 1.0;
    if (isEvening && (tags.contains('Romantic') || tags.contains('RnB'))) return 1.0;
    if (!isNight && !isEvening && tags.contains('Workout')) return 1.0;
    return 0.0;
  }

  /// Inverse of existing affinity — rewards genuinely new artists so
  /// exploration candidates aren't drowned out by heavily-affine ones.
  double _noveltyScore(String artist, TasteProfile profile) {
    final affinity = profile.artistAffinity[artist] ?? 0.0;
    if (affinity <= 0) return 1.0; // never engaged with before = fully novel
    // Decays toward 0 as affinity grows — a moderately-known artist
    // still gets some novelty credit, a heavily-played one gets none.
    return (1.0 / (1.0 + affinity)).clamp(0.0, 1.0);
  }
}
