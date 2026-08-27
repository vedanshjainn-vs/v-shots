// ═════════════════════════════════════════════════════════════════════════════
// V Shots — VShotsPlaybackManager (global playback source of truth)
// ═════════════════════════════════════════════════════════════════════════════
//
// The SINGLE app-level owner of in-app YouTube playback, built on the PROVEN
// native engine that powers Discovery (VShotsBrowserSession → native Android
// WebView → official YouTube watch page + foreground media service).
//
//   Home / Search / Library / Discovery / Artist / Playlist
//        └──► VShotsPlaybackManager.play / playQueue / next / previous
//                     └──► ONE DiscoveryBrowserController (state)
//                     └──► ONE VShotsBrowserSession (WebView, owned by the
//                          global player sheet mounted once at the shell)
//
// There is exactly ONE active playback session. The native WebView is created
// ONCE per open and reused for every video switch — never destroyed on tab
// changes / minimize / expand; only on explicit close().
//
// Owns the global QUEUE with shuffle + repeat (pure Dart, unit-tested).
//
// AUTO-ADVANCE: the native WebView emits a real `video.ended` event (JS poll
// of the official YouTube page's <video> element), surfaced through
// VShotsBrowserSession → this manager's onVideoEnded(). Idempotent (once per
// completed video) and respects repeat/shuffle. Works screen-on and screen-off
// because the foreground media service keeps the engine + JS poll alive.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../features/foryou/discovery_browser_controller.dart';

enum PlaybackRepeat { off, one, all }

class VShotsPlaybackManager extends ChangeNotifier {
  VShotsPlaybackManager._();
  static final VShotsPlaybackManager instance = VShotsPlaybackManager._();

  /// The global browser state (open/closed/collapsed/expanded + current
  /// track). The single source of truth every surface reads.
  final DiscoveryBrowserController browser = DiscoveryBrowserController();

  final List<Map<String, dynamic>> _queue = [];
  int _index = 0;
  bool _shuffle = false;
  final List<int> _shuffleOrder = [];
  PlaybackRepeat _repeat = PlaybackRepeat.off;
  final Random _random = Random();

  bool get isOpen => browser.isOpen;
  Map<String, dynamic>? get currentTrack => browser.track;
  List<Map<String, dynamic>> get queue => List.unmodifiable(_queue);
  int get currentIndex => _index;
  bool get isShuffleOn => _shuffle;
  PlaybackRepeat get repeatMode => _repeat;
  List<int> get shuffleOrder => List.unmodifiable(_shuffleOrder);

  /// Idempotency guard for the native completion event: the last ended
  /// videoId + when it fired. A duplicate event for the SAME id within a
  /// short window is ignored; repeat-one reloads the same id, so a legitimate
  /// re-end (a full song later) is outside the window and passes.
  String? _lastEndedId;
  DateTime? _lastEndedAt;

  /// Plays a single track in the global session (reusing the same WebView).
  void play(Map<String, dynamic> track, {bool expanded = false}) {
    _queue
      ..clear()
      ..add(track);
    _index = 0;
    _rebuildShuffle(keepCurrentAt: null);
    browser.startExpanded = expanded;
    browser.open(track);
    notifyListeners();
  }

  /// Plays [tracks] starting at [startIndex]. [expanded] opens the full
  /// player immediately (explicit taps); Discovery autoplay passes false.
  void playQueue(
    List<Map<String, dynamic>> tracks,
    int startIndex, {
    bool expanded = false,
  }) {
    if (tracks.isEmpty) return;
    _queue
      ..clear()
      ..addAll(tracks);
    _index = startIndex.clamp(0, _queue.length - 1);
    _rebuildShuffle(keepCurrentAt: _index);
    browser.startExpanded = expanded;
    browser.open(_queue[_index]);
    notifyListeners();
  }

  /// Jumps to a queue index (tap on the queue list).
  void jumpTo(int index) {
    if (index < 0 || index >= _queue.length) return;
    _index = index;
    browser.open(_queue[_index]);
    notifyListeners();
  }

  void next() {
    if (_queue.length < 2) return;
    _index = _nextIndex(1);
    browser.open(_queue[_index]);
    notifyListeners();
  }

  void previous() {
    if (_queue.length < 2) return;
    _index = _nextIndex(-1);
    browser.open(_queue[_index]);
    notifyListeners();
  }

  /// Handles REAL media completion (native `video.ended`). Idempotent, and
  /// respects repeat/shuffle. Advances exactly once per completed video:
  ///   repeat ONE → replay the same track (same session, forced reload)
  ///   repeat ALL → next (wraps, following shuffle order when enabled)
  ///   repeat OFF → next; stops at the end of the queue (non-shuffle)
  void onVideoEnded(String videoId) {
    if (videoId.isEmpty) return;
    // Identity guard: only auto-advance when the ended video IS the current
    // track (a stale 'ended' from a previous load must never skip the queue).
    if ((browser.track?['id'] as String?) != videoId) return;
    final now = DateTime.now();
    // Duplicate completion event for the same video (native double-fire)
    // within a short window → ignored.
    if (_lastEndedId == videoId &&
        _lastEndedAt != null &&
        now.difference(_lastEndedAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastEndedId = videoId;
    _lastEndedAt = now;

    if (_repeat == PlaybackRepeat.one) {
      browser.requestReplay();
      notifyListeners();
      return;
    }

    // repeat OFF → stop at end (natural order); shuffle wraps its order.
    if (_repeat == PlaybackRepeat.off &&
        !_shuffle &&
        _index >= _queue.length - 1) {
      return; // end of queue — leave the finished state
    }
    next();
  }

  int _nextIndex(int delta) {
    if (_shuffle && _shuffleOrder.length == _queue.length) {
      final pos = _shuffleOrder.indexOf(_index);
      final safePos = pos == -1 ? 0 : pos;
      return _shuffleOrder[(safePos + delta + _shuffleOrder.length) %
          _shuffleOrder.length];
    }
    return (_index + delta + _queue.length) % _queue.length;
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    _rebuildShuffle(keepCurrentAt: _index);
    notifyListeners();
  }

  void setRepeat(PlaybackRepeat mode) {
    _repeat = mode;
    notifyListeners();
  }

  void cycleRepeat() {
    _repeat = switch (_repeat) {
      PlaybackRepeat.off => PlaybackRepeat.all,
      PlaybackRepeat.all => PlaybackRepeat.one,
      PlaybackRepeat.one => PlaybackRepeat.off,
    };
    notifyListeners();
  }

  void addToEnd(Map<String, dynamic> track) {
    if (_queue.isEmpty) {
      play(track);
      return;
    }
    _queue.add(track);
    _rebuildShuffle(keepCurrentAt: _index);
    notifyListeners();
  }

  /// Inserts [track] right after the current one (Play Next).
  void playNext(Map<String, dynamic> track) {
    if (_queue.isEmpty) {
      play(track);
      return;
    }
    _queue.insert(_index + 1, track);
    _rebuildShuffle(keepCurrentAt: _index);
    notifyListeners();
  }

  void _rebuildShuffle({int? keepCurrentAt}) {
    _shuffleOrder.clear();
    final indices = List<int>.generate(_queue.length, (i) => i);
    indices.shuffle(_random);
    if (keepCurrentAt != null && indices.remove(keepCurrentAt)) {
      indices.insert(0, keepCurrentAt);
    }
    _shuffleOrder.addAll(indices);
  }

  /// Closes the global session: stops playback and disposes the WebView (the
  /// global player sheet removes itself from the tree when closed). Resets
  /// the transient session state (queue/shuffle/repeat/ended guard).
  void close() {
    browser.close();
    _queue.clear();
    _index = 0;
    _shuffle = false;
    _repeat = PlaybackRepeat.off;
    _shuffleOrder.clear();
    _lastEndedId = null;
    _lastEndedAt = null;
    notifyListeners();
  }

  /// Pauses the native WebView (sleep timer / lock). Does not close the session.
  void pause() {
    browser.requestPause();
    notifyListeners();
  }

  /// Minimizes the player to the mini player (playback continues).
  void minimize() => browser.requestMinimize();

  /// Expands the player to the full player.
  void expand() => browser.requestExpand();
}
