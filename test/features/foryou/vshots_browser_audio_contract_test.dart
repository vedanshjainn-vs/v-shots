// ═════════════════════════════════════════════════════════════════════════════
// V Shots — player architecture contract
//
// These are source-level contract tests. They exist because the player spans
// Dart, Kotlin and a WebView, and the regressions that mattered were
// architectural, not local: a synthetic touch creeping back in, a retry loop
// reappearing, a state being reported as audible when it is muted.
//
// Each assertion below pins a decision that was made deliberately.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _platformViewPath =
    'android/app/src/main/kotlin/com/vshots/live/VShotsBrowserPlatformView.kt';
const String _servicePath =
    'android/app/src/main/kotlin/com/vshots/live/VShotsBrowserPlaybackService.kt';
const String _sessionPath = 'lib/features/foryou/vshots_browser_session.dart';
const String _statePath = 'lib/features/foryou/vshots_playback_state.dart';
const String _sheetPath = 'lib/features/foryou/discovery_browser_sheet.dart';

String _read(String path) => File(path).readAsStringSync();

/// Source with comments removed.
///
/// The negative ("must NOT contain") assertions below are about CODE. The files
/// deliberately document the regressions that were removed, so a raw source
/// check would trip over its own explanation.
String _code(String path) {
  final String source = _read(path);
  final String withoutBlocks =
      source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ');
  return withoutBlocks.split('\n').map((String line) {
    final int marker = line.indexOf('//');
    return marker >= 0 ? line.substring(0, marker) : line;
  }).join('\n');
}

void main() {
  group('native platform view', () {
    test('is a pure observer: event driven, never DOM polling', () {
      final String source = _read(_platformViewPath);

      // Real media events, delivered through a token-guarded bridge.
      expect(source, contains('@JavascriptInterface'));
      expect(source, contains('addJavascriptInterface'));
      expect(source, contains('"VShotsNative"'));
      expect(source, contains('bootstrapScript'));
      expect(source, contains('addEventListener(events[i], publish, true)'));
      expect(source, contains("'play','pause','playing','waiting','seeking'"));
      expect(source, contains('bridgeToken'));

      // The one remaining periodic evaluation is read-only reconciliation.
      expect(source, contains('YT_RECONCILE_JS'));
      expect(
        source,
        isNot(contains('YT_POLL_JS')),
        reason: 'the 1 Hz full-document scrape must not come back',
      );
      expect(
        source,
        isNot(contains('YT_POSITION_JS')),
        reason: 'position rides the read-only reconciliation now',
      );
    });

    test('never fabricates a trusted gesture', () {
      final String source = _code(_platformViewPath);

      expect(source, isNot(contains('performTrustedUnmuteTap')));
      expect(source, isNot(contains('trustedTouchInFlight')));
      expect(source, isNot(contains('SOURCE_TOUCHSCREEN')));
      expect(source, isNot(contains('MotionEvent.obtain')));
      expect(source, isNot(contains('unmute-target')));
      expect(
        source,
        isNot(contains('override fun dispatchTouchEvent')),
        reason: 'swallowing every touch is what broke Discovery swipes',
      );
      expect(source, isNot(contains('override fun onTouchEvent')));
    });

    test('routes gestures inside the page instead of at the view layer', () {
      final String source = _read(_platformViewPath);

      expect(source, contains('.html5-video-player * { pointer-events: none'));
      expect(source, contains('vshots-gesture-shield'));
      // The two controls we deliberately delegate to YouTube stay reachable.
      expect(source, contains('.ytp-unmute'));
      expect(source, contains('.ytp-ad-skip-button'));
    });

    test('has no pause-recovery retry loop', () {
      final String source = _code(_platformViewPath);

      expect(source, isNot(contains('recoverUnexpectedPause')));
      expect(source, isNot(contains('pauseRecoveryAttempts')));
      expect(source, isNot(contains('maxPauseRecoveryAttempts')));
      expect(source, isNot(contains('unexpectedPauseSinceMs')));
    });

    test('cannot leave content permanently muted', () {
      final String source = _code(_platformViewPath);

      // Ad muting is an explicit flag with an unconditional release.
      expect(source, contains('private var adMuted = false'));
      expect(source, contains('releaseAdMute()'));
      expect(
        source,
        isNot(contains('if(v && !v.muted){ v.muted = true; v.volume = 0; }')),
      );
      expect(
        source,
        isNot(contains('__vshotsAdAudioSnapshot')),
        reason: 'snapshot restore was skipped whenever playback was paused',
      );
      // A volume/duck command must never re-mute or force-unmute the element.
      expect(source, isNot(contains('v.muted=false')));
      expect(source, isNot(contains('v.volume=1')));
    });

    test('publishes the shared state vocabulary and real audio truth', () {
      final String source = _read(_platformViewPath);

      expect(source, contains('BrowserPlaybackState'));
      expect(source, contains('"playing_with_audio"'));
      expect(source, contains('"playing_muted"'));
      expect(source, contains('"paused_by_user"'));
      expect(source, contains('"paused_by_audio_focus"'));
      expect(source, contains('"paused_by_lifecycle"'));
      expect(source, contains('"paused_by_browser"'));
      expect(source, contains('pauseStateForOrigin'));
      expect(source, contains('"hasAudio" to'));
    });

    test('still owns completion and the official skip assist', () {
      final String source = _read(_platformViewPath);

      // Seamless auto-advance: the validated near-end point reports completion
      // once per load, and the Flutter manager decides what happens next.
      expect(source, contains('reportVideoEnded'));
      expect(source, contains('"videoEnded"'));
      expect(source, contains('nearEndOf'));
      expect(source, contains("'ratechange','timeupdate'"));
      // Ad assist uses YouTube's OWN skip control and is gated by the flag.
      expect(source, contains('clickOfficialSkip'));
      expect(source, contains('__vshotsAdAssistEnabled'));
    });

    test('survives a dead WebView renderer without crashing the app', () {
      final String source = _read(_platformViewPath);

      expect(source, contains('override fun onRenderProcessGone'));
      expect(source, contains('"renderer-gone"'));
    });

    test('still renders only the official video-only embed', () {
      final String source = _read(_platformViewPath);

      expect(source, contains('youtubePlayerSurfaceUrl'));
      expect(source, contains('https://www.youtube.com/embed/\$id'));
      expect(source, contains('controls=0'));
      expect(source, contains('rel=0'));
      expect(source, contains('disablekb=1'));
      expect(source, contains('loadUrl(playbackUrl, additionalHeaders)'));
      expect(source, contains('"Referer"'));
      expect(source, contains('appContext.packageName'));
      expect(source, contains('Error 153'));
      expect(source, isNot(contains('loadUrl(url)')));
    });
  });

  group('native playback service', () {
    test('treats audio focus as a reason, not as a command', () {
      final String source = _read(_servicePath);
      final String code = _code(_servicePath);

      expect(source, contains('fun emitAudioFocus'));
      expect(code, contains('emitAudioFocus("loss")'));
      expect(code, contains('emitAudioFocus("loss_transient")'));
      expect(code, contains('emitAudioFocus("gain")'));
      expect(code, contains('emitAudioFocus("duck_on")'));
      // Headset / Bluetooth route loss must stop playback instead of blasting
      // the phone speaker.
      expect(code, contains('emitAudioFocus("becoming_noisy")'));
      expect(code, contains('ACTION_AUDIO_BECOMING_NOISY'));

      // The old local focus ledger fought the Dart state machine, and the
      // service is not allowed to issue transport commands from focus
      // callbacks.
      expect(code, isNot(contains('pausedByFocusLoss')));
      expect(code, isNot(contains('dispatch("focusPlay")')));
      expect(code, isNot(contains('dispatch("focusPause")')));
    });

    test('never re-requests focus while it is already held', () {
      final String source = _read(_servicePath);

      expect(
        source,
        contains('if (focusHeld) return'),
        reason: 'a repeat AUDIOFOCUS_GAIN request caused spurious pauses',
      );
    });

    test('never advertises muted playback as STATE_PLAYING', () {
      final String source = _read(_servicePath);

      expect(source,
          contains('"playing_with_audio" -> PlaybackState.STATE_PLAYING'));
      expect(source, contains('"playing_muted" -> PlaybackState.STATE_PAUSED'));
      expect(source, contains('wireIsPlaying'));
    });
  });

  group('dart session', () {
    test('owns one state machine with distinguishable pause reasons', () {
      final String source = _read(_sessionPath);

      expect(source, contains('VShotsPauseReason.user'));
      expect(source, contains('VShotsPauseReason.audioFocus'));
      expect(source, contains('VShotsPauseReason.lifecycle'));
      expect(source, contains('VShotsPauseReason.browser'));
      expect(source, contains('handleAudioFocus'));
      expect(source, contains('setBackgrounded'));
      expect(source, contains('_maxDivergenceCorrectionsPerLoad'));
      expect(source, contains('_tryCorrection'));
      // No duplicated audio-only side channel.
      expect(source, isNot(contains('onAudioState')));
    });

    test('the shared vocabulary has no second copy', () {
      final String state = _read(_statePath);
      expect(state, contains('enum VShotsPlaybackState'));
      expect(state, contains('playingMuted'));
      expect(state, contains('playingWithAudio'));
      expect(state, contains('pausedByUser'));
      expect(state, contains('pausedByAudioFocus'));
      expect(state, contains('pausedByLifecycle'));
      expect(state, contains('pausedByBrowser'));
      expect(
        state,
        isNot(contains('enum VShotsAudioState')),
        reason: 'two parallel state enums is what allowed the contradictions',
      );
    });
  });

  group('player chrome', () {
    test('keeps the premium surface and the explicit sound action', () {
      final String source = _read(_sheetPath);

      expect(source, contains('AspectRatio('));
      expect(source, contains('_videoAspectRatio = 16 / 9'));
      expect(source, contains('YouTube controls are disabled'));
      expect(
        source,
        contains("label: Text(busy ? 'Enabling…' : 'Enable Sound')"),
      );
      expect(source, contains("'Enable Sound'"));
      // The explicit path is a real Flutter button, not a synthetic gesture.
      expect(source, contains('Future<void> _enableAudio()'));
      expect(source, isNot(contains('performTrustedUnmuteTap')));
    });

    test('routes drags over the native surface but never taps', () {
      final String source = _read(_sheetPath);

      expect(source, contains('onVerticalDragStart: _onDragStart'));
      expect(source, contains('onVerticalDragUpdate: _onDragUpdate'));
      expect(source, contains('onVerticalDragEnd: _onDragEnd'));
      expect(source, contains('behavior: HitTestBehavior.deferToChild'));
      // The video viewport must not install a tap recognizer: a tap there must
      // never reach a playback toggle.
      expect(
        source,
        isNot(contains('onTap: _enableAudio')),
        reason: 'the sound action is an explicit button, not a video tap',
      );
    });
  });
}
