// ════════════════════════════════════════════════
// V Shots — Recommendation Engine: Taste Profile (Phase 7, Parts I/K)
// ════════════════════════════════════════════════
//
// Derives ARTIST_AFFINITY, GENRE_AFFINITY, and per-artist SKIP
// PENALTY from the raw `SignalEvent` history in `SignalStore` — this
// is the "Feature Extraction" stage of the pipeline diagram in Part H.
//
// WEIGHTING (per Part I's explicit examples):
//   completed track     = strong positive
//   long listen         = positive (proportional to playDuration)
//   replay              = strong positive
//   like                = very strong positive
//   immediate skip      = negative
//   repeated skips of the same artist = strong negative, but DECAYS
//     (half-life, not permanent) — Part I: "Do not permanently punish
//     an artist based on one skip."
//
// All decay uses the same recency-half-life pattern
// ForYouFeedService v2 already established (`pow(0.5, hoursAgo /
// halfLife)`) — kept consistent with existing, working code rather
// than inventing a different decay function.
// ════════════════════════════════════════════════

import 'dart:math';

import 'genre_classifier.dart';
import 'recommendation_config.dart';
import 'signal_event.dart';
import 'signal_store.dart';

/// A snapshot of the user's derived taste — artist scores, genre
/// scores, and skip penalties — computed fresh from `SignalStore`'s
/// event history. Deliberately a plain data class (not a singleton
/// with mutable state) so it can be computed once per
/// recommendation-refresh and reused across the scoring pass without
/// recomputing per-candidate (Part S: "Do not calculate the entire
/// feed every rebuild").
class TasteProfile {
  const TasteProfile({
    required this.artistAffinity,
    required this.genreAffinity,
    required this.artistSkipPenalty,
    required this.totalSignalCount,
  });

  final Map<String, double> artistAffinity;
  final Map<String, double> genreAffinity;
  final Map<String, double> artistSkipPenalty;
  final int totalSignalCount;

  bool get hasEnoughHistoryForPersonalization => totalSignalCount >= 3;

  static const empty = TasteProfile(
    artistAffinity: {},
    genreAffinity: {},
    artistSkipPenalty: {},
    totalSignalCount: 0,
  );

  List<String> get topArtists {
    final sorted = artistAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  List<String> get topGenres {
    final sorted = genreAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }
}

class TasteProfileBuilder {
  TasteProfileBuilder({
    this.config = RecommendationConfig.defaultConfig,
    GenreClassifier? genreClassifier,
  }) : _genres = genreClassifier ?? GenreClassifier.instance;

  final RecommendationConfig config;
  final GenreClassifier _genres;

  /// Builds a [TasteProfile] from [events] (defaults to
  /// `SignalStore.instance.events` — parameterized for testability
  /// without touching real shared_preferences-backed storage).
  TasteProfile build({List<SignalEvent>? events}) {
    final signals = events ?? SignalStore.instance.events;
    if (signals.isEmpty) return TasteProfile.empty;

    final now = DateTime.now();
    final artistAffinity = <String, double>{};
    final genreAffinity = <String, double>{};
    final artistSkipPenalty = <String, double>{};

    for (final event in signals) {
      final hoursAgo = now.difference(event.timestamp).inMinutes / 60.0;
      final affinityDecay = pow(
        0.5,
        hoursAgo / config.affinityHalfLifeHours,
      ).toDouble();
      final skipDecay = pow(
        0.5,
        hoursAgo / config.skipPenaltyHalfLifeHours,
      ).toDouble();

      final artist = event.artist;
      final weight = _weightFor(event);

      if (artist != null && artist.isNotEmpty) {
        if (event.type == SignalType.skip) {
          // Skip penalty tracked SEPARATELY from positive affinity
          // (not just a negative addition to the same accumulator) so
          // scoring can weigh "affinity" and "skip penalty" with
          // independently configurable weights (see
          // RecommendationConfig.weightSkipPenalty) — matches Part K's
          // scoring formula having them as distinct terms.
          artistSkipPenalty[artist] =
              (artistSkipPenalty[artist] ?? 0) + weight.abs() * skipDecay;
        } else {
          artistAffinity[artist] =
              (artistAffinity[artist] ?? 0) + weight * affinityDecay;
        }

        if (event.title != null) {
          final tags = _genres.classify(title: event.title!, artist: artist);
          for (final tag in tags) {
            final genreWeight = event.type == SignalType.skip
                ? -weight.abs() *
                    skipDecay *
                    0.5 // skips dampen genre affinity less aggressively than artist affinity
                : weight * affinityDecay;
            genreAffinity[tag] = (genreAffinity[tag] ?? 0) + genreWeight;
          }
        }
      }
    }

    // Genre scores can go slightly negative from skip dampening —
    // clamp at 0 since "negative interest in a genre" isn't a
    // meaningful concept the way "negative interest in one specific
    // artist" (a real skip penalty) is.
    genreAffinity.updateAll((key, value) => max(0, value));

    return TasteProfile(
      artistAffinity: artistAffinity,
      genreAffinity: genreAffinity,
      artistSkipPenalty: artistSkipPenalty,
      totalSignalCount: signals.length,
    );
  }

  /// Per-event-type base weight — the concrete numbers behind Part I's
  /// qualitative examples ("completed = strong positive", "like = very
  /// strong positive", etc.).
  double _weightFor(SignalEvent event) {
    switch (event.type) {
      case SignalType.like:
        return 5.0; // very strong positive
      case SignalType.replay:
        return 4.0; // strong positive
      case SignalType.completed:
        return 3.0; // strong positive
      case SignalType.addToPlaylist:
        return 3.5; // deliberate curation action, strong positive
      case SignalType.playDuration:
        // Positive, proportional to how long they listened (capped at
        // 3.0 for a full ~3min+ listen) — "long listen = positive".
        final seconds = event.value ?? 0;
        return min(3.0, seconds / 60.0);
      case SignalType.play:
        return 1.0; // baseline positive (a play was at least started)
      case SignalType.unlike:
        return -1.0; // mild negative, not punitive
      case SignalType.removeFromPlaylist:
        return -0.5; // mild negative
      case SignalType.skip:
        // Magnitude depends on HOW FAST the skip happened — an
        // immediate skip (<10s) is a much stronger negative signal
        // than a skip near the end of a track (which might just mean
        // "I was done listening," not "I disliked this").
        final secondsListened = event.value ?? 0;
        if (secondsListened < 10) return -2.5; // immediate skip
        if (secondsListened < 30) return -1.5;
        return -0.5; // skipped late — weak negative
      case SignalType.search:
        return 0.0; // search signals feed query-pattern analysis elsewhere, not artist affinity directly
    }
  }
}
