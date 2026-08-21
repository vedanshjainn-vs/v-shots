// ════════════════════════════════════════════════
// V Shots — Recommendation Engine: User Signals (Phase 7, Part I)
// ════════════════════════════════════════════════
//
// WHY THIS FILE EXISTS:
// The pre-Phase-7 recommendation logic (ForYouFeedService v1/v2, see
// that file's own revision history) only ever used ONE real signal:
// LocalLibrary's `recentlyPlayed` list (id/title/artist/playedAt).
// There was no signal for skips, completion, likes, playlist actions,
// or replays — "recommendation quality" was entirely a function of
// "did the user press play," which conflates a track someone
// immediately skipped with one they listened to in full.
//
// This file defines the real signal vocabulary the rest of the
// recommendation pipeline (candidate generation, scoring, diversity)
// consumes. Every `SignalType` below is either:
//   (a) already capturable from real, existing app behavior (PLAY,
//       LIKE, UNLIKE, SEARCH, ADD_TO_PLAYLIST, REMOVE_FROM_PLAYLIST —
//       these all already have a real call site somewhere in the app,
//       e.g. LocalLibrary.toggleLiked()), or
//   (b) newly instrumented in this phase (SKIP, COMPLETED,
//       PLAY_DURATION, REPLAY — see signal_recorder.dart for exactly
//       where these are now recorded in main.dart's real playback
//       code).
// ARTIST_AFFINITY/GENRE_AFFINITY/TIME_OF_DAY/SESSION_CONTEXT are NOT
// raw signal types recorded per-event — they are DERIVED from the
// signals below (see taste_profile.dart) — listed here only so this
// file's vocabulary matches the task's own Part I list exactly, with
// a comment clarifying they're derived, not primary events.
// ════════════════════════════════════════════════

/// A single recorded user-behavior event. Deliberately a flat,
/// JSON-serializable shape (matches the app's existing
/// `Map<String, dynamic>` track-record convention) so it can be
/// persisted via `shared_preferences` the same way `LocalLibrary`
/// already persists everything else — no new storage technology
/// introduced for this.
enum SignalType {
  play,
  playDuration, // carries `value` = seconds actually listened
  completed,
  skip, // carries `value` = seconds listened before skipping
  like,
  unlike,
  search, // carries `query` instead of a trackId
  addToPlaylist,
  removeFromPlaylist,
  replay, // same track played again within a short window
}

class SignalEvent {
  const SignalEvent({
    required this.type,
    required this.timestamp,
    this.trackId,
    this.artist,
    this.title,
    this.query,
    this.value,
  });

  final SignalType type;
  final DateTime timestamp;

  /// Present for track-level signals (play/completed/skip/like/etc.);
  /// null for [SignalType.search].
  final String? trackId;
  final String? artist;
  final String? title;

  /// Present only for [SignalType.search].
  final String? query;

  /// Present only for [SignalType.playDuration] (seconds listened) and
  /// [SignalType.skip] (seconds listened before the skip) — lets the
  /// scoring model distinguish "skipped after 3 seconds" (strong
  /// negative) from "skipped after 3 minutes of a 3:30 song" (should
  /// NOT be penalized the same way — see PART I's own instruction:
  /// "Do not permanently punish an artist based on one skip" and the
  /// scoring model's skip-penalty logic in scorer.dart).
  final double? value;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        if (trackId != null) 'trackId': trackId,
        if (artist != null) 'artist': artist,
        if (title != null) 'title': title,
        if (query != null) 'query': query,
        if (value != null) 'value': value,
      };

  factory SignalEvent.fromJson(Map<String, dynamic> json) {
    return SignalEvent(
      type: SignalType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => SignalType.play,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      trackId: json['trackId'] as String?,
      artist: json['artist'] as String?,
      title: json['title'] as String?,
      query: json['query'] as String?,
      value: (json['value'] as num?)?.toDouble(),
    );
  }
}
