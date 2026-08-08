// ════════════════════════════════════════════════
// Project Lyra — Audio Handler
// ════════════════════════════════════════════════
//
// Media3-ready audio handler abstraction.
// Manages playback state, queue, and audio focus.
// ════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Audio handler interface for music playback.
///
/// This is an abstraction that can be backed by:
/// - just_audio (current)
/// - Media3 via platform channels (future)
///
/// Features depend on this, not on the underlying player.
abstract class AudioHandler {
  /// Current playback state stream.
  Stream<PlaybackState> get playbackState;

  /// Current track stream.
  Stream<TrackInfo?> get currentTrack;

  /// Queue stream.
  Stream<List<TrackInfo>> get queue;

  /// Play the current track or resume.
  Future<void> play();

  /// Pause playback.
  Future<void> pause();

  /// Stop playback and release resources.
  Future<void> stop();

  /// Skip to next track.
  Future<void> skipToNext();

  /// Skip to previous track.
  Future<void> skipToPrevious();

  /// Seek to a position.
  Future<void> seek(Duration position);

  /// Set repeat mode.
  Future<void> setRepeatMode(RepeatMode mode);

  /// Toggle shuffle.
  Future<void> setShuffleMode(bool enabled);

  /// Load a queue and start playing from index.
  Future<void> loadQueue(List<TrackInfo> tracks, {int startIndex = 0});

  /// Add track to queue.
  Future<void> addToQueue(TrackInfo track);

  /// Remove track from queue at index.
  Future<void> removeFromQueue(int index);

  /// Set playback speed (for audiobooks/podcasts).
  Future<void> setSpeed(double speed);

  /// Set audio quality / bitrate.
  Future<void> setQuality(AudioQuality quality);
}

/// Playback state.
enum PlayerState {
  idle,
  loading,
  buffering,
  playing,
  paused,
  stopped,
  error,
}

/// Repeat modes.
enum RepeatMode {
  off,
  one,
  all,
}

/// Audio quality levels.
enum AudioQuality {
  low,       // 96 kbps
  normal,    // 128 kbps
  high,      // 256 kbps
  lossless,  // 320 kbps
}

/// Immutable playback state.
class PlaybackState {
  const PlaybackState({
    required this.playerState,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.speed = 1.0,
    this.repeatMode = RepeatMode.off,
    this.shuffleEnabled = false,
  });

  final PlayerState playerState;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final double speed;
  final RepeatMode repeatMode;
  final bool shuffleEnabled;

  bool get isPlaying => playerState == PlayerState.playing;
  bool get isPaused => playerState == PlayerState.paused;
  bool get isBuffering => playerState == PlayerState.buffering;
  bool get isLoading => playerState == PlayerState.loading;

  double get progress =>
      duration.inMilliseconds > 0
          ? position.inMilliseconds / duration.inMilliseconds
          : 0.0;
}

/// Track metadata for the audio handler.
class TrackInfo {
  const TrackInfo({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.artUrl,
    this.streamUrl,
    this.duration,
    this.isOffline = false,
  });

  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? artUrl;
  final String? streamUrl;
  final Duration? duration;
  final bool isOffline;
}
