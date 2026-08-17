// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Native Discovery YouTube browser session
// ═════════════════════════════════════════════════════════════════════════════
//
// Discovery uses a native Android WebView platform view rather than the
// generic webview_flutter widget. The native view is deliberately kept alive
// while its media session is playing so minimizing the browser does not resize
// or recreate the playback surface. The Android implementation also keeps the
// WebView media lifecycle alive across Activity visibility changes.
//
// The session remains UI-agnostic: it owns the native channel and exposes a
// Widget for the sheet. This keeps the existing Discovery sheet/drag UX intact
// while replacing only the playback engine underneath it.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/browser/vshots_content_blocker.dart';
import '../../shared/utils/youtube_url.dart';

/// Pure host policy — approved YouTube/Google infrastructure only.
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

class VShotsBrowserSession {
  VShotsBrowserSession({
    required this.onPageStarted,
    required this.onPageFinished,
    required this.onError,
    this.onVideoEnded,
    VShotsContentBlocker? contentBlocker,
  }) : contentBlocker = contentBlocker ?? VShotsContentBlocker();

  final void Function() onPageStarted;
  final void Function() onPageFinished;
  final void Function(String message) onError;

  /// Fired by the native WebView when the current video's media reaches its
  /// natural end (real `video.ended` from the page — not a fake timer).
  /// Carries the ended video's id (extracted from the loaded URL) so the
  /// manager can de-duplicate completion events idempotently.
  final void Function(String videoId)? onVideoEnded;

  /// The general-purpose content blocker for this browser session. Owned here
  /// (NOT by the playback manager) — independent from playback.
  final VShotsContentBlocker contentBlocker;

  MethodChannel? _channel;
  String? _lastUrl;
  String? _pendingUrl;
  bool _disposed = false;
  bool _pagePlaying = false;

  bool get hasLoaded => _channel != null;
  bool get pagePlaying => _pagePlaying;

  Future<void> load(String url) async {
    if (_disposed) return;
    _lastUrl = url;
    _pendingUrl = url;
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('load', url);
    } catch (_) {
      onError('Could not open this video');
    }
  }

  Future<void> retry() async {
    final url = _lastUrl;
    if (url == null) return;
    final channel = _channel;
    if (channel == null) {
      _pendingUrl = url;
      return;
    }
    try {
      await channel.invokeMethod<void>('reload');
    } catch (_) {
      onError('Playback failed — please retry');
    }
  }

  Future<bool?> togglePagePlayback() async {
    final channel = _channel;
    if (channel == null) return null;
    try {
      await channel.invokeMethod<void>('toggle');
      return _pagePlaying;
    } catch (_) {
      return null;
    }
  }

  Future<void> play() async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('play');
    } catch (_) {
      // The page may still be loading or YouTube may reject unmuted autoplay.
    }
  }

  Widget buildWidget() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Discovery browser is available on Android.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return AndroidView(
      viewType: 'vshots/native_browser',
      layoutDirection: TextDirection.ltr,
      onPlatformViewCreated: _attachPlatformView,
    );
  }

  /// Pushes the compiled blocker configuration to the native WebView once
  /// (cheap sets; no per-request regex, no WebView recreation). Toggling
  /// on/off only affects SUBSEQUENT requests.
  Future<void> _pushContentBlocker(MethodChannel channel) async {
    await contentBlocker.initialize();
    try {
      await channel.invokeMethod<void>('setContentBlocker', {
        'enabled': contentBlocker.enabled,
        'blocked': contentBlocker.blockedHosts,
        'essential': contentBlocker.essentialHosts,
      });
    } catch (_) {
      // Older native view / not ready — non-fatal.
    }
  }

  /// Applies a blocker toggle to the LIVE session (next requests) without
  /// recreating the WebView or interrupting playback.
  Future<void> applyContentBlocker() async {
    final channel = _channel;
    if (channel == null) return;
    await _pushContentBlocker(channel);
  }

  void _attachPlatformView(int viewId) {
    if (_disposed) return;
    final channel = MethodChannel('vshots/browser/$viewId');
    _channel = channel;
    channel.setMethodCallHandler(_handleNativeEvent);
    unawaited(_pushContentBlocker(channel));
    final pending = _pendingUrl;
    if (pending != null) {
      unawaited(load(pending));
    }
  }

  Future<void> _handleNativeEvent(MethodCall call) async {
    switch (call.method) {
      case 'pageStarted':
        onPageStarted();
        break;
      case 'pageFinished':
        onPageFinished();
        unawaited(_autoplayPass());
        break;
      case 'playbackState':
        _pagePlaying = call.arguments == true;
        break;
      case 'videoEnded':
        final endedId = extractYoutubeVideoId(_lastUrl ?? '') ?? '';
        onVideoEnded?.call(endedId);
        break;
      case 'blocked':
        contentBlocker.recordBlocked(call.arguments?.toString() ?? '');
        break;
      case 'error':
        onError(call.arguments?.toString() ?? 'Playback failed — please retry');
        break;
    }
  }

  Future<void> _autoplayPass() async {
    for (final delay in const [
      Duration(milliseconds: 250),
      Duration(milliseconds: 900),
      Duration(milliseconds: 1800),
    ]) {
      if (_disposed) return;
      await Future<void>.delayed(delay);
      if (_disposed) return;
      await play();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final channel = _channel;
    _channel = null;
    _pendingUrl = null;
    _lastUrl = null;
    _pagePlaying = false;
    if (channel != null) {
      unawaited(channel.invokeMethod<void>('dispose'));
      channel.setMethodCallHandler(null);
    }
  }
}

String browserWatchUrl(String videoId) => youtubeWatchUrl(videoId);
