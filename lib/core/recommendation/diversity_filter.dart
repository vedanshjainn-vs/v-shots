// ════════════════════════════════════════════════
// V Shots — Recommendation Engine: Diversity (Phase 7, Part N)
// ════════════════════════════════════════════════
//
// Re-orders an already-scored, already-ranked list so no more than
// [RecommendationConfig.maxConsecutiveSameArtist] tracks from the same
// artist appear back-to-back — a real, deterministic algorithm, not a
// vague "shuffle a bit" — while preserving overall score order as
// much as possible (a lower-scored track only ever "jumps ahead" of a
// higher-scored one from the immediately-blocked artist, never an
// arbitrary reshuffle of the whole list).
// ════════════════════════════════════════════════

import 'recommendation_config.dart';
import 'recommendation_scorer.dart';

class DiversityFilter {
  DiversityFilter({this.config = RecommendationConfig.defaultConfig});

  final RecommendationConfig config;

  /// Takes a list already sorted by score (descending) and re-orders
  /// it so no artist appears more than [RecommendationConfig
  /// .maxConsecutiveSameArtist] times in a row. Uses a greedy
  /// look-ahead: when about to place a track that would violate the
  /// consecutive-artist rule, it instead looks ahead in the remaining
  /// (still score-sorted) queue for the next track from a DIFFERENT
  /// artist and promotes it — this is a real, deterministic algorithm
  /// (not a random shuffle), so the same input always produces the
  /// same diversified output (Part X's "ranking determinism"
  /// requirement, extended to diversity too).
  List<ScoredTrack> apply(List<ScoredTrack> rankedTracks) {
    if (rankedTracks.length <= config.maxConsecutiveSameArtist) {
      return rankedTracks;
    }

    final remaining = List<ScoredTrack>.from(rankedTracks);
    final result = <ScoredTrack>[];
    String? lastArtist;
    int consecutiveCount = 0;

    while (remaining.isNotEmpty) {
      // Find the highest-scored remaining track that doesn't violate
      // the consecutive-artist rule.
      int chosenIndex = 0;
      for (var i = 0; i < remaining.length; i++) {
        final candidateArtist = remaining[i].track.artist;
        final wouldViolate =
            candidateArtist == lastArtist &&
            consecutiveCount >= config.maxConsecutiveSameArtist;
        if (!wouldViolate) {
          chosenIndex = i;
          break;
        }
        // If EVERY remaining track is from the same blocked artist
        // (only possible when the whole rest of the list is one
        // artist), we have no choice but to allow it rather than
        // infinite-loop or drop tracks — diversity is a soft
        // preference, not a hard requirement that discards content.
        if (i == remaining.length - 1) chosenIndex = 0;
      }

      final chosen = remaining.removeAt(chosenIndex);
      if (chosen.track.artist == lastArtist) {
        consecutiveCount++;
      } else {
        consecutiveCount = 1;
        lastArtist = chosen.track.artist;
      }
      result.add(chosen);
    }

    return result;
  }
}
