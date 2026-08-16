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
// ONCE per open (by the global player sheet) and reused for every video
// switch — never destroyed on tab changes / minimize / expand; only on
// explicit close().
//
// NOTE (safe incremental migration): this turn unifies DISCOVERY onto the
// global manager and provides the global queue/state. The legacy IFrame
// (audio_service) path still serves Home/Search/Profile playback and is
// coordinated against this manager via main.dart (opening the browser pauses
// the IFrame; starting the IFrame closes the browser) — it will be migrated
// onto this manager in the next phase, one surface at a time.
// ═════════════════════════════════════════════════════════════════════════════

import '../../features/foryou/discovery_browser_controller.dart';

class VShotsPlaybackManager {
  VShotsPlaybackManager._();
  static final VShotsPlaybackManager instance = VShotsPlaybackManager._();

  /// The global browser state (open/closed/collapsed/expanded + current
  /// track). The single source of truth every surface reads.
  final DiscoveryBrowserController browser = DiscoveryBrowserController();

  final List<Map<String, dynamic>> _queue = [];
  int _index = 0;

  bool get isOpen => browser.isOpen;
  Map<String, dynamic>? get currentTrack => browser.track;
  List<Map<String, dynamic>> get queue => List.unmodifiable(_queue);
  int get currentIndex => _index;

  /// Plays a single track in the global session (reusing the same WebView).
  void play(Map<String, dynamic> track) {
    _queue
      ..clear()
      ..add(track);
    _index = 0;
    browser.open(track);
  }

  /// Plays [tracks] starting at [startIndex]; next()/previous() then navigate
  /// this queue through the SAME browser session (no second WebView).
  void playQueue(List<Map<String, dynamic>> tracks, int startIndex) {
    if (tracks.isEmpty) return;
    _queue
      ..clear()
      ..addAll(tracks);
    _index = startIndex.clamp(0, _queue.length - 1);
    browser.open(_queue[_index]);
  }

  /// Plays the same track the browser already holds (no-op if closed).
  void playCurrent() {
    if (_queue.isEmpty) return;
    browser.open(_queue[_index]);
  }

  void next() {
    if (_queue.length < 2) return;
    _index = (_index + 1) % _queue.length;
    browser.open(_queue[_index]);
  }

  void previous() {
    if (_queue.length < 2) return;
    _index = (_index - 1 + _queue.length) % _queue.length;
    browser.open(_queue[_index]);
  }

  /// Closes the global session: stops playback and disposes the WebView (the
  /// global player sheet removes itself from the tree when closed).
  void close() {
    browser.close();
    _queue.clear();
    _index = 0;
  }
}
