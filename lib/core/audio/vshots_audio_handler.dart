// ════════════════════════════════════════════════
// V Shots — Background Playback (audio_service AudioHandler)
// ════════════════════════════════════════════════
//
// Bridges the app's existing global just_audio player to the Android/iOS
// media session without changing the app's playback ownership or queue.
// ════════════════════════════════════════════════

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// OS media-session bridge for V Shots' existing global AudioPlayer.
/// The app remains the source of truth for queue/skip behavior.
class VShotsAudioHandler extends BaseAudioHandler with SeekHandler {
  VShotsAudioHandler(this._player) {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        onTrackCompleted?.call();
      }
    });
  }

  final AudioPlayer _player;

  /// Publishes the current track to the OS media session. Android's native
  /// MediaStyle notification uses this MediaItem for title/artist/artwork and
  /// PlaybackState for the rich media controls/progress.
  void updateNowPlaying(MediaItem item) {
    mediaItem.add(item);
    playbackState.add(_currentPlaybackState());
  }

  PlaybackState _currentPlaybackState() {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      // Android compact MediaStyle keeps the three most useful actions visible
      // while the expanded notification exposes the full five-action layout.
      androidCompactActionIndices: const [0, 2, 4],
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

  @override
  Future<void> fastForward() async {
    final target = _player.position + const Duration(seconds: 10);
    final duration = _player.duration;
    await _player.seek(duration == null || target < duration ? target : duration);
  }

  @override
  Future<void> rewind() async {
    final target = _player.position - const Duration(seconds: 10);
    await _player.seek(target.isNegative ? Duration.zero : target);
  }

  @override
  Future<void> skipToNext() async => onSkipNext?.call();

  @override
  Future<void> skipToPrevious() async => onSkipPrevious?.call();

  void Function()? onSkipNext;
  void Function()? onSkipPrevious;
  void Function()? onTrackCompleted;

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 2, 4],
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
