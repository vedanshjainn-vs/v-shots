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
  });

  final void Function() onPageStarted;
  final void Function() onPageFinished;
  final void Function(String message) onError;

  MethodChannel? _channel;
  String? _lastUrl;
  String? _pendingUrl;
  bool _disposed = false;
  bool _pagePlaying = false;

  bool get hasLoaded => _channel != null;
  bool get pagePlaying => _pagePlaying;

  /// Loads [url] into the same native browser instance. If the platform view
  /// has not been attached yet, the URL is queued and sent immediately after
  /// Android creates the view.
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

  /// Explicitly asks the native player to start with audio. This is used as a
  /// second-stage autoplay attempt after the YouTube page has loaded.
  Future<void> play() async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('play');
    } catch (_) {
      // The page may still be loading or YouTube may reject unmuted autoplay.
    }
  }

  /// Native Android platform view. The existing Discovery sheet keeps this
  /// widget mounted for the whole browser session, including the collapsed
  /// mini-player state.
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
      hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      onPlatformViewCreated: _attachPlatformView,
    );
  }

  void _attachPlatformView(int viewId) {
    if (_disposed) return;
    final channel = MethodChannel('vshots/browser/$viewId');
    _channel = channel;
    channel.setMethodCallHandler(_handleNativeEvent);
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
        // Give YouTube's dynamic player a moment to attach, then make a few
        // best-effort play/unmute attempts. We never fake success in Dart.
        unawaited(_autoplayPass());
        break;
      case 'playbackState':
        _pagePlaying = call.arguments == true;
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

/// Canonical YouTube watch URL helper retained for callers/tests that use the
/// browser session as a standalone component.
String browserWatchUrl(String videoId) => youtubeWatchUrl(videoId);
