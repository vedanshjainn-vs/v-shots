// ════════════════════════════════════════════════
// V Shots — Player Controller
// ════════════════════════════════════════════════
//
// Single source of truth for playback.
// Handles stream resolution, playback state,
// queue management, and error recovery.
// ════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Player state enum.
enum PlayerStatus {
  idle,
  loading,
  ready,
  playing,
  paused,
  buffering,
  completed,
  error,
}

/// Represents a track in the queue.
class TrackItem {
  final String id;
  final String title;
  final String artist;
  final String? artwork;
  final int? durationSeconds;

  const TrackItem({
    required this.id,
    required this.title,
    required this.artist,
    this.artwork,
    this.durationSeconds,
  });
}

/// Playback state that UI subscribes to.
class PlayerState {
  final PlayerStatus status;
  final TrackItem? currentTrack;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final bool isPlaying;
  final bool isShuffle;
  final RepeatMode repeatMode;
  final double volume;
  final String? error;
  final List<TrackItem> queue;
  final int currentIndex;

  const PlayerState({
    this.status = PlayerStatus.idle,
    this.currentTrack,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.isPlaying = false,
    this.isShuffle = false,
    this.repeatMode = RepeatMode.off,
    this.volume = 1.0,
    this.error,
    this.queue = const [],
    this.currentIndex = 0,
  });

  PlayerState copyWith({
    PlayerStatus? status,
    TrackItem? currentTrack,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    bool? isPlaying,
    bool? isShuffle,
    RepeatMode? repeatMode,
    double? volume,
    String? error,
    List<TrackItem>? queue,
    int? currentIndex,
  }) {
    return PlayerState(
      status: status ?? this.status,
      currentTrack: currentTrack ?? this.currentTrack,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      isPlaying: isPlaying ?? this.isPlaying,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      volume: volume ?? this.volume,
      error: error,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

enum RepeatMode { off, one, all }

/// Single source of truth for all playback.
class PlayerController {
  PlayerController();
  
  final AudioPlayer _player = AudioPlayer();
  final YoutubeExplode _yt = YoutubeExplode();
  
  PlayerState _state = const PlayerState();
  final _stateController = StreamController<PlayerState>.broadcast();
  
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferedSub;
  StreamSubscription? _playerStateSub;

  /// Stream of player state changes.
  Stream<PlayerState> get stateStream => _stateController.stream;
  
  /// Current state.
  PlayerState get state => _state;

  /// Initialize the player controller.
  Future<void> initialize() async {
    _positionSub = _player.positionStream.listen((pos) {
      _updateState(position: pos);
    });

    _durationSub = _player.durationStream.listen((dur) {
      _updateState(duration: dur ?? Duration.zero);
    });

    _bufferedSub = _player.bufferedPositionStream.listen((buf) {
      _updateState(bufferedPosition: buf);
    });

    _playerStateSub = _player.playerStateStream.listen((ps) {
      PlayerStatus status;
      if (ps.processingState == ProcessingState.idle) {
        status = PlayerStatus.idle;
      } else if (ps.processingState == ProcessingState.loading ||
                 ps.processingState == ProcessingState.buffering) {
        status = ps.processingState == ProcessingState.buffering
            ? PlayerStatus.buffering
            : PlayerStatus.loading;
      } else if (ps.processingState == ProcessingState.completed) {
        status = PlayerStatus.completed;
        _onTrackCompleted();
      } else {
        status = ps.playing ? PlayerStatus.playing : PlayerStatus.paused;
      }
      _updateState(status: status, isPlaying: ps.playing);
    });


    _logger('PlayerController initialized');
  }

  /// Play a single track.
  Future<void> playTrack(TrackItem track) async {
    _logger('▶ playTrack: ${track.title} (${track.id})');
    
    _updateState(
      status: PlayerStatus.loading,
      currentTrack: track,
      error: null,
    );

    try {
      // Step 1: Resolve stream URL.
      final streamUrl = await _resolveStream(track.id);
      if (streamUrl == null) {
        _updateState(status: PlayerStatus.error, error: 'Could not resolve stream');
        return;
      }
      _logger('✓ Stream URL resolved: ${streamUrl.substring(0, 50)}...');

      // Step 2: Set URL and wait for ready.
      await _player.setUrl(streamUrl);
      _logger('✓ URL set on player');

      // Step 3: Play.
      await _player.play();
      _logger('✓ Player.play() called');

    } catch (e, st) {
      _logger('✗ playTrack error: $e\n$st');
      _updateState(status: PlayerStatus.error, error: e.toString());
    }
  }

  /// Play a queue starting from index.
  Future<void> playQueue(List<TrackItem> tracks, {int startIndex = 0}) async {
    _logger('▶ playQueue: ${tracks.length} tracks, starting at $startIndex');
    
    _updateState(
      queue: tracks,
      currentIndex: startIndex,
    );

    await playTrack(tracks[startIndex]);
  }

  /// Pause playback.
  Future<void> pause() async {
    _logger('⏸ pause');
    await _player.pause();
  }

  /// Resume playback.
  Future<void> resume() async {
    _logger('▶ resume');
    await _player.play();
  }

  /// Toggle play/pause.
  Future<void> togglePlayPause() async {
    if (_state.isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  /// Seek to position.
  Future<void> seek(Duration position) async {
    _logger('⏩ seek: $position');
    await _player.seek(position);
  }

  /// Play next track in queue.
  Future<void> next() async {
    final queue = _state.queue;
    if (queue.isEmpty) return;

    int nextIndex;
    if (_state.repeatMode == RepeatMode.one) {
      nextIndex = _state.currentIndex;
    } else if (_state.isShuffle) {
      nextIndex = (queue.length * (DateTime.now().millisecondsSinceEpoch % 1000) ~/ 1000);
    } else {
      nextIndex = _state.currentIndex + 1;
      if (nextIndex >= queue.length) {
        if (_state.repeatMode == RepeatMode.all) {
          nextIndex = 0;
        } else {
          _updateState(status: PlayerStatus.completed);
          return;
        }
      }
    }

    _updateState(currentIndex: nextIndex);
    await playTrack(queue[nextIndex]);
  }

  /// Play previous track in queue.
  Future<void> previous() async {
    final queue = _state.queue;
    if (queue.isEmpty) return;

    // If more than 3 seconds in, restart current track.
    if (_state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    int prevIndex = _state.currentIndex - 1;
    if (prevIndex < 0) {
      if (_state.repeatMode == RepeatMode.all) {
        prevIndex = queue.length - 1;
      } else {
        prevIndex = 0;
      }
    }

    _updateState(currentIndex: prevIndex);
    await playTrack(queue[prevIndex]);
  }

  /// Set volume (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
    _updateState(volume: volume.clamp(0.0, 1.0));
  }

  /// Toggle shuffle.
  void toggleShuffle() {
    _updateState(isShuffle: !_state.isShuffle);
  }

  /// Cycle repeat mode.
  void cycleRepeatMode() {
    final modes = RepeatMode.values;
    final nextIndex = (modes.indexOf(_state.repeatMode) + 1) % modes.length;
    _updateState(repeatMode: modes[nextIndex]);
  }

  /// Set playback speed.
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  /// Stop playback.
  Future<void> stop() async {
    _logger('⏹ stop');
    await _player.stop();
    _updateState(
      status: PlayerStatus.idle,
      isPlaying: false,
      position: Duration.zero,
    );
  }

  /// Dispose resources.
  Future<void> dispose() async {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferedSub?.cancel();
    _playerStateSub?.cancel();
    await _player.dispose();
    await _stateController.close();
    _yt.close();
  }

  // ═══════════════════════════════════════════════
  // PRIVATE: Stream Resolution
  // ═══════════════════════════════════════════════

  /// Resolve a playable stream URL from YouTube.
  ///
  /// Uses multi-client fallback: androidVr → ios → android
  /// to avoid 403 errors from any single client being blocked.
  Future<String?> _resolveStream(String videoId) async {
    _logger('Resolving stream for: $videoId');

    // Try clients in priority order.
    // androidVr and ios are most reliable for audio-only streams.
    final clientAttempts = [
      [YoutubeApiClient.androidVr],
      [YoutubeApiClient.ios],
      [YoutubeApiClient.android],
    ];

    for (final clients in clientAttempts) {
      try {
        _logger('Attempting manifest with client: $clients');
        final manifest = await _yt.videos.streamsClient
            .getManifest(videoId, ytClients: clients)
            .timeout(const Duration(seconds: 12));

        final audioStreams = manifest.audioOnly;
        if (audioStreams.isEmpty) {
          _logger('✗ No audio streams from $clients, trying next');
          continue;
        }

        // Sort by bitrate (highest first) and pick best.
        final sorted = audioStreams.toList()
          ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
        final selected = sorted.first;

        _logger(
          '✓ Selected stream via $clients: ${selected.bitrate}, '
          '${selected.codec}, ${selected.container}',
        );

        return selected.url.toString();
      } catch (e) {
        _logger('✗ Client $clients failed: $e — trying next');
        continue;
      }
    }

    _logger('✗ All client attempts failed for $videoId');
    return null;
  }

  // ═══════════════════════════════════════════════
  // PRIVATE: Helpers
  // ═══════════════════════════════════════════════

  void _updateState({
    PlayerStatus? status,
    TrackItem? currentTrack,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    bool? isPlaying,
    bool? isShuffle,
    RepeatMode? repeatMode,
    double? volume,
    String? error,
    List<TrackItem>? queue,
    int? currentIndex,
  }) {
    _state = _state.copyWith(
      status: status,
      currentTrack: currentTrack,
      position: position,
      duration: duration,
      bufferedPosition: bufferedPosition,
      isPlaying: isPlaying,
      isShuffle: isShuffle,
      repeatMode: repeatMode,
      volume: volume,
      error: error,
      queue: queue,
      currentIndex: currentIndex,
    );
    _stateController.add(_state);
  }

  void _onTrackCompleted() {
    _logger('Track completed');
    if (_state.repeatMode == RepeatMode.one) {
      seek(Duration.zero);
      resume();
    } else {
      next();
    }
  }

  void _logger(String message) {
    debugPrint('[PlayerController] $message');
  }
}

/// Global player controller instance.
final playerController = PlayerController();
