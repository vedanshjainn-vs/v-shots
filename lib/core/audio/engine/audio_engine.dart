// ════════════════════════════════════════════════
// Project Lyra — Audio Engine
// ════════════════════════════════════════════════
//
// Production audio engine with just_audio.
// Supports background playback, queue, shuffle,
// repeat, crossfade, sleep timer, headset controls.
// ════════════════════════════════════════════════

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../logging/app_logger.dart';
import '../../media/queue/playback_queue.dart';
import '../../media/state/playback_models.dart';
import '../audio_handler.dart';

/// Production audio engine using just_audio.
///
/// Implements [AudioHandler] for the player feature.
class AudioEngine implements AudioHandler {
  AudioEngine({AppLogger? logger}) : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;
  final AudioPlayer _player = AudioPlayer();
  AudioSession? _session;

  final _stateController = StreamController<PlaybackStateModel>.broadcast();
  final _trackController = StreamController<QueueItem?>.broadcast();
  final _queueController = StreamController<List<QueueItem>>.broadcast();

  PlaybackQueue _queue = PlaybackQueue(tracks: []);
  bool _isInitialized = false;

  // ── Initialization ───────────────────────────

  /// Initialize the audio engine.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configure audio session.
      _session = await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration.music());

      // Listen for interruptions.
      _session!.interruptionEventStream.listen((event) {
        if (event.begin) {
          if (event.type == AudioInterruptionType.duck) {
            _player.setVolume(0.3);
          } else {
            pause();
          }
        } else {
          _player.setVolume(1.0);
        }
      });

      // Listen for headphone disconnect.
      _session!.becomingNoisyEventStream.listen((_) {
        pause();
      });

      // Listen to player state changes.
      _player.playerStateStream.listen((state) {
        _emitState();
      });

      _player.positionStream.listen((_) => _emitState());
      _player.durationStream.listen((_) => _emitState());

      _isInitialized = true;
      _logger.i('AudioEngine: Initialized');
    } catch (e, st) {
      _logger.e('AudioEngine: Init failed', error: e, stackTrace: st);
    }
  }

  // ── Playback Controls ────────────────────────

  @override
  Future<void> play() async {
    try {
      await _session?.setActive(true);
      await _player.play();
    } catch (e, st) {
      _logger.e('AudioEngine: play failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e, st) {
      _logger.e('AudioEngine: pause failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      await _session?.setActive(false);
    } catch (e, st) {
      _logger.e('AudioEngine: stop failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e, st) {
      _logger.e('AudioEngine: seek failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> skipToNext() async {
    _queue = _queue.next();
    await _loadCurrentTrack();
  }

  @override
  Future<void> skipToPrevious() async {
    _queue = _queue.previous();
    await _loadCurrentTrack();
  }

  // ── Queue Management ─────────────────────────

  @override
  Future<void> loadQueue(List<QueueItem> tracks, {int startIndex = 0}) async {
    try {
      _queue = PlaybackQueue(
        tracks: tracks,
        currentIndex: startIndex,
      );
      _queueController.add(tracks);
      await _loadCurrentTrack();
    } catch (e, st) {
      _logger.e('AudioEngine: loadQueue failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> addToQueue(QueueItem track) async {
    _queue = _queue.add(track);
    _queueController.add(_queue.tracks);
  }

  @override
  Future<void> removeFromQueue(int index) async {
    _queue = _queue.removeAt(index);
    _queueController.add(_queue.tracks);
  }

  // ── Playback Modes ───────────────────────────

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    _queue = _queue.setRepeatMode(mode);
    _emitState();
  }

  @override
  Future<void> setShuffleMode(bool enabled) async {
    _queue = _queue.toggleShuffle();
    _emitState();
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  @override
  Future<void> setQuality(AudioQuality quality) async {
    // Quality is set at stream URL level.
  }

  // ── Streams ──────────────────────────────────

  @override
  Stream<PlaybackStateModel> get playbackState => _stateController.stream;

  @override
  Stream<QueueItem?> get currentTrack => _trackController.stream;

  @override
  Stream<List<QueueItem>> get queue => _queueController.stream;

  // ── Private Helpers ──────────────────────────

  Future<void> _loadCurrentTrack() async {
    final track = _queue.current;
    if (track == null) return;

    _trackController.add(track);

    try {
      if (track.streamUrl != null) {
        await _player.setUrl(track.streamUrl!);
        await play();
      }
    } catch (e, st) {
      _logger.e('AudioEngine: _loadCurrentTrack failed', error: e, stackTrace: st);
    }
  }

  void _emitState() {
    _stateController.add(PlaybackStateModel(
      status: _mapPlayerState(_player.playerState),
      position: _player.position,
      duration: _player.duration ?? Duration.zero,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      repeatMode: _queue.repeatMode,
      shuffleEnabled: _queue.shuffleEnabled,
      currentTrack: _queue.current,
      currentIndex: _queue.currentIndex,
      queueLength: _queue.length,
    ));
  }

  PlayerStatus _mapPlayerState(PlayerState state) {
    if (state.playing) return PlayerStatus.playing;
    return switch (state.processingState) {
      ProcessingState.idle => PlayerStatus.idle,
      ProcessingState.loading => PlayerStatus.loading,
      ProcessingState.buffering => PlayerStatus.buffering,
      ProcessingState.ready => PlayerStatus.paused,
      ProcessingState.completed => PlayerStatus.completed,
    };
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await _player.dispose();
    await _stateController.close();
    await _trackController.close();
    await _queueController.close();
  }
}
