// ═════════════════════════════════════════════════════════════════════════════
// V Shots — authoritative playback state machine tests
//
// These tests exist to make the invariants the user asked for directly
// assertable, so a future change cannot quietly re-conflate:
//
//   • user pause          vs  audio-focus pause
//   • audio-focus pause   vs  app background
//   • buffering           vs  playing
//   • muted playback      vs  audible playback
//   • a stale generation  vs  the current track
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/features/foryou/vshots_browser_session.dart';
import 'package:v_shots/features/foryou/vshots_playback_state.dart';

VShotsBrowserSession _session({
  void Function()? onFinished,
  void Function(String message)? onError,
}) =>
    VShotsBrowserSession(
      onPageStarted: () {},
      onPageFinished: onFinished ?? () {},
      onError: onError ?? (_) {},
    );

const String _trackUrl = 'https://www.youtube.com/watch?v=testTrack01';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('wire vocabulary', () {
    test('every state has a stable wire name and maps back 1:1', () {
      for (final VShotsPlaybackState state in VShotsPlaybackState.values) {
        expect(
          playbackStateFromNative(state.wireName),
          state,
          reason: '${state.name} must round-trip through the wire vocabulary',
        );
      }
    });

    test('an unknown wire value is never guessed into playback', () {
      expect(
        playbackStateFromNative('something-new'),
        VShotsPlaybackState.idle,
      );
      expect(playbackStateFromNative(null), VShotsPlaybackState.idle);
    });

    test('muted playback is not audible and buffering is not playback', () {
      expect(VShotsPlaybackState.playingMuted.isTransportRunning, isTrue);
      expect(VShotsPlaybackState.playingMuted.hasAudio, isFalse);
      expect(VShotsPlaybackState.playingWithAudio.hasAudio, isTrue);
      expect(VShotsPlaybackState.buffering.isBusy, isTrue);
      expect(VShotsPlaybackState.buffering.isTransportRunning, isFalse);
    });

    test('only a user pause is excluded from automatic recovery', () {
      expect(VShotsPlaybackState.pausedByUser.isInterruptionPause, isFalse);
      expect(
          VShotsPlaybackState.pausedByAudioFocus.isInterruptionPause, isTrue);
      expect(VShotsPlaybackState.pausedByLifecycle.isInterruptionPause, isTrue);
      expect(VShotsPlaybackState.pausedByBrowser.isInterruptionPause, isTrue);
    });
  });

  group('user pause is final', () {
    test('a browser pause after a user pause stays pausedByUser', () async {
      final VShotsBrowserSession session = _session();
      await session.load(_trackUrl);
      session.applyObservedTransport(wireState: 'playing_with_audio');

      await session.pause();
      expect(session.playbackState, VShotsPlaybackState.pausedByUser);
      expect(session.intent, VShotsPlaybackIntent.pause);

      // The browser confirms a pause. It must NOT be re-attributed.
      session.applyObservedTransport(wireState: 'paused');
      expect(session.playbackState, VShotsPlaybackState.pausedByUser);

      session.dispose();
    });

    test('an audio-focus gain never resumes a user pause', () async {
      final VShotsBrowserSession session = _session();
      await session.load(_trackUrl);
      session.applyObservedTransport(wireState: 'playing_with_audio');

      await session.handleAudioFocus('loss_transient');
      await session.pause();
      expect(session.playbackState, VShotsPlaybackState.pausedByUser);

      await session.handleAudioFocus('gain');
      expect(
        session.playbackState,
        VShotsPlaybackState.pausedByUser,
        reason: 'the user paused while focus was away; resume must not happen',
      );

      session.dispose();
    });
  });

  group('unexpected browser pause', () {
    test('is reported as pausedByBrowser and never as a user pause', () async {
      final VShotsBrowserSession session = _session();
      await session.load(_trackUrl);
      session.applyObservedTransport(wireState: 'playing_with_audio');

      session.applyObservedTransport(wireState: 'paused');
      expect(session.playbackState, VShotsPlaybackState.pausedByBrowser);
      expect(session.pauseReason, VShotsPauseReason.browser);
      expect(
        session.intent,
        VShotsPlaybackIntent.play,
        reason:
            'the standing intent is still PLAY, only the observation changed',
      );

      session.dispose();
    });

    test('corrections are bounded — no unbounded play/pause loop', () async {
      final VShotsBrowserSession session = _session();
      await session.load(_trackUrl);
      session.applyObservedTransport(wireState: 'playing_with_audio');

      final int budgetAtStart = session.divergenceCorrectionsLeft;
      expect(budgetAtStart, greaterThan(0));

      // Hammer the divergence path far more often than any real player would.
      for (int i = 0; i < 50; i++) {
        session.applyObservedTransport(wireState: 'paused');
      }

      expect(
        session.divergenceCorrectionsLeft,
        greaterThanOrEqualTo(0),
        reason: 'the correction budget must never go negative',
      );
      expect(
        session.divergenceCorrectionsLeft,
        lessThanOrEqualTo(budgetAtStart),
        reason:
            'corrections may only be consumed, never replenished by polling',
      );

      session.dispose();
    });
  });

  group('audio focus', () {
    test('transient loss pauses and the matching gain resumes exactly once',
        () async {
      final VShotsBrowserSession session = _session();
      await session.load(_trackUrl);
      session.applyObservedTransport(wireState: 'playing_with_audio');

      await session.handleAudioFocus('loss_transient');
      expect(session.playbackState, VShotsPlaybackState.pausedByAudioFocus);
      expect(session.pauseReason, VShotsPauseReason.audioFocus);

      await session.handleAudioFocus('gain');
      expect(session.playbackState, VShotsPlaybackState.buffering);
      expect(session.intent, VShotsPlaybackIntent.play);

      // A second gain (no new loss) must not produce another resume.
      await session.handleAudioFocus('gain');
      expect(session.playbackState, VShotsPlaybackState.buffering);

      session.dispose();
    });

    test('permanent loss pauses and never auto-resumes', () async {
      final VShotsBrowserSession session = _session();
      await session.load(_trackUrl);
      session.applyObservedTransport(wireState: 'playing_with_audio');

      await session.handleAudioFocus('loss');
      expect(session.playbackState, VShotsPlaybackState.pausedByAudioFocus);
      expect(session.intent, VShotsPlaybackIntent.pause);

      await session.handleAudioFocus('gain');
      expect(session.playbackState, VShotsPlaybackState.pausedByAudioFocus);

      session.dispose();
    });

    test('ducking is volume-only and never changes the state', () async {
      final VShotsBrowserSession session = _session();
      await session.load(_trackUrl);
      session.applyObservedTransport(wireState: 'playing_with_audio');

      await session.handleAudioFocus('duck_on');
      expect(session.playbackState, VShotsPlaybackState.playingWithAudio);
      await session.handleAudioFocus('duck_off');
      expect(session.playbackState, VShotsPlaybackState.playingWithAudio);

      session.dispose();
    });
  });

  group('lifecycle', () {
    test(
        'backgrounding alone never pauses and a platform pause is '
        'classified as pausedByLifecycle', () async {
      final VShotsBrowserSession session = _session();
      await session.load(_trackUrl);
      session.applyObservedTransport(wireState: 'playing_with_audio');

      session.setBackgrounded(true);
      expect(
        session.playbackState,
        VShotsPlaybackState.playingWithAudio,
        reason: 'background playback is a product feature',
      );

      session.applyObservedTransport(wireState: 'paused');
      expect(session.playbackState, VShotsPlaybackState.pausedByLifecycle);
      expect(session.pauseReason, VShotsPauseReason.lifecycle);

      session.dispose();
    });

    test(
        'returning to the foreground recovers a lifecycle pause only while '
        'the intent is still PLAY', () async {
      final VShotsBrowserSession session = _session();
      await session.load(_trackUrl);
      session.applyObservedTransport(wireState: 'playing_with_audio');
      session.setBackgrounded(true);
      session.applyObservedTransport(wireState: 'paused');
      session.setBackgrounded(false);
      expect(session.intent, VShotsPlaybackIntent.play);

      // Now the same situation, but the user paused meanwhile.
      final VShotsBrowserSession other = _session();
      await other.load(_trackUrl);
      other.applyObservedTransport(wireState: 'playing_with_audio');
      other.setBackgrounded(true);
      other.applyObservedTransport(wireState: 'paused');
      await other.pause();
      other.setBackgrounded(false);
      expect(other.playbackState, VShotsPlaybackState.pausedByUser);

      session.dispose();
      other.dispose();
    });
  });

  group('muted vs audible', () {
    test(
        'a muted transport reports playingMuted, an audible one '
        'playingWithAudio', () async {
      final VShotsBrowserSession session = _session();
      await session.load(_trackUrl);

      session.applyObservedTransport(
        wireState: 'playing_muted',
        hasAudio: false,
      );
      expect(session.playbackState, VShotsPlaybackState.playingMuted);
      expect(session.playbackState.hasAudio, isFalse);
      expect(session.pagePlaying, isTrue);

      session.applyObservedTransport(
        wireState: 'playing_with_audio',
        hasAudio: true,
      );
      expect(session.playbackState, VShotsPlaybackState.playingWithAudio);
      expect(session.playbackState.hasAudio, isTrue);

      session.dispose();
    });

    test('an explicit Play asks for playback but never claims it', () async {
      final VShotsBrowserSession session = _session();
      await session.load(_trackUrl);
      session.applyObservedTransport(
          wireState: 'playing_muted', hasAudio: false);

      await session.play();
      expect(
        session.playbackState,
        VShotsPlaybackState.buffering,
        reason: 'nothing has been observed yet, so PLAYING would be a lie',
      );

      session.dispose();
    });
  });

  group('stale generation callbacks', () {
    test('events from an older load are ignored', () async {
      final VShotsBrowserSession session = _session();
      await session.load(_trackUrl);
      final int oldGeneration = session.generation;
      await session.load('https://www.youtube.com/watch?v=testTrack02');
      final int currentGeneration = session.generation;

      await session.debugHandleNativeEvent(
        MethodCall('playbackState', <String, Object?>{
          'state': 'playing_with_audio',
          'hasAudio': true,
          'generation': oldGeneration,
        }),
      );
      expect(
        session.playbackState,
        VShotsPlaybackState.loading,
        reason: 'a stale generation must not mutate the new track',
      );

      await session.debugHandleNativeEvent(
        MethodCall('playbackState', <String, Object?>{
          'state': 'playing_with_audio',
          'hasAudio': true,
          'generation': currentGeneration,
        }),
      );
      expect(session.playbackState, VShotsPlaybackState.playingWithAudio);

      session.dispose();
    });
  });

  group('renderer recovery is bounded', () {
    test('the platform view is remounted at most once per load', () async {
      final VShotsBrowserSession session = _session();
      await session.load(_trackUrl);
      final int epoch = session.viewEpoch;

      await session.debugHandleNativeEvent(
        MethodCall('error', <String, Object?>{
          'message': 'Playback was interrupted — please retry',
          'reason': 'renderer-gone',
          'generation': session.generation,
        }),
      );
      expect(session.viewEpoch, epoch + 1);
      expect(session.playbackState, VShotsPlaybackState.error);

      await session.debugHandleNativeEvent(
        MethodCall('error', <String, Object?>{
          'message': 'Playback was interrupted — please retry',
          'reason': 'renderer-gone',
          'generation': session.generation,
        }),
      );
      expect(
        session.viewEpoch,
        epoch + 1,
        reason: 'a second crash must not start a recreate loop',
      );

      session.dispose();
    });
  });
}
