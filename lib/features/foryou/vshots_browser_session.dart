// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Native Discovery YouTube/WebView browser session
// ═════════════════════════════════════════════════════════════════════════════
//
// This class is the ONE owner of the playback state machine. It is the only
// place in the app that decides WHAT playback should be doing and WHY it is not
// doing it. The native WebView observes media and executes commands; it never
// decides policy. The native playback service reports audio focus and
// lifecycle reasons; it never decides policy either.
//
//   user / notification / OS reason  →  session intent + pause reason
//   session                          →  explicit command across the channel
//   native WebView                   →  observed transport + audio truth
//   session                          →  ONE authoritative state / callback
//   Flutter UI, notification         ←  that same state
//
// INVARIANTS
// ----------
//  1. Page loading is not playback. A load may request exactly ONE system
//     autoplay after the matching page-finish. No callback starts a second one.
//  2. An explicit user pause is final: nothing in this file can leave
//     [VShotsPlaybackState.pausedByUser] except an explicit Play.
//  3. An interruption pause (audio focus, lifecycle) may resume only while the
//     standing intent is still [VShotsPlaybackIntent.play] — and only once, for
//     the specific interruption that caused it. There is no retry loop.
//  4. The browser is allowed a SMALL, BOUNDED budget of divergence corrections
//     per load. When the budget is exhausted the divergence is reported
//     honestly as [VShotsPlaybackState.pausedByBrowser] instead of being
//     hidden by an endless play/pause fight.
//  5. Muted playback is never reported as audible playback.
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
  final String h = host.toLowerCase();
  if (h.isEmpty) return false;
  if (h == 'api.jiosaavn.com' || h.endsWith('.api.jiosaavn.com')) {
    return false;
  }
  if (h == 'saavn.me' || h.endsWith('.saavn.me')) return false;
  const List<String> allowed = <String>[
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
  return allowed.any((String a) => h == a || h.endsWith('.$a'));
}

bool isAllowedBrowserUrl(String url) {
  final Uri? uri = Uri.tryParse(url.trim());
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
    this.onPosition,
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

  /// Position/duration snapshots from the real HTML media element.
  final void Function(int positionMs, int durationMs)? onPosition;

  /// Compatibility boolean snapshot for lightweight consumers. It is DERIVED
  /// from the authoritative state — never independently maintained.
  final void Function(bool playing)? onPlaybackState;

  /// The authoritative state, consumed by the browser controller and the UI.
  final void Function(VShotsPlaybackState state, bool playing)?
      onPlaybackStateChanged;

  final Future<void> Function(String action)? onNotificationAction;

  /// The general-purpose content blocker for this browser session. Owned here
  /// (NOT by the playback manager) — independent from playback.
  final VShotsContentBlocker contentBlocker;

  /// Divergence corrections allowed per load. Two is enough to absorb a real
  /// browser hiccup and far too few to become a play/pause fight.
  static const int _maxDivergenceCorrectionsPerLoad = 2;

  /// Minimum spacing between two divergence corrections.
  static const Duration _minCorrectionGap = Duration(milliseconds: 1500);

  /// Audio-focus duck level for transient interruptions (navigation prompts,
  /// notifications speaking).
  static const double _duckVolume = 0.15;

  MethodChannel? _channel;
  String? _lastUrl;
  String? _pendingUrl;
  bool _pendingAutoplay = true;
  int _generation = 0;
  bool _disposed = false;
  Map<String, Object?>? _notificationPayload;

  // ── The authoritative machine ───────────────────────────────────────────
  VShotsPlaybackState _state = VShotsPlaybackState.idle;
  VShotsPlaybackIntent _intent = VShotsPlaybackIntent.none;
  VShotsPauseReason _pauseReason = VShotsPauseReason.none;

  /// True while the app is backgrounded. Background playback is a product
  /// feature, so this NEVER pauses by itself — it only classifies a pause the
  /// platform caused as [VShotsPlaybackState.pausedByLifecycle] instead of
  /// reporting a phantom user pause.
  bool _backgrounded = false;

  /// Set by a transient audio-focus loss; consumed by the matching GAIN.
  bool _focusLossLatch = false;

  /// True while a transient CAN_DUCK interruption has us at reduced volume.
  bool _ducked = false;

  /// One system autoplay request is allowed per load, after page finish.
  bool _awaitingPagePlay = false;

  /// Remaining divergence corrections for the current load.
  int _correctionsLeft = _maxDivergenceCorrectionsPerLoad;
  DateTime? _lastCorrectionAt;

  /// Bumped when the native WebView renderer dies. The widget layer keys the
  /// platform view on this value, so a fresh WebView is mounted and the last
  /// URL is re-loaded. Bounded to one remount per load — never a loop.
  int _viewEpoch = 0;
  bool _remountUsed = false;

  /// Version of the platform view this session currently wants mounted.
  int get viewEpoch => _viewEpoch;

  bool get hasLoaded => _channel != null;

  /// The authoritative playback state.
  VShotsPlaybackState get playbackState => _state;

  /// What the app currently wants the player to do.
  VShotsPlaybackIntent get intent => _intent;

  /// Why playback is currently paused.
  VShotsPauseReason get pauseReason => _pauseReason;

  /// Transport is running (may still be muted).
  bool get pagePlaying => _state.isTransportRunning;

  /// Remaining automatic resume corrections for the current load. Exposed for
  /// tests so the "no unbounded retry" invariant is directly assertable.
  @visibleForTesting
  int get divergenceCorrectionsLeft => _correctionsLeft;

  @visibleForTesting
  bool get isBackgrounded => _backgrounded;

  int get generation => _generation;

  // ── Commands ────────────────────────────────────────────────────────────

  /// Loads a new track. [autoplay] is a single standing intent to play, not a
  /// promise to keep forcing playback if the browser buffers or the user
  /// pauses.
  Future<void> load(String url, {bool autoplay = true}) async {
    if (_disposed) return;
    _generation++;
    _lastUrl = url;
    _pendingUrl = url;
    _pendingAutoplay = autoplay;
    _intent = autoplay ? VShotsPlaybackIntent.play : VShotsPlaybackIntent.pause;
    _pauseReason = autoplay ? VShotsPauseReason.none : VShotsPauseReason.user;
    _focusLossLatch = false;
    _ducked = false;
    _awaitingPagePlay = autoplay;
    _correctionsLeft = _maxDivergenceCorrectionsPerLoad;
    _lastCorrectionAt = null;
    _remountUsed = false;
    _setState(VShotsPlaybackState.loading);

    final MethodChannel? channel = _channel;
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
        _intent = VShotsPlaybackIntent.none;
        _setState(VShotsPlaybackState.error);
        onError('Could not open this video');
      }
    }
  }

  /// Retry is an explicit user action and starts one fresh load. It does not
  /// use a native reload/autoplay loop.
  Future<void> retry() async {
    final String? url = _lastUrl;
    if (url == null) return;
    await load(url, autoplay: true);
  }

  /// The UI may expose one toggle, but it is translated into an explicit PLAY
  /// or PAUSE command before crossing the platform boundary. The decision uses
  /// the authoritative TRANSPORT state, so a muted-but-running player pauses
  /// (rather than being mistaken for "not playing").
  Future<bool?> togglePagePlayback() async {
    if (_channel == null) return null;
    if (_state.isTransportRunning) {
      await pause();
      return false;
    }
    await play();
    return true;
  }

  /// Explicit user/system PAUSE.
  ///
  /// [userInitiated] distinguishes "the user pressed Pause" from "the OS told
  /// us play must stop for a moment". The two produce different states and
  /// different resume rules. A user pause always clears any pending automatic
  /// resume.
  Future<void> pause({bool userInitiated = true}) async {
    _intent = VShotsPlaybackIntent.pause;
    _pauseReason =
        userInitiated ? VShotsPauseReason.user : VShotsPauseReason.audioFocus;
    _awaitingPagePlay = false;
    if (userInitiated) _focusLossLatch = false;

    final MethodChannel? channel = _channel;
    final int generation = _generation;
    if (channel == null) {
      _setState(
        userInitiated
            ? VShotsPlaybackState.pausedByUser
            : VShotsPlaybackState.pausedByAudioFocus,
      );
      return;
    }
    try {
      await channel.invokeMethod<void>(
        userInitiated ? 'pause' : 'focusPause',
        <String, Object?>{'generation': generation},
      );
    } catch (_) {}
    _setState(
      userInitiated
          ? VShotsPlaybackState.pausedByUser
          : VShotsPlaybackState.pausedByAudioFocus,
    );
  }

  /// Explicit PLAY. It is never implemented as a toggle.
  ///
  /// The intent becomes PLAY and the state becomes [VShotsPlaybackState.
  /// buffering] — we asked for playback but nothing has been observed yet.
  /// Announcing PLAYING here would be exactly the lie this refactor removes.
  Future<void> play({bool userInitiated = true}) async {
    _intent = VShotsPlaybackIntent.play;
    _pauseReason = VShotsPauseReason.none;
    _awaitingPagePlay = false;
    if (userInitiated) {
      _focusLossLatch = false;
      // A deliberate user Play earns a fresh divergence budget: the user has
      // just re-affirmed the intent, so absorbing one more browser hiccup is
      // correct. It is still bounded.
      _correctionsLeft = _maxDivergenceCorrectionsPerLoad;
      _lastCorrectionAt = null;
    }
    // The intent is recorded first and the state always reflects it, even
    // when the platform view has not been attached yet (a Play tapped during
    // mount must not leave the UI showing a pause).
    _setState(VShotsPlaybackState.buffering);
    final MethodChannel? channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>(
        'play',
        <String, Object?>{'generation': _generation},
      );
    } catch (_) {}
  }

  /// Audio-focus ducking: set the real media element's volume (0..1).
  Future<void> setVolume(double volume) async {
    final MethodChannel? channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('setVolume', <String, Object?>{
        'volume': volume,
        'generation': _generation,
      });
    } catch (_) {}
  }

  /// Seek the real HTML media element without recreating or resizing the
  /// WebView. A seek is not a playback intent: the state is untouched and the
  /// next observed transport event stays authoritative.
  Future<void> seekBy(int seconds) async {
    final MethodChannel? channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('seekBy', <String, Object?>{
        'seconds': seconds,
        'generation': _generation,
      });
    } catch (_) {}
  }

  /// Absolute seek used by the premium progress control. It is an explicit
  /// command; it never starts, pauses, or toggles playback.
  Future<void> seekTo(Duration position) async {
    final MethodChannel? channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('seekTo', <String, Object?>{
        'positionMs': position.inMilliseconds,
        'generation': _generation,
      });
    } catch (_) {}
  }

  // ── Interruption reasons (owned by the OS-facing native service) ────────

  /// Reports an Android audio-focus transition. This is a REASON, not a
  /// playback command: all policy lives in this class.
  ///
  /// [change] is one of `loss`, `loss_transient`, `gain`, `duck_on`,
  /// `duck_off`.
  Future<void> handleAudioFocus(String change) async {
    if (_disposed) return;
    switch (change) {
      case 'loss':
        // Permanent loss: stop cleanly. Never auto-resumes.
        _focusLossLatch = false;
        _intent = VShotsPlaybackIntent.pause;
        _pauseReason = VShotsPauseReason.audioFocus;
        _awaitingPagePlay = false;
        await _sendSimple('focusPause');
        _setState(VShotsPlaybackState.pausedByAudioFocus);
        break;
      case 'loss_transient':
        // Only remember the interruption if playback was actually wanted.
        _focusLossLatch = _intent == VShotsPlaybackIntent.play ||
            _state.isTransportRunning ||
            _state == VShotsPlaybackState.buffering;
        _pauseReason = VShotsPauseReason.audioFocus;
        _awaitingPagePlay = false;
        await _sendSimple('focusPause');
        _setState(VShotsPlaybackState.pausedByAudioFocus);
        break;
      case 'gain':
        if (_ducked) {
          // A transient sound finished: restore the volume we reduced. This is
          // volume-only and can never resume or pause anything.
          _ducked = false;
          await setVolume(1.0);
        }
        if (_focusLossLatch) {
          _focusLossLatch = false;
          if (_intent == VShotsPlaybackIntent.play &&
              _pauseReason == VShotsPauseReason.audioFocus) {
            // The focus we are regaining is the one whose loss paused us, and
            // the user has not paused since. Resume exactly once.
            _pauseReason = VShotsPauseReason.none;
            await _sendSimple('focusPlay');
            _setState(VShotsPlaybackState.buffering);
            return;
          }
        }
        // No latch, or the intent is no longer PLAY (the user paused while
        // focus was away): stay exactly as we are. A focus gain is NOT allowed
        // to change the state or to "explain away" a user pause.
        break;
      case 'duck_on':
        _ducked = true;
        await setVolume(_duckVolume);
        break;
      case 'duck_off':
        _ducked = false;
        await setVolume(1.0);
        break;
      case 'becoming_noisy':
        // The audio route went away (headphones unplugged, Bluetooth
        // disconnected). Pausing is the expected, safe behaviour, and it is
        // treated as a deliberate stop so nothing auto-resumes when the route
        // comes back: only an explicit Play restarts playback.
        _ducked = false;
        _focusLossLatch = false;
        await pause();
        break;
    }
  }

  /// Lifecycle is a REASON, never a pause command: keeping audio alive while
  /// the app is backgrounded or the screen is locked is a product feature.
  void setBackgrounded(bool backgrounded) {
    if (_disposed || _backgrounded == backgrounded) return;
    _backgrounded = backgrounded;
    if (backgrounded) return;
    // Returning to the foreground: recover a lifecycle pause exactly once,
    // through the same bounded correction budget as any other divergence.
    if (_state == VShotsPlaybackState.pausedByLifecycle &&
        _intent == VShotsPlaybackIntent.play) {
      _pauseReason = VShotsPauseReason.none;
      _tryCorrection(allowFromLifecycle: true);
    }
  }

  Future<void> _sendSimple(String method) async {
    final MethodChannel? channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>(
        method,
        <String, Object?>{'generation': _generation},
      );
    } catch (_) {}
  }

  // ── Native event ingestion ──────────────────────────────────────────────

  /// Applies one observed transport observation from the native WebView.
  ///
  /// [wireState] uses the shared vocabulary in `vshots_playback_state.dart`.
  /// [hasAudio] is native audio truth when the platform reports it; a
  /// `playing_with_audio` wire state implies it.
  @visibleForTesting
  void applyObservedTransport({
    required String wireState,
    bool? hasAudio,
  }) {
    if (_disposed) return;
    final VShotsPlaybackState observed = playbackStateFromNative(wireState);
    switch (observed) {
      case VShotsPlaybackState.loading:
        if (_intent == VShotsPlaybackIntent.play) {
          _setState(VShotsPlaybackState.loading);
        }
        break;
      case VShotsPlaybackState.buffering:
        if (_intent == VShotsPlaybackIntent.play) {
          // Buffering is a real, honest state. It must never be smoothed into
          // PLAYING just to keep the notification cheerful.
          _setState(VShotsPlaybackState.buffering);
        }
        break;
      case VShotsPlaybackState.playingMuted:
      case VShotsPlaybackState.playingWithAudio:
        if (_intent != VShotsPlaybackIntent.play) {
          _correctDivergence();
          return;
        }
        _pauseReason = VShotsPauseReason.none;
        final bool audible =
            hasAudio ?? (observed == VShotsPlaybackState.playingWithAudio);
        _setState(
          audible
              ? VShotsPlaybackState.playingWithAudio
              : VShotsPlaybackState.playingMuted,
        );
        break;
      case VShotsPlaybackState.pausedByUser:
      case VShotsPlaybackState.pausedByAudioFocus:
      case VShotsPlaybackState.pausedByLifecycle:
      case VShotsPlaybackState.pausedByBrowser:
        _applyObservedPause(observed);
        break;
      case VShotsPlaybackState.ended:
        _intent = VShotsPlaybackIntent.none;
        _pauseReason = VShotsPauseReason.none;
        _awaitingPagePlay = false;
        _setState(VShotsPlaybackState.ended);
        break;
      case VShotsPlaybackState.error:
        _intent = VShotsPlaybackIntent.none;
        _pauseReason = VShotsPauseReason.none;
        _setState(VShotsPlaybackState.error);
        break;
      case VShotsPlaybackState.idle:
        // 'none' / 'unknown' observations keep the current state.
        break;
    }
  }

  /// Classifies a pause the browser reported.
  ///
  /// This is the single place where "the user paused", "focus took the audio
  /// away", "the app was backgrounded" and "the browser just paused" stop
  /// being the same event.
  void _applyObservedPause(VShotsPlaybackState observed) {
    if (_intent == VShotsPlaybackIntent.pause) {
      // We asked for this pause; report the reason we recorded, preferring an
      // explicit reason carried by the observation itself.
      final VShotsPauseReason reason =
          observed == VShotsPlaybackState.pausedByUser
              ? VShotsPauseReason.user
              : _pauseReason;
      _pauseReason = reason;
      _setState(_stateFor(_pauseReason));
      return;
    }

    // Explicit reasons carried by the observation always win.
    if (observed == VShotsPlaybackState.pausedByUser) {
      _intent = VShotsPlaybackIntent.pause;
      _pauseReason = VShotsPauseReason.user;
      _focusLossLatch = false;
      _setState(VShotsPlaybackState.pausedByUser);
      return;
    }
    if (observed == VShotsPlaybackState.pausedByAudioFocus) {
      _pauseReason = VShotsPauseReason.audioFocus;
      _setState(VShotsPlaybackState.pausedByAudioFocus);
      return;
    }
    if (observed == VShotsPlaybackState.pausedByLifecycle) {
      _pauseReason = VShotsPauseReason.lifecycle;
      _setState(VShotsPlaybackState.pausedByLifecycle);
      return;
    }

    // A bare 'paused' observation with a standing PLAY intent. Attribute it to
    // whatever interruption is currently outstanding before calling it a
    // divergence.
    if (_focusLossLatch) {
      _pauseReason = VShotsPauseReason.audioFocus;
      _setState(VShotsPlaybackState.pausedByAudioFocus);
      return;
    }
    if (_backgrounded) {
      _pauseReason = VShotsPauseReason.lifecycle;
      _setState(VShotsPlaybackState.pausedByLifecycle);
      return;
    }
    _pauseReason = VShotsPauseReason.browser;
    _setState(VShotsPlaybackState.pausedByBrowser);
    _tryCorrection();
  }

  VShotsPlaybackState _stateFor(VShotsPauseReason reason) => switch (reason) {
        VShotsPauseReason.user => VShotsPlaybackState.pausedByUser,
        VShotsPauseReason.audioFocus => VShotsPlaybackState.pausedByAudioFocus,
        VShotsPauseReason.lifecycle => VShotsPlaybackState.pausedByLifecycle,
        VShotsPauseReason.browser => VShotsPlaybackState.pausedByBrowser,
        VShotsPauseReason.none => VShotsPlaybackState.pausedByBrowser,
      };

  /// Re-asserts the standing intent against a divergent browser.
  ///
  /// This is deliberately NOT a retry loop: it is bounded per load, spaced by
  /// a minimum gap, and only ever runs while the intent is still PLAY. Once the
  /// budget is gone the session keeps reporting `pausedByBrowser` so the user
  /// (and the notification) see the truth instead of a hidden fight.
  void _tryCorrection({bool allowFromLifecycle = false}) {
    if (_disposed) return;
    if (_correctionsLeft <= 0) return;
    if (_state == VShotsPlaybackState.ended ||
        _state == VShotsPlaybackState.error) {
      return;
    }
    final bool recoverable = _state == VShotsPlaybackState.pausedByBrowser ||
        (allowFromLifecycle && _state == VShotsPlaybackState.pausedByLifecycle);
    if (!recoverable) return;
    if (_intent != VShotsPlaybackIntent.play) return;
    final DateTime now = DateTime.now();
    final DateTime? last = _lastCorrectionAt;
    if (last != null && now.difference(last) < _minCorrectionGap) return;

    _correctionsLeft--;
    _lastCorrectionAt = now;
    debugPrint(
      '[VShotsPlayer] re-asserting play intent '
      '(remaining corrections=$_correctionsLeft)',
    );
    unawaited(_sendSimple('play'));
  }

  /// Corrects the opposite divergence: the user asked for PAUSE but the
  /// browser kept playing. Shares the same bounded budget.
  void _correctDivergence() {
    if (_disposed || _correctionsLeft <= 0) return;
    final DateTime now = DateTime.now();
    final DateTime? last = _lastCorrectionAt;
    if (last != null && now.difference(last) < _minCorrectionGap) return;
    _correctionsLeft--;
    _lastCorrectionAt = now;
    unawaited(
      _sendSimple(
        _pauseReason == VShotsPauseReason.user ? 'pause' : 'focusPause',
      ),
    );
  }

  // ── Widget / channel plumbing ───────────────────────────────────────────

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
      // The key changes ONLY when a dead renderer has to be replaced, which is
      // what makes Flutter mount a brand new platform view. An ordinary rebuild
      // reuses the same element and therefore the same WebView.
      key: ValueKey<String>('vshots-browser-$_viewEpoch'),
      viewType: 'vshots/native_browser',
      layoutDirection: TextDirection.ltr,
      onPlatformViewCreated: _attachPlatformView,
    );
  }

  Future<void> _pushContentBlocker(MethodChannel channel) async {
    await contentBlocker.initialize();
    try {
      await channel.invokeMethod<void>('setContentBlocker', <String, Object?>{
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
    final MethodChannel? channel = _channel;
    if (channel == null) return;
    await _pushContentBlocker(channel);
  }

  void _attachPlatformView(int viewId) {
    if (_disposed) return;
    final MethodChannel channel = MethodChannel('vshots/browser/$viewId');
    _channel = channel;
    channel.setMethodCallHandler(_handleNativeEvent);
    unawaited(_pushContentBlocker(channel));
    unawaited(_pushAdAssist(channel));
    final String? pending = _pendingUrl;
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
    final MethodChannel? channel = _channel;
    if (channel == null) return;
    await _pushAdAssist(channel);
  }

  int? _eventGeneration(Object? arguments) {
    if (arguments is Map) {
      final Object? value = arguments['generation'];
      if (value is num) return value.toInt();
    }
    // Test hooks and older platform views had no generation payload. Treat
    // those events as belonging to the active session.
    return null;
  }

  bool _isCurrentEvent(Object? arguments) {
    final int? eventGeneration = _eventGeneration(arguments);
    return eventGeneration == null || eventGeneration == _generation;
  }

  Future<void> _handleNativeEvent(MethodCall call) async {
    if (_disposed) return;
    switch (call.method) {
      case 'pageStarted':
        if (_isCurrentEvent(call.arguments)) {
          if (_intent == VShotsPlaybackIntent.play) {
            _setState(VShotsPlaybackState.loading);
          }
          onPageStarted();
        }
        break;
      case 'pageFinished':
        if (!_isCurrentEvent(call.arguments)) break;
        onPageFinished();
        // Exactly one controlled SYSTEM_AUTOPLAY request per load. Page load
        // and lifecycle callbacks never call play by themselves.
        if (_awaitingPagePlay && _intent == VShotsPlaybackIntent.play) {
          _awaitingPagePlay = false;
          unawaited(_sendSimple('play'));
        }
        break;
      case 'playbackState':
        if (!_isCurrentEvent(call.arguments)) break;
        final Object? arguments = call.arguments;
        final bool? hasAudio =
            arguments is Map ? (arguments['hasAudio'] as bool?) : null;
        final Object? nativeState = arguments is Map
            ? arguments['state']
            : (arguments == true ? 'playing_muted' : 'paused');
        // A legacy payload without an explicit state may only claim that the
        // transport runs — never that audio is audible.
        applyObservedTransport(
          wireState: nativeState?.toString() ??
              ((arguments is Map && arguments['playing'] == true)
                  ? 'playing_muted'
                  : 'idle'),
          hasAudio: hasAudio,
        );
        break;
      case 'videoEnded':
        if (!_isCurrentEvent(call.arguments)) break;
        final String endedId = extractYoutubeVideoId(_lastUrl ?? '') ?? '';
        onVideoEnded?.call(endedId);
        break;
      case 'adState':
        if (_isCurrentEvent(call.arguments)) {
          onAdState?.call(call.arguments == true);
        }
        break;
      case 'audioFocus':
        await handleAudioFocus(call.arguments?.toString() ?? '');
        break;
      case 'position':
        if (!_isCurrentEvent(call.arguments)) break;
        final Object? positionArguments = call.arguments;
        if (positionArguments is Map) {
          final int? position =
              (positionArguments['positionMs'] as num?)?.toInt();
          final int? duration =
              (positionArguments['durationMs'] as num?)?.toInt();
          if (position != null && duration != null) {
            onPosition?.call(position, duration);
          }
        }
        break;
      case 'notificationAction':
        final String action = call.arguments?.toString() ?? '';
        if (action.isNotEmpty) await onNotificationAction?.call(action);
        break;
      case 'blocked':
        contentBlocker.recordBlocked(call.arguments?.toString() ?? '');
        break;
      case 'error':
        if (_isCurrentEvent(call.arguments)) {
          final Object? arguments = call.arguments;
          final String message = arguments is Map
              ? arguments['message']?.toString() ?? ''
              : arguments?.toString() ?? '';
          _intent = VShotsPlaybackIntent.none;
          _pauseReason = VShotsPauseReason.none;
          final String reason =
              arguments is Map ? arguments['reason']?.toString() ?? '' : '';
          if (reason == 'renderer-gone') {
            _recoverFromDeadRenderer();
          }
          _setState(VShotsPlaybackState.error);
          onError(
            message.isEmpty ? 'Playback failed — please retry' : message,
          );
        }
        break;
    }
  }

  /// Replaces a WebView whose renderer process died.
  ///
  /// Android kills WebView renderers under memory pressure. Without this the
  /// player would be left pointing at a dead view and every later command would
  /// be swallowed silently. We remount ONCE per load: if the replacement also
  /// dies, the error is reported and the user is asked to retry rather than
  /// being put into a recreate loop.
  void _recoverFromDeadRenderer() {
    if (_remountUsed) return;
    _remountUsed = true;
    _viewEpoch++;
    _channel = null;
    _pendingUrl = _lastUrl;
    _pendingAutoplay = _intent == VShotsPlaybackIntent.play;
    _awaitingPagePlay = _pendingAutoplay;
    _correctionsLeft = _maxDivergenceCorrectionsPerLoad;
    _lastCorrectionAt = null;
    debugPrint('[VShotsPlayer] remounting platform view after renderer loss');
  }

  /// The single state publisher. Every consumer (controller, UI, notification
  /// inputs) observes this and nothing else.
  void _setState(VShotsPlaybackState next) {
    final bool stateChanged = _state != next;
    final bool playingChanged = _state.asPlayingFlag != next.asPlayingFlag;
    if (!stateChanged && !playingChanged) return;
    _state = next;
    if (playingChanged) onPlaybackState?.call(next.asPlayingFlag);
    onPlaybackStateChanged?.call(next, next.asPlayingFlag);
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
    final Map<String, Object?>? payload = _notificationPayload;
    if (channel == null || payload == null || _disposed) return;
    try {
      await channel.invokeMethod<void>('updateNotification', payload);
    } catch (_) {}
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    final MethodChannel? channel = _channel;
    _channel = null;
    _pendingUrl = null;
    _lastUrl = null;
    _awaitingPagePlay = false;
    _intent = VShotsPlaybackIntent.none;
    _pauseReason = VShotsPauseReason.none;
    _state = VShotsPlaybackState.idle;
    if (channel != null) {
      unawaited(channel.invokeMethod<void>('dispose'));
      channel.setMethodCallHandler(null);
    }
  }

  /// Test hook: attach a deterministic MethodChannel without a real Android
  /// platform view. Production uses [AndroidView.onPlatformViewCreated].
  @visibleForTesting
  void debugAttachPlatformView(int viewId) => _attachPlatformView(viewId);

  /// Test hook: dispatch a native event without a real platform channel.
  @visibleForTesting
  Future<void> debugHandleNativeEvent(MethodCall call) =>
      _handleNativeEvent(call);
}

String browserWatchUrl(String videoId) => youtubeWatchUrl(videoId);
