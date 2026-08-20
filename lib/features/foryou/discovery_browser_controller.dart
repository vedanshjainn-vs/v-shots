// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Discovery in-app browser controller (Discovery-scoped)
// ═════════════════════════════════════════════════════════════════════════════
//
// Single source of truth for the Discovery in-app YouTube browser session.
// There is ONLY ever one of these (a field of the Discovery feed state), so
// "Play" on any Discovery card reuses this one session — never a second
// browser. It owns pure STATE only (no WebView reference): the WebView
// controller lives in the sheet widget, so this class stays fully unit-
// testable without any platform channel.
//
// Follows the app's existing lightweight-state conventions (ValueNotifier/
// ChangeNotifier style) — no new state-management dependency.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

import '../../shared/utils/youtube_url.dart';

/// Explicit browser lifecycle states. One source of truth for what the
/// Discovery browser is doing — prevents "browser visible but player disposed"
/// / "player playing but browser hidden" bugs.
enum BrowserState { closed, collapsed, expanded }

class DiscoveryBrowserController extends ChangeNotifier {
  Map<String, dynamic>? _track;
  bool _isOpen = false;
  bool _isExpanded = false;
  bool _isLoading = false;
  String? _error;
  bool? _pagePlaying;

  /// When true, the sheet mounts already expanded (explicit taps from Home /
  /// Search / Library open the full player). Discovery autoplay stays
  /// collapsed (false).
  bool startExpanded = false;

  /// Extent commands from OUTSIDE the sheet (e.g. the manager's minimize()/
  /// expand()). 0=none, 1=minimize, 2=expand. The sheet observes this and
  /// animates its own extent.
  final ValueNotifier<int> extentCommand = ValueNotifier<int>(0);

  Map<String, dynamic>? get track => _track;

  /// Current lifecycle state (see [BrowserState]).
  BrowserState get state {
    if (!_isOpen) return BrowserState.closed;
    return _isExpanded ? BrowserState.expanded : BrowserState.collapsed;
  }

  bool get isOpen => _isOpen;
  bool get isExpanded => _isExpanded;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Last-known page playback state. Null = unknown (YouTube does not expose
  /// playback state to the embedder; this is set only from our own
  /// play/pause commands to the page). Callers treat it as a hint, not a
  /// guaranteed status.
  bool? get pagePlaying => _pagePlaying;

  String? get videoId => _track?['id'] as String?;
  String? get title => _track?['title'] as String?;
  String? get artist => _track?['artist'] as String?;
  String? get artwork => _track?['artwork'] as String?;
  String get playbackSource => _track?['playbackSource'] as String? ?? 'youtube';

  /// Canonical playback URL for the current track, or null when closed.
  /// Supports both YouTube and JioSaavn URLs.
  String? get url {
    final id = videoId;
    if (id == null || id.isEmpty) return null;
    
    // Check if track has a direct URL (JioSaavn, etc.)
    final directUrl = _track?['url'] as String? ?? _track?['webUrl'] as String?;
    if (directUrl != null && directUrl.isNotEmpty) {
      return directUrl;
    }
    
    // Default to YouTube
    return youtubeWatchUrl(id);
  }

  /// Opens the browser for [track] (or switches to it if already open —
  /// reusing this one session). Starts collapsed with a loading state.
  void open(Map<String, dynamic> track) {
    _track = track;
    _isOpen = true;
    _isExpanded = false;
    _isLoading = true;
    _error = null;
    _pagePlaying = null;
    debugPrint('[DiscoveryBrowser] OPEN videoId=${track['id']} url=$url');
    notifyListeners();
  }

  /// Closes the browser entirely and clears the session.
  void close() {
    debugPrint('[DiscoveryBrowser] CLOSE');
    _isOpen = false;
    _isExpanded = false;
    _isLoading = false;
    _error = null;
    _pagePlaying = null;
    _track = null;
    notifyListeners();
  }

  void expand() {
    if (_isExpanded) return;
    _isExpanded = true;
    debugPrint('[DiscoveryBrowser] EXPANDED');
    notifyListeners();
  }

  void minimize() {
    if (!_isExpanded) return;
    _isExpanded = false;
    debugPrint('[DiscoveryBrowser] MINIMIZED');
    notifyListeners();
  }

  void setExpanded(bool value) {
    if (_isExpanded == value) return;
    _isExpanded = value;
    debugPrint(
      value ? '[DiscoveryBrowser] EXPANDED' : '[DiscoveryBrowser] MINIMIZED',
    );
    notifyListeners();
  }

  void setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void setError(String? message) {
    if (_error == message) return;
    _error = message;
    notifyListeners();
  }

  void setPagePlaying(bool value) {
    if (_pagePlaying == value) return;
    _pagePlaying = value;
    notifyListeners();
  }

  /// Requests the sheet to minimize its extent (used by the manager/back).
  void requestMinimize() => extentCommand.value = 1;

  /// Requests the sheet to expand its extent (used by the manager).
  void requestExpand() => extentCommand.value = 2;

  /// Requests the sheet to RELOAD the current URL (used by repeat-one).
  final ValueNotifier<int> replayRequest = ValueNotifier<int>(0);

  void requestReplay() => replayRequest.value++;
}
