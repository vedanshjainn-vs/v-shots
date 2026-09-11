// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Native Discovery YouTube browser session
// ═════════════════════════════════════════════════════════════════════════════
//
// Discovery uses one native Android WebView platform view for official
// YouTube/JioSaavn playback. This class is the Flutter command/state boundary:
//
//   user/system command → explicit MethodChannel command
//   native WebView      → authoritative playback-state event
//   Flutter UI          ← state event
//
// Page loading is not playback. A load may request one system autoplay command
// after the matching page finishes, but there is no retry loop and no lifecycle
// callback that can continuously force PLAY. User pause cancels that request.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/browser/vshots_content_blocker.dart';
import '../../core/remote_config/remote_feature_flags.dart';
import '../../shared/utils/youtube_url.dart';
import 'vshots_playback_state.dart';

/// Pure host policy — YouTube/Google + official JioSaavn webpage hosts.
bool isAllowedBrowserHost(String host) {
  final h = host.toLowerCase();
  if (h.isEmpty) return false;
  if (h == 'api.jiosaavn.com' || h.endsWith('.api.jiosaavn.com')) {
    return false;
  }
  if (h == 'saavn.me' || h.endsWith('.saavn.me')) return false;
  const allowed = [
    'youtube.com',
    'youtu.be',
    'googlevideo.com',
    'ytimg.com',
    'google.com',
    'gstatic.com',
    'ggpht.com',
    'jiosaavn.com',
    'www.jiosaavn.com',
    'saavn.com',
    'www.saavn.com',
    'static.saavncdn.com',
    'c.saavncdn.com',
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
    this.onPlaybackState,
    this.onPlaybackStateChanged,
    this.onNotificationAction,
    VShotsContentBlocker? contentBlocker,
  }) : contentBlocker = contentBlocker ?? VShotsContentBlocker();

  final void Function() onPageStarted;
  final void Function() onPageFinished;
  final void Function(String message) onError;

  /// Fired by the native WebView when the current media reaches its natural
  /// end or the validated near-end auto-advance point.
  final void Function(String videoId)? onVideoEnded;

  /// Fired when the official player enters/leaves an in-stream ad.
  final void Function(bool adActive)? onAdState;

  /// Compatibility boolean snapshot for lightweight consumers.
  final void Function(bool playing)? onPlaybackState;

  /// Full native state-machine snapshot consumed by the browser controller.
  final void Function(VShotsPlaybackState state, bool playing)?
      onPlaybackStateChanged;

  final Future<void> Function(String action)? onNotificationAction;

  /// The general-purpose content blocker for this browser session. Owned here
  /// (NOT by the playback manager) — independent from playback.
  final VShotsContentBlocker contentBlocker;

  MethodChannel? _channel;
  String? _lastUrl;
  String? _pendingUrl;
  bool _pendingAutoplay = true;
  int _generation = 0;
  bool _disposed = false;
  bool _pagePlaying = false;
  VShotsPlaybackState _playbackState = VShotsPlaybackState.idle;
  bool _userPaused = false;
  bool _autoplayPending = false;
  Map<String, Object?>? _notificationPayload;

  bool get hasLoaded => _channel != null;
  bool get pagePlaying => _pagePlaying;
  VShotsPlaybackState get playbackState => _playbackState;
  int get generation => _generation;

  /// Loads a new track. [autoplay] is a single system request, not a promise
  /// to keep forcing playback if the player buffers or the user pauses.
  Future<void> load(String url, {bool autoplay = true}) async {
    if (_disposed) return;
    _generation++;
    _lastUrl = url;
    _pendingUrl = url;
    _pendingAutoplay = autoplay;
    _autoplayPending = autoplay;
    _userPaused = false;
    _setPlaybackState(VShotsPlaybackState.loading, false);

    final channel = _channel;
    if (channel == null) return;
    await _sendLoad(channel, url, _generation, autoplay);
  }

  Future<void> _sendLoad(
    MethodChannel channel,
    String url,
    int generation,
    bool autoplay,
  ) async {
    try {
      await channel.invokeMethod<void>('load', <String, Object?>{
        'url': url,
        'generation': generation,
        'autoplay': autoplay,
      });
    } catch (_) {
      if (!_disposed && generation == _generation) {
        onError('Could not open this video');
      }
    }
  }

  /// Retry is an explicit user action and starts one fresh load. It does not
  /// use a native reload/autoplay loop.
  Future<void> retry() async {
    final url = _lastUrl;
    if (url == null) return;
    await load(url, autoplay: true);
  }

  /// The UI may expose one toggle, but it is translated into an explicit
  /// PLAY or PAUSE command before crossing the platform boundary.
  Future<bool?> togglePagePlayback() async {
    if (_channel == null) return null;
    if (_pagePlaying) {
      await pause();
      return false;
    }
    await play();
    return true;
  }

  /// Explicit user/system PAUSE. User pause is recorded before the platform
  /// command so late page-finished, ad, or lifecycle callbacks cannot restart.
  Future<void> pause({bool userInitiated = true}) async {
    if (userInitiated) _userPaused = true;
    _autoplayPending = false;
    final channel = _channel;
    if (channel == null) {
      _setPlaybackState(VShotsPlaybackState.paused, false);
      return;
    }
    try {
      await channel.invokeMethod<void>(userInitiated ? 'pause' : 'focusPause');
    } catch (_) {}
    _setPlaybackState(VShotsPlaybackState.paused, false);
  }

  /// Explicit PLAY. It is never implemented as a toggle.
  Future<void> play({bool userInitiated = true}) async {
    if (userInitiated) {
      _userPaused = false;
    }
    _autoplayPending = false;
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('play');
    } catch (_) {}
  }

  /// Audio-focus ducking: set the real media element's volume (0..1).
  Future<void> setVolume(double volume) async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('setVolume', volume);
    } catch (_) {}
  }

  /// Seek the real HTML media element without recreating or resizing the WebView.
  Future<void> seekBy(int seconds) async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('seekBy', seconds);
    } catch (_) {}
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
    } catch (_) {
      // Older native view / not ready — non-fatal.
    }
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
    if (pending != null) {
      unawaited(_sendLoad(channel, pending, _generation, _pendingAutoplay));
    }
    unawaited(_sendNotificationUpdate(channel));
  }

  Future<void> _pushAdAssist(MethodChannel channel) async {
    try {
      await channel.invokeMethod<void>(
        'setAdAssist',
        RemoteFeatureFlags.instance.enableYoutubeAdAssist,
      );
    } catch (_) {
      // Older native view / not ready — non-fatal.
    }
  }

  Future<void> applyAdAssist() async {
    final channel = _channel;
    if (channel == null) return;
    await _pushAdAssist(channel);
  }

  int? _eventGeneration(Object? arguments) {
    if (arguments is Map) {
      final value = arguments['generation'];
      if (value is num) return value.toInt();
    }
    // Test hooks and older platform views had no generation payload. Treat
    // those events as belonging to the active session.
    return null;
  }

  bool _isCurrentEvent(Object? arguments) {
    final eventGeneration = _eventGeneration(arguments);
    return eventGeneration == null || eventGeneration == _generation;
  }

  Future<void> _handleNativeEvent(MethodCall call) async {
    if (_disposed) return;
    switch (call.method) {
      case 'pageStarted':
        if (_isCurrentEvent(call.arguments)) {
          _setPlaybackState(VShotsPlaybackState.loading, false);
          onPageStarted();
        }
        break;
      case 'pageFinished':
        if (!_isCurrentEvent(call.arguments)) break;
        onPageFinished();
        // Exactly one controlled SYSTEM_AUTOPLAY request. Page load and
        // lifecycle callbacks never call play by themselves.
        if (_autoplayPending && !_userPaused) {
          _autoplayPending = false;
          unawaited(play(userInitiated: false));
        }
        break;
      case 'playbackState':
        if (!_isCurrentEvent(call.arguments)) break;
        final arguments = call.arguments;
        final playing =
            arguments is Map ? arguments['playing'] == true : arguments == true;
        final nativeState = arguments is Map ? arguments['state'] : null;
        final state = nativeState == null
            ? (playing
                ? VShotsPlaybackState.playing
                : VShotsPlaybackState.paused)
            : playbackStateFromNative(nativeState);
        _setPlaybackState(state, playing);
        break;
      case 'videoEnded':
        if (!_isCurrentEvent(call.arguments)) break;
        final endedId = extractYoutubeVideoId(_lastUrl ?? '') ?? '';
        onVideoEnded?.call(endedId);
        break;
      case 'adState':
        onAdState?.call(call.arguments == true);
        break;
      case 'notificationAction':
        final action = call.arguments?.toString() ?? '';
        if (action.isNotEmpty) await onNotificationAction?.call(action);
        break;
      case 'blocked':
        contentBlocker.recordBlocked(call.arguments?.toString() ?? '');
        break;
      case 'error':
        if (_isCurrentEvent(call.arguments)) {
          final arguments = call.arguments;
          final message = arguments is Map
              ? arguments['message']?.toString()
              : arguments?.toString();
          _setPlaybackState(VShotsPlaybackState.error, false);
          onError(
            message == null || message.isEmpty
                ? 'Playback failed — please retry'
                : message,
          );
        }
        break;
    }
  }

  void _setPlaybackState(VShotsPlaybackState state, bool playing) {
    final stateChanged = _playbackState != state;
    final playingChanged = _pagePlaying != playing;
    if (!stateChanged && !playingChanged) return;
    _playbackState = state;
    _pagePlaying = playing;
    if (playingChanged) onPlaybackState?.call(playing);
    onPlaybackStateChanged?.call(state, playing);
  }

  /// Updates track metadata only. The native player remains the authority for
  /// whether playback is active; the supplied flag is a snapshot for legacy
  /// callers and is not allowed to start playback or request audio focus.
  Future<void> updateNotification({
    required String title,
    required String artist,
    required String artwork,
    required bool playing,
  }) async {
    _notificationPayload = <String, Object?>{
      'title': title,
      'artist': artist,
      'artwork': artwork,
      'playing': playing,
      'generation': _generation,
    };
    await _sendNotificationUpdate(_channel);
  }

  Future<void> _sendNotificationUpdate(MethodChannel? channel) async {
    final payload = _notificationPayload;
    if (channel == null || payload == null || _disposed) return;
    try {
      await channel.invokeMethod<void>('updateNotification', payload);
    } catch (_) {}
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    final channel = _channel;
    _channel = null;
    _pendingUrl = null;
    _lastUrl = null;
    _autoplayPending = false;
    _userPaused = true;
    _pagePlaying = false;
    if (channel != null) {
      unawaited(channel.invokeMethod<void>('dispose'));
      channel.setMethodCallHandler(null);
    }
  }

  /// Test hook: dispatch a native event without a real platform channel.
  @visibleForTesting
  Future<void> debugHandleNativeEvent(MethodCall call) =>
      _handleNativeEvent(call);
}

String browserWatchUrl(String videoId) => youtubeWatchUrl(videoId);
