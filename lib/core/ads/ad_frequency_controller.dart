// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Frequency Controller
//
// Centralized cooldown/cap enforcement for interrupting ad formats
// (interstitials). Native in-feed placements are cadence-based (index
// spacing) and do not use this controller.
//
// Rules (conservative defaults, configurable for testing):
//   1. Minimum interval between interstitials: 180 s (2–3 min window).
//   2. Maximum interstitials per app session: 4.
//   3. Minimum foreground dwell time before the first interstitial: 60 s —
//      an interstitial can never fire "immediately on app launch".
//
// Pure Dart / no SDK calls — fully unit-testable.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

class AdFrequencyController {
  AdFrequencyController({
    this.minInterval = const Duration(minutes: 3),
    this.maxPerSession = 4,
    this.minDwell = const Duration(minutes: 1),
    DateTime? appStartedAt,
  }) : _appStartedAt = appStartedAt ?? DateTime.now();

  /// Minimum time between two interstitial presentations.
  final Duration minInterval;

  /// Hard cap per app run (reset when the app process restarts).
  final int maxPerSession;

  /// The app must have been in the foreground for at least this long before
  /// any interstitial may show (no launch-time ads).
  final Duration minDwell;

  final DateTime _appStartedAt;

  DateTime? _lastShownAt;
  int _shownThisSession = 0;

  /// How many interstitials have been shown this session.
  int get shownThisSession => _shownThisSession;

  /// Whether an interstitial is allowed RIGHT NOW under cooldown + caps +
  /// dwell rules. Does NOT consume the budget — call [recordShown] only when
  /// the ad is actually presented.
  bool canShow({DateTime? now}) {
    final t = now ?? DateTime.now();
    if (_shownThisSession >= maxPerSession) return false;
    final dwell = t.difference(_appStartedAt);
    if (dwell < minDwell) return false;
    final last = _lastShownAt;
    if (last != null && t.difference(last) < minInterval) return false;
    return true;
  }

  /// Records a successfully presented interstitial.
  void recordShown({DateTime? now}) {
    _lastShownAt = now ?? DateTime.now();
    _shownThisSession++;
  }

  /// Test/diagnostics helper: clears all counters.
  @visibleForTesting
  void reset() {
    _lastShownAt = null;
    _shownThisSession = 0;
  }
}
