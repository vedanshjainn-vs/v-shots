// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Native Discovery YouTube browser session
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/browser/vshots_content_blocker.dart';
import '../../core/remote_config/remote_feature_flags.dart';
import '../../shared/utils/youtube_url.dart';

bool isAllowedBrowserHost(String host) {
  final h = host.toLowerCase();
  if (h.isEmpty) return false;
  if (h == 'api.jiosaavn.com' || h.endsWith('.api.jiosaavn.com')) return false;
  if (h == 'saavn.me' || h.endsWith('.saavn.me')) return false;
  const allowed = [
    'youtube.com', 'youtu.be', 'googlevideo.com', 'ytimg.com', 'google.com',
    'gstatic.com', 'ggpht.com', 'jiosaavn.com', 'www.jiosaavn.com',
    'saavn.com', 'www.saavn.com', 'static.saavncdn.com', 'c.saavncdn.com',
  ];
  return allowed.any((a) => h == a || h.endsWith('.$a'));
}

bool isAllowedBrowserUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme != 'https') return false;
  return isAllowedBrowserHost(uri.host);
}

class VShotsBrowserSession {
  VShotsBrowserSession({
    required this.onPageStarted,
    required this.onPageFinished,
    required this.onError,
    this.onVideoEnded,
    this.onAdState,
    this.onNotificationAction,
    VShotsContentBlocker? contentBlocker,
  }) : contentBlocker = contentBlocker ?? VShotsContentBlocker();

  final void Function() onPageStarted;
  final void Function() onPageFinished;
  final void Function(String message) onError;
  final void Function(String videoId)? onVideoEnded;
  final void Function(bool adActive)? onAdState;
  final Future<void> Function(String action)? onNotificationAction;
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
    if (channel == null) { _pendingUrl = url; return; }
    try { await channel.invokeMethod<void>('reload'); }
    catch (_) { onError('Playback failed — please retry'); }
  }

  Future<bool?> togglePagePlayback() async {
    final channel = _channel;
    if (channel == null) return null;
    try {
      final state = await channel.invokeMethod<String>('toggle');
      _pagePlaying = state == 'playing';
      return _pagePlaying;
    } catch (_) { return null; }
  }

  Future<void> pause() async {
    final channel = _channel;
    if (channel == null) return;
    try { await channel.invokeMethod<void>('pause'); _pagePlaying = false; }
    catch (_) {}
  }

  Future<void> play() async {
    final channel = _channel;
    if (channel == null) return;
    try { await channel.invokeMethod<void>('play'); }
    catch (_) {}
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

  Future<void> _pushContentBlocker(MethodChannel channel) async {
    await contentBlocker.initialize();
    try {
      await channel.invokeMethod<void>('setContentBlocker', {
        'enabled': contentBlocker.enabled,
        'blocked': contentBlocker.blockedHosts,
        'essential': contentBlocker.essentialHosts,
        'patterns': contentBlocker.adUrlPatterns,
      });
    } catch (_) {}
  }

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
    unawaited(_pushAdAssist(channel));
    final pending = _pendingUrl;
    if (pending != null) unawaited(load(pending));
  }

  Future<void> _pushAdAssist(MethodChannel channel) async {
    try {
      await channel.invokeMethod<void>(
        'setAdAssist',
        RemoteFeatureFlags.instance.enableYoutubeAdAssist,
      );
    } catch (_) {}
  }

  Future<void> applyAdAssist() async {
    final channel = _channel;
    if (channel == null) return;
    await _pushAdAssist(channel);
  }

  Future<void> updateNotification({
    required String title,
    required String artist,
    required bool playing,
  }) async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('updateNotification', {
        'title': title,
        'artist': artist,
        'playing': playing,
      });
    } catch (_) {}
  }

  Future<void> _handleNativeEvent(MethodCall call) async {
    switch (call.method) {
      case 'pageStarted': onPageStarted(); break;
      case 'pageFinished':
        onPageFinished();
        unawaited(_autoplayPass());
        break;
      case 'playbackState': _pagePlaying = call.arguments == true; break;
      case 'videoEnded':
        final endedId = extractYoutubeVideoId(_lastUrl ?? '') ?? '';
        onVideoEnded?.call(endedId);
        break;
      case 'adState': onAdState?.call(call.arguments == true); break;
      case 'notificationAction':
        final action = call.arguments?.toString() ?? '';
        if (action.isNotEmpty) await onNotificationAction?.call(action);
        break;
      case 'blocked': contentBlocker.recordBlocked(call.arguments?.toString() ?? ''); break;
      case 'error': onError(call.arguments?.toString() ?? 'Playback failed — please retry'); break;
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

  @visibleForTesting
  Future<void> debugHandleNativeEvent(MethodCall call) => _handleNativeEvent(call);
}

String browserWatchUrl(String videoId) => youtubeWatchUrl(videoId);
