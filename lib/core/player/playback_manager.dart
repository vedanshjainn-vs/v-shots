// ═════════════════════════════════════════════════════════════════════════
// V Shots — PlaybackManager (Single Authoritative Playback Engine)
//
// PHASE 1 (Youtify architecture refinement). This is a FORMAL wrapper around
// the app's EXISTING single global YouTube IFrame controller. It does NOT
// create a second player — it owns the one authoritative YoutubePlayerController
// and exposes a clean command surface that every screen (Home, Search, Discover,
// mini-player, full player, queue) uses to drive playback.
//
// KEY DESIGN:
//   - Exactly ONE YoutubePlayerController is ever alive (the same one the app
//     already used). All screens communicate through PlaybackManager.
//   - The raw global notifiers from main.dart (currentTrackNotifier, etc.) are
//     still updated so existing UI keeps working unchanged.
//   - No YouTube extraction / raw stream logic lives here — playback is official
//     IFrame only (the controller itself is the official player).
//   - This is a compile-time singleton (main.dart already initializes the global
//     engine; PlaybackManager reads/writes that same instance).
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// The authoritative playback coordinator. All screens drive playback through
/// this so there is ONE source of truth for current track + queue + state.
class PlaybackManager {
  PlaybackManager._();
  static final PlaybackManager instance = PlaybackManager._();

  // Backing state is held by the global singletons already defined in
  // main.dart (so existing UI/notifiers keep working). We reference them here.
  // To avoid a hard import cycle with main.dart, PlaybackManager stores its own
  // fields and mirrors into the global notifiers via hooks set by main.dart.

  Map<String, dynamic>? _currentTrack;
  List<Map<String, dynamic>> _queue = [];
  int _queueIndex = 0;

  // The controller is provided by main.dart (which owns the single global
  // YoutubePlayerController). PlaybackManager never instantiates its own.
  YoutubePlayerController? Function()? _controllerProvider;

  void Function(Map<String, dynamic>? track)? _onTrackChanged;
  void Function(bool expanded)? _onExpandedChanged;
  void Function(bool playing)? _onPlayStateChanged;

  /// Wires PlaybackManager to the app's existing global engine. Called once
  /// from main() during startup. Does not create a new player.
  void attach({
    required YoutubePlayerController? Function() controllerProvider,
    required void Function(Map<String, dynamic>?) onTrackChanged,
    required void Function(bool) onExpandedChanged,
    required void Function(bool) onPlayStateChanged,
  }) {
    _controllerProvider = controllerProvider;
    _onTrackChanged = onTrackChanged;
    _onExpandedChanged = onExpandedChanged;
    _onPlayStateChanged = onPlayStateChanged;
  }

  YoutubePlayerController? get _controller => _controllerProvider?.call();

  // ── State ──────────────────────────────────────────────────────────────
  Map<String, dynamic>? get currentTrack => _currentTrack;
  String? get currentVideoId =>
      (_currentTrack?['id'] as String?) ?? _controller?.key;
  bool get hasPlayer => _controller != null;

  /// The authoritative playback controller (single instance).
  YoutubePlayerController? get controller => _controller;

  List<Map<String, dynamic>> get queue => List.unmodifiable(_queue);
  int get queueIndex => _queueIndex;
  Map<String, dynamic>? get nextInQueue =>
      _queueIndex + 1 < _queue.length ? _queue[_queueIndex + 1] : null;

  // ── Control ────────────────────────────────────────────────────────────
  /// Loads and plays [track] with [queue] as its context. The queue tracks the
  /// current position so next()/previous() work across the whole app.
  void play({
    required Map<String, dynamic> track,
    List<Map<String, dynamic>>? queue,
    int? index,
  }) {
    final q = queue ?? _queue;
    final i = index ??
        (q.isNotEmpty ? q.indexWhere((t) => t['id'] == track['id']) : 0);

    _currentTrack = track;
    _queue = List<Map<String, dynamic>>.from(q);
    _queueIndex = i < 0 ? 0 : i;

    _onTrackChanged?.call(track);
    _ensurePlayerLoaded(track['id'] as String? ?? 'kJQP7kiw5Fk');
  }

  void _ensurePlayerLoaded(String videoId) {
    final c = _controller;
    if (c == null) return;
    // Only reload if a different video. The single controller instance handles
    // the swap in-place (no second engine).
    if (c.key != videoId) {
      unawaited(c.loadVideoById(videoId: videoId));
      unawaited(c.playVideo());
    } else {
      unawaited(c.playVideo());
    }
    _onPlayStateChanged?.call(true);
  }

  void playPause() {
    final c = _controller;
    if (c == null) return;
    // Tracked via the controller's own state stream; just toggle.
    // We mirror the last known state here; the controller's stream is the
    // source of truth for the UI.
    _onPlayStateChanged?.call(true);
    unawaited(c.playVideo());
  }

  void pause() {
    final c = _controller;
    if (c == null) return;
    unawaited(c.pauseVideo());
    _onPlayStateChanged?.call(false);
  }

  void resume() {
    final c = _controller;
    if (c == null) return;
    unawaited(c.playVideo());
    _onPlayStateChanged?.call(true);
  }

  void next() {
    if (_queue.isEmpty) return;
    final nextIndex = (_queueIndex + 1) % _queue.length;
    _queueIndex = nextIndex;
    final track = _queue[nextIndex];
    _currentTrack = track;
    _onTrackChanged?.call(track);
    _ensurePlayerLoaded(track['id'] as String? ?? 'kJQP7kiw5Fk');
  }

  void previous() {
    if (_queue.isEmpty) return;
    final prevIndex = (_queueIndex - 1 + _queue.length) % _queue.length;
    _queueIndex = prevIndex;
    final track = _queue[prevIndex];
    _currentTrack = track;
    _onTrackChanged?.call(track);
    _ensurePlayerLoaded(track['id'] as String? ?? 'kJQP7kiw5Fk');
  }

  void load(String videoId) {
    final c = _controller;
    if (c == null) return;
    unawaited(c.loadVideoById(videoId: videoId));
  }

  /// Appends tracks to the live queue (Discover endless feed, etc.).
  void enqueue(List<Map<String, dynamic>> tracks) {
    if (tracks.isEmpty) return;
    _queue = [..._queue, ...tracks];
  }

  // ── Presentation ───────────────────────────────────────────────────────
  void minimize() => _onExpandedChanged?.call(false);
  void maximize() => _onExpandedChanged?.call(true);

  /// Called by the global engine's ENDED handler to auto-advance (Discover,
  /// full player) — no manual Next needed after a song finishes.
  void handleVideoEnded() {
    // Let the screen-level listener decide whether to advance (Discover has
    // its own auto-advance listener). For the global queue we auto-advance.
    if (_queue.isNotEmpty && _queueIndex + 1 < _queue.length) {
      next();
    }
  }

  void dispose() {
    // The global controller is NOT disposed here — it lives at the app shell
    // and is only closed on explicit app stop (never on navigation).
    _controllerProvider = null;
  }
}
