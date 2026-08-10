// ════════════════════════════════════════════════
// V Shots — Recommendation Engine: Quality metrics hooks (Phase 7, Part R)
// ════════════════════════════════════════════════
//
// Per the task's explicit instruction ("Track metrics: CTR, play-start
// rate, completion rate, skip rate, like rate, repeat rate, artist
// diversity, recommendation diversity... Do NOT add analytics SDK just
// for this phase. Create internal event models/hooks so analytics can
// be connected later"):
//
// This is ONLY an internal hook/event-model layer — `RecommendationMetricsSink`
// is an interface any future analytics backend (Firebase Analytics,
// a custom Supabase table, etc.) could implement; `NoopMetricsSink` is
// the only implementation that ships in this phase, and it does
// nothing but log to console in debug mode. No SDK, no network call,
// no data collection is actually wired up — this satisfies "create
// hooks," not "add analytics."
// ════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

/// One measurable recommendation-quality event.
enum MetricEvent {
  impression, // a recommended track was shown to the user
  ctr, // the user tapped/played a shown recommendation
  playStart,
  completion,
  skip,
  like,
  repeat,
}

abstract class RecommendationMetricsSink {
  void record(MetricEvent event,
      {required String trackId, Map<String, dynamic>? extra});

  /// Called once per generated feed batch — lets a future sink compute
  /// artist/recommendation diversity for that batch without this
  /// engine needing to know HOW that's stored/reported.
  void recordBatchDiversity({
    required int totalTracks,
    required int distinctArtists,
    required double explorationFraction,
  });
}

/// The only sink wired up in this phase — logs to console in debug
/// builds only, records nothing, sends nothing anywhere. Real per-user
/// analytics (if ever added) would implement
/// [RecommendationMetricsSink] and be swapped in via
/// [RecommendationMetrics.sink] — no other code in this engine would
/// need to change.
class NoopMetricsSink implements RecommendationMetricsSink {
  const NoopMetricsSink();

  @override
  void record(MetricEvent event,
      {required String trackId, Map<String, dynamic>? extra}) {
    if (kDebugMode) {
      debugPrint(
          '[RecommendationMetrics] ${event.name} trackId=$trackId extra=$extra');
    }
  }

  @override
  void recordBatchDiversity({
    required int totalTracks,
    required int distinctArtists,
    required double explorationFraction,
  }) {
    if (kDebugMode) {
      debugPrint(
        '[RecommendationMetrics] batch: $totalTracks tracks, '
        '$distinctArtists distinct artists, '
        '${(explorationFraction * 100).toStringAsFixed(0)}% exploration',
      );
    }
  }
}

class RecommendationMetrics {
  RecommendationMetrics._();

  /// Swappable sink — defaults to [NoopMetricsSink]. A future session
  /// could assign a real sink here without touching
  /// RecommendationEngine's own code.
  static RecommendationMetricsSink sink = const NoopMetricsSink();
}
