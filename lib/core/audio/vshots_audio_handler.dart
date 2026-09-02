// ════════════════════════════════════════════════
// V Shots — Background Playback (audio_service AudioHandler)
// ════════════════════════════════════════════════
//
// WHY THIS FILE EXISTS (read before touching main.dart's playback code):
//
// The app's actual playback code (in lib/main.dart) never used the
// PlayerController class in lib/core/audio/player_controller.dart — that
// file is orphaned/unused. main.dart instead plays audio through a raw
// global `final AudioPlayer audioPlayer = AudioPlayer();` with NO
// audio_service wrapping at all. This means, before this file existed:
//   - No lock-screen media controls
//   - No notification with play/pause/skip
//   - No guaranteed playback survival when the screen turns off or the
//     app is backgrounded (Android 8+ aggressively kills unbound
//     services with no foreground MediaSession)
//   - No headset/Bluetooth/car button support
// This was the single biggest functionality gap the user explicitly
// asked to fix.
//
// DESIGN: main.dart already has its own queue/skip/YouTube-stream-
// resolution logic (playTrack(), _next(), _prev() in PlayerScreen).
// Rather than duplicating that logic here (which would create two
// competing sources of truth for "what track plays next"), this
// handler does two things only:
//   1. Mirrors just_audio's real-time playback state onto the OS media
//      session (so the notification/lock screen always reflect the
//      truth) — this is the exact pattern shown in audio_service's own
//      official README/example (AudioPlayerHandler).
//   2. Routes OS-originated commands (a lock-screen "skip next" tap, a
//      headset button, an Android Auto press) back into main.dart's
//      existing real skip logic via the onSkipNext/onSkipPrevious
//      callbacks — main.dart wires these once, in MainShell's
//      initState, to call the same functions it already uses for
//      in-app skip buttons.
// This keeps a genuine single source of truth for "what plays next"
// (main.dart's queue), while still getting full OS-level media session
// integration — no logic is duplicated or forked.
// ════════════════════════════════════════════════

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Bridges the app's existing global `audioPlayer` (just_audio) to the
/// OS media session via audio_service. Constructed once in main() with
/// the SAME AudioPlayer instance used everywhere else in the app, so
/// both "paths" (direct in-app calls like `audioPlayer.play()` and
/// OS-triggered calls like a lock-screen tap) control the exact same
/// playback state — there is only ever one AudioPlayer in the app.
class VShotsAudioHandler extends BaseAudioHandler with SeekHandler {
  VShotsAudioHandler(this._player) {
    // Broadcast every playback event (play/pause/buffering/etc.) from
    // just_audio to audio_service's playbackState stream, which is what
    // the notification/lock screen/Android Auto all listen to.
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // When a track finishes, let main.dart's existing "track completed"
    // logic decide what happens next (repeat/next/stop) — the handler
    // itself does not own repeat-mode state, main.dart's PlayerScreen
    // does, matching the "single source of truth" design above.
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        onTrackCompleted?.call();
      }
    });
  }

  final AudioPlayer _player;

  /// Called by main.dart whenever a new track starts playing (from
  /// playTrack()/_play()), so the OS notification/lock screen update
  /// with the correct title/artist/artwork immediately — without this,
  /// the notification would keep showing stale metadata from whatever
  /// played previously.
  void updateNowPlaying(MediaItem item) {
    mediaItem.add(item);
    // Also update playback state to trigger notification refresh
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// A lock-screen/notification/headset "skip next" was pressed — route
  /// it back to main.dart's real skip-to-next logic (which knows the
  /// queue and how to resolve the next track's YouTube stream).
  @override
  Future<void> skipToNext() async => onSkipNext?.call();

  /// Same as above, for "skip previous".
  @override
  Future<void> skipToPrevious() async => onSkipPrevious?.call();

  /// Hooks that main.dart sets once (in MainShell.initState) so that OS
  /// media-session commands route back to the app's real, existing
  /// skip logic — see the file-level design note above for why this
  /// handler does not implement its own competing queue/skip logic.
  void Function()? onSkipNext;
  void Function()? onSkipPrevious;

  /// Called by main.dart's own processingStateStream completion
  /// handling logic (repeat-one / auto-advance / stop-at-end) — wired
  /// the same way as onSkipNext/onSkipPrevious.
  void Function()? onTrackCompleted;

  /// Converts a just_audio PlaybackEvent into an audio_service
  /// PlaybackState — this exact transform is the pattern shown in
  /// audio_service's own official example (AudioPlayerHandler in their
  /// README/example/lib/main.dart).
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
