// ═════════════════════════════════════════════════════════════════════════════
// V Shots — VShotsBrowserSession (reusable in-app YouTube browser session)
// ═════════════════════════════════════════════════════════════════════════════
//
// Owns ONE WebViewController session (the real YouTube watch page) and its
// lifecycle: creation/config, loading, page playback toggle, and disposal.
// The UI/interaction layer (mini player, drag, expand/collapse) belongs to
// DiscoveryBrowserSheet — this class is the content/session layer, so the same
// browser can later be reused by Home/Search/Artist pages without duplicating
// WebView setup.
//
// Honest limits (documented, not faked):
//   • Playback is the real YouTube web page inside a WebView. Continuity while
//     minimized/expanded works because the WebView stays mounted; genuine
//     background/lock-screen audio is NOT guaranteed by WebViews and is the
//     existing audio_service global player's job, not this session's.
//   • Navigation is restricted to YouTube/Google infrastructure hosts.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Pure host policy — approved YouTube/Google infrastructure only. Extracted
/// for unit testing (no platform needed).
bool isAllowedBrowserHost(String host) {
  final h = host.toLowerCase();
  const allowed = [
    'youtube.com',
    'youtu.be',
    'googlevideo.com',
    'ytimg.com',
    'google.com',
    'gstatic.com',
    'ggpht.com',
  ];
  return allowed.any((a) => h == a || h.endsWith('.$a'));
}

/// A single in-app YouTube browser session. Created once per Discovery
/// browser opening; reused across video switches; disposed on close.
class VShotsBrowserSession {
  VShotsBrowserSession({
    required this.onPageStarted,
    required this.onPageFinished,
    required this.onError,
  });

  final void Function() onPageStarted;
  final void Function() onPageFinished;
  final void Function(String message) onError;

  WebViewController? _controller;
  String? _lastUrl;

  WebViewController? get controller => _controller;

  bool get hasLoaded => _controller != null;

  /// Loads [url] into the session, creating the WebView on first use.
  /// Safe to call repeatedly (video switching) — the SAME session/WebView is
  /// reused, preserving cookies/session state.
  Future<void> load(String url) async {
    _lastUrl = url;
    final webViewController = _controller ??= await _createController();
    try {
      await webViewController.loadRequest(Uri.parse(url));
    } catch (e) {
      onError('Could not open this video');
    }
  }

  /// Reloads the last-loaded URL (retry after an error).
  Future<void> retry() async {
    final url = _lastUrl;
    if (url != null) await load(url);
  }

  /// Toggles the page's video play/pause. Best-effort: YouTube does not
  /// expose playback state to the embedder, so this is a command, not a
  /// guaranteed status.
  Future<bool?> togglePagePlayback() async {
    final webViewController = _controller;
    if (webViewController == null) return null;
    try {
      final result = await webViewController.runJavaScriptReturningResult(
        "(function(){var v=document.querySelector('video');"
        "if(!v){return 'none';}"
        "if(v.paused){v.play();return 'playing';}"
        "v.pause();return 'paused';})()",
      );
      final state = result.toString();
      if (state.contains('playing')) return true;
      if (state.contains('paused')) return false;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<WebViewController> _createController() async {
    final webViewController = WebViewController();
    await webViewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await webViewController.setBackgroundColor(Colors.black);
    await webViewController.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) => onPageStarted(),
        onPageFinished: (_) => onPageFinished(),
        onWebResourceError: (error) =>
            onError('Playback failed — please retry'),
        onNavigationRequest: (request) {
          String host;
          try {
            host = Uri.parse(request.url).host.toLowerCase();
          } catch (_) {
            return NavigationDecision.prevent;
          }
          return isAllowedBrowserHost(host)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ),
    );
    // Android: allow the official YouTube page's media to start without an
    // extra in-page tap (the user already tapped Play in the app).
    try {
      final android = webViewController.platform as AndroidWebViewController;
      await android.setMediaPlaybackRequiresUserGesture(false);
    } catch (_) {
      // Non-Android or platform not ready — page still loads; the user can
      // tap YouTube's own play button.
    }
    return webViewController;
  }

  /// Disposes the session. Must be called on browser close.
  void dispose() {
    _controller = null;
    _lastUrl = null;
  }
}
