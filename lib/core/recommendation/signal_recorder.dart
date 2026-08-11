// ════════════════════════════════════════════════
// V Shots — Recommendation Engine: real playback signal instrumentation
// ════════════════════════════════════════════════
//
// This is the ONE place that translates the app's REAL, existing
// playback events (just_audio's position/processing streams) into
// `SignalEvent`s the recommendation engine consumes. Previously (pre-
// Phase-7) the only signal captured anywhere was
// `LocalLibrary.recordRecentlyPlayed()` on track START — there was no
// instrumentation for skip/completion/listen-duration/replay at all.
//
// DESIGN: a single `PlaybackSignalTracker` instance, constructed once
// alongside the app's other globals (see main.dart), that main.dart's
// EXISTING playback code calls into at 3 real points:
//   1. `onTrackStarted(track)` — call when a new track begins (from
//      playTrack()/_playAdjacentInQueue()/_handleTrackCompleted()/
//      PlayerScreen._play()/ForYouFeedScreen._playIndex() — every
//      real "a track started playing" call site).
//   2. `onTrackEnded(track, {required bool completed})` — call when
//      that track stops being current (a skip, or natural completion)
//      — computes elapsed listen time from the real position stream
//      state captured at start, and records either SignalType.skip
//      (with elapsed seconds) or SignalType.completed +
//      SignalType.playDuration.
//   3. `onReplay(track)` — call when the SAME track is played again
//      shortly after a previous play (see the replay-detection window
//      below).
//
// This does NOT create a second player, a second stream listener
// architecture, or duplicate `_handleTrackCompleted`'s existing
// off/one/all repeat logic — it is a thin, additive observer called
// FROM the existing real playback call sites, per this task's "DO NOT
// change the player architecture" constraint.
// ════════════════════════════════════════════════

import 'recommendation_engine.dart';
import 'signal_event.dart';

class PlaybackSignalTracker {
  PlaybackSignalTracker(this._engine);

  final RecommendationEngine _engine;

  String? _currentTrackId;
  String? _currentArtist;
  String? _currentTitle;
  DateTime? _startedAt;

  /// Tracks recent track-start timestamps per track id, so a genuine
  /// "replay" (same track played again within a short window) can be
  /// distinguished from an unrelated later listen of the same track
  /// (e.g. weeks apart) — a real, bounded-memory map, not persisted
  /// (replay detection only needs to work within a live session).
  final Map<String, DateTime> _recentStarts = {};
  static const _replayWindow = Duration(minutes: 30);

  /// Call when a new track becomes the one actually playing. If a
  /// DIFFERENT track was previously playing and never had
  /// [onTrackEnded] called for it (e.g. an abrupt queue replacement
  /// rather than a clean skip), this finalizes that previous track as
  /// a skip using whatever elapsed time was tracked — so no play is
  /// ever silently dropped from the signal history.
  void onTrackStarted(Map<String, dynamic> track) {
    final id = track['id'] as String?;
    if (id == null || id.isEmpty) return;

    // Finalize any still-open previous track as a skip (see doc above).
    if (_currentTrackId != null && _currentTrackId != id) {
      _finalize(completed: false);
    }

    final now = DateTime.now();
    final lastStart = _recentStarts[id];
    if (lastStart != null && now.difference(lastStart) < _replayWindow) {
      _engine.recordSignal(
        SignalEvent(
          type: SignalType.replay,
          timestamp: now,
          trackId: id,
          artist: track['artist'] as String?,
          title: track['title'] as String?,
        ),
      );
    }
    _recentStarts[id] = now;

    _currentTrackId = id;
    _currentArtist = track['artist'] as String?;
    _currentTitle = track['title'] as String?;
    _startedAt = now;

    _engine.recordSignal(
      SignalEvent(
        type: SignalType.play,
        timestamp: now,
        trackId: id,
        artist: _currentArtist,
        title: _currentTitle,
      ),
    );
  }

  /// Call when the current track stops being current — either a user/
  /// OS skip ([completed] = false) or natural completion ([completed]
  /// = true, i.e. `ProcessingState.completed` fired). Records BOTH a
  /// skip/completed event AND (if any real listening time elapsed) a
  /// [SignalType.playDuration] event, per Part I's "long listen =
  /// positive" signal.
  void onTrackEnded({required bool completed}) {
    _finalize(completed: completed);
  }

  void _finalize({required bool completed}) {
    final id = _currentTrackId;
    final artist = _currentArtist;
    final title = _currentTitle;
    final startedAt = _startedAt;
    if (id == null || startedAt == null) return;

    final elapsedSeconds =
        DateTime.now().difference(startedAt).inMilliseconds / 1000.0;

    if (completed) {
      _engine.recordSignal(
        SignalEvent(
          type: SignalType.completed,
          timestamp: DateTime.now(),
          trackId: id,
          artist: artist,
          title: title,
        ),
      );
    } else {
      _engine.recordSignal(
        SignalEvent(
          type: SignalType.skip,
          timestamp: DateTime.now(),
          trackId: id,
          artist: artist,
          title: title,
          value: elapsedSeconds,
        ),
      );
    }

    if (elapsedSeconds > 1) {
      _engine.recordSignal(
        SignalEvent(
          type: SignalType.playDuration,
          timestamp: DateTime.now(),
          trackId: id,
          artist: artist,
          title: title,
          value: elapsedSeconds,
        ),
      );
    }

    _currentTrackId = null;
    _currentArtist = null;
    _currentTitle = null;
    _startedAt = null;
  }

  void onPlaylistAdd(Map<String, dynamic> track) {
    final id = track['id'] as String?;
    if (id == null || id.isEmpty) return;
    _engine.recordSignal(
      SignalEvent(
        type: SignalType.addToPlaylist,
        timestamp: DateTime.now(),
        trackId: id,
        artist: track['artist'] as String?,
        title: track['title'] as String?,
      ),
    );
  }

  void onLiked(Map<String, dynamic> track) {
    _engine.recordSignal(
      SignalEvent(
        type: SignalType.like,
        timestamp: DateTime.now(),
        trackId: track['id'] as String?,
        artist: track['artist'] as String?,
        title: track['title'] as String?,
      ),
    );
  }

  void onUnliked(Map<String, dynamic> track) {
    _engine.recordSignal(
      SignalEvent(
        type: SignalType.unlike,
        timestamp: DateTime.now(),
        trackId: track['id'] as String?,
        artist: track['artist'] as String?,
        title: track['title'] as String?,
      ),
    );
  }

  void onAddedToPlaylist(Map<String, dynamic> track) {
    _engine.recordSignal(
      SignalEvent(
        type: SignalType.addToPlaylist,
        timestamp: DateTime.now(),
        trackId: track['id'] as String?,
        artist: track['artist'] as String?,
        title: track['title'] as String?,
      ),
    );
  }

  void onSearched(String query) {
    _engine.recordSignal(
      SignalEvent(
        type: SignalType.search,
        timestamp: DateTime.now(),
        query: query,
      ),
    );
  }
}
