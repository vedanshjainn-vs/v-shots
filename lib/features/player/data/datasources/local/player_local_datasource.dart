// ════════════════════════════════════════════════
// Project Lyra — Player Local Data Source
// ════════════════════════════════════════════════

import '../../../../../core/cache/cache_key.dart';
import '../../../../../core/cache/cache_manager.dart';
import '../../../../../core/cache/policies/cache_policy.dart';
import '../../../../../core/logging/app_logger.dart';
import '../../../../../core/storage/local_storage.dart';
import '../models/player_models.dart';

abstract class PlayerLocalDataSource {
  Future<TrackModel?> getCachedTrack(String trackId);
  Future<void> cacheTrack(TrackModel track);
  Future<PlaybackSessionModel?> getSavedPlaybackState();
  Future<void> savePlaybackState(PlaybackSessionModel session);
  Future<void> clearPlaybackState();
  Future<List<TrackModel>> getCachedQueue();
  Future<void> cacheQueue(List<TrackModel> tracks);
}

class HivePlayerLocalDataSource implements PlayerLocalDataSource {
  HivePlayerLocalDataSource({
    required this.cacheManager,
    required this.localStorage,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final CacheManager cacheManager;
  final LocalStorage localStorage;
  final AppLogger _logger;

  static const String _playbackStateKey = 'playback_state';
  static const String _queueKey = 'playback_queue';

  @override
  Future<TrackModel?> getCachedTrack(String trackId) async {
    try {
      final key = CacheKey(namespace: 'tracks', id: trackId);
      final raw = cacheManager.getRaw(key);
      if (raw == null) return null;
      // TODO(team): Deserialize from raw.
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> cacheTrack(TrackModel track) async {
    try {
      final key = CacheKey(namespace: 'tracks', id: track.id);
      await cacheManager.put<TrackModel>(
        key: key,
        data: track,
        toJson: (data) => data.toJson(),
        ttl: CachePolicy.static.maxAge,
      );
    } catch (e) {
      _logger.w('PlayerLocal: cacheTrack failed');
    }
  }

  @override
  Future<PlaybackSessionModel?> getSavedPlaybackState() async {
    try {
      return await localStorage.getObject<PlaybackSessionModel>(
        _playbackStateKey,
        PlaybackSessionModel.fromJson,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> savePlaybackState(PlaybackSessionModel session) async {
    try {
      await localStorage.setObject<PlaybackSessionModel>(
        _playbackStateKey,
        session,
        (s) => s.toJson(),
      );
    } catch (e) {
      _logger.w('PlayerLocal: savePlaybackState failed');
    }
  }

  @override
  Future<void> clearPlaybackState() async {
    await localStorage.remove(_playbackStateKey);
  }

  @override
  Future<List<TrackModel>> getCachedQueue() async {
    try {
      final raw = await localStorage.getString(_queueKey);
      if (raw == null) return [];
      // TODO(team): Deserialize queue from JSON.
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> cacheQueue(List<TrackModel> tracks) async {
    try {
      // TODO(team): Serialize queue to JSON.
      await localStorage.setString(_queueKey, tracks.length.toString());
    } catch (e) {
      _logger.w('PlayerLocal: cacheQueue failed');
    }
  }
}

@freezed
class PlaybackSessionModel with _$PlaybackSessionModel {
  const factory PlaybackSessionModel({
    required String id,
    String? currentTrackId,
    @Default(0) int currentIndex,
    @Default([]) List<String> queueIds,
    @Default(0) int positionMs,
    @Default(0) int durationMs,
    @Default(false) bool isPlaying,
    @Default(false) bool shuffleEnabled,
    @Default('off') String repeatMode,
    @Default(1.0) double speed,
    String? startedAt,
  }) = _PlaybackSessionModel;

  factory PlaybackSessionModel.fromJson(Map<String, dynamic> json) => _$PlaybackSessionModelFromJson(json);
}
