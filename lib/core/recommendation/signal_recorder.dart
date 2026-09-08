// ═════════════════════════════════════════════════════════════════════════
// V Shots — Recommendation Engine: Real Playback & Intent Signal Tracker
// ═════════════════════════════════════════════════════════════════════════

import 'recommendation_engine.dart';
import 'signal_event.dart';

class PlaybackSignalTracker {
  PlaybackSignalTracker(this._engine);

  final RecommendationEngine _engine;

  String? _currentTrackId;
  String? _currentArtist;
  String? _currentTitle;
  DateTime? _startedAt;

  final Map<String, DateTime> _recentStarts = {};
  static const _replayWindow = Duration(minutes: 30);

  void onTrackStarted(Map<String, dynamic> track) {
    final id = track['id'] as String?;
    if (id == null || id.isEmpty) return;

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

  void onPlaylistOpened(String playlistTitle, {String? subtitle}) {
    _engine.recordSignal(
      SignalEvent(
        type: SignalType.playlistOpen,
        timestamp: DateTime.now(),
        playlistTheme: '$playlistTitle ${subtitle ?? ''}'.trim(),
      ),
    );
  }

  void onPlaylistInteraction(Map<String, dynamic> track, String playlistTitle) {
    _engine.recordSignal(
      SignalEvent(
        type: SignalType.playlistInteraction,
        timestamp: DateTime.now(),
        trackId: track['id'] as String?,
        artist: track['artist'] as String?,
        title: track['title'] as String?,
        playlistTheme: playlistTitle,
      ),
    );
  }
}
