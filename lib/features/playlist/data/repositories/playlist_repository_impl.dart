// ════════════════════════════════════════════════
// Project Lyra — Playlist Repository Implementation
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import '../../../../core/cache/cache_key.dart';
import '../../../../core/cache/cache_manager.dart';
import '../../../../core/cache/policies/cache_policy.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/mapper/failure_mapper.dart';
import '../../../../core/events/bus/app_event_bus.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/playlist_entities.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../datasources/remote/playlist_remote_datasource.dart';
import '../models/playlist_models.dart';

class PlaylistRepositoryImpl implements PlaylistRepository {
  PlaylistRepositoryImpl({
    required this.remoteDataSource,
    required this.cacheManager,
    required this.eventBus,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final PlaylistRemoteDataSource remoteDataSource;
  final CacheManager cacheManager;
  final AppEventBus eventBus;
  final AppLogger _logger;

  static const String _namespace = 'playlists';

  @override
  Future<Either<Failure, Playlist>> getPlaylist(String playlistId) async {
    try {
      // Check cache first.
      final key = CacheKey(namespace: _namespace, id: playlistId);
      final cached = cacheManager.getRaw(key);
      if (cached != null) {
        _logger.d('PlaylistRepo: Cache hit for $playlistId');
        // TODO(team): Deserialize from cache.
      }

      final playlist = await remoteDataSource.getPlaylist(playlistId);

      // Cache the result.
      await cacheManager.put<PlaylistModel>(
        key: key,
        data: playlist,
        toJson: (data) => data.toJson(),
        ttl: CachePolicy.userSpecific.maxAge,
      );

      return Right(playlist.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<Playlist>>> getUserPlaylists({int page = 1, int limit = 20}) async {
    try {
      final playlists = await remoteDataSource.getUserPlaylists(page: page, limit: limit);
      return Right(playlists.map((p) => p.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, Playlist>> createPlaylist({required String title, String? description, bool isPublic = true}) async {
    try {
      final playlist = await remoteDataSource.createPlaylist(
        title: title, description: description, isPublic: isPublic,
      );
      return Right(playlist.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> deletePlaylist(String playlistId) async {
    try {
      await remoteDataSource.deletePlaylist(playlistId);
      await cacheManager.invalidate(CacheKey(namespace: _namespace, id: playlistId));
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, Playlist>> renamePlaylist(String playlistId, String newTitle) async {
    try {
      final playlist = await remoteDataSource.renamePlaylist(playlistId, newTitle);
      await cacheManager.invalidate(CacheKey(namespace: _namespace, id: playlistId));
      return Right(playlist.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, Playlist>> updateDescription(String playlistId, String? description) async {
    // TODO(team): Implement description update.
    return const Left(UnknownFailure(message: 'Not implemented'));
  }

  @override
  Future<Either<Failure, void>> addTrack(String playlistId, String trackId) async {
    try {
      await remoteDataSource.addTrack(playlistId, trackId);
      await cacheManager.invalidate(CacheKey(namespace: _namespace, id: playlistId));
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> removeTrack(String playlistId, String trackId) async {
    try {
      await remoteDataSource.removeTrack(playlistId, trackId);
      await cacheManager.invalidate(CacheKey(namespace: _namespace, id: playlistId));
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> reorderTrack(String playlistId, int oldIndex, int newIndex) async {
    try {
      await remoteDataSource.reorderTrack(playlistId, oldIndex, newIndex);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> followPlaylist(String playlistId) async {
    try {
      await remoteDataSource.followPlaylist(playlistId);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> unfollowPlaylist(String playlistId) async {
    try {
      await remoteDataSource.unfollowPlaylist(playlistId);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> sharePlaylist(String playlistId) async {
    // TODO(team): Implement sharing.
    return const Right(null);
  }

  @override
  Future<Either<Failure, Playlist>> addCollaborator(String playlistId, String userId, CollaboratorRole role) async {
    // TODO(team): Implement collaborator management.
    return const Left(UnknownFailure(message: 'Not implemented'));
  }

  @override
  Future<Either<Failure, Playlist>> removeCollaborator(String playlistId, String userId) async {
    // TODO(team): Implement collaborator management.
    return const Left(UnknownFailure(message: 'Not implemented'));
  }

  @override
  Future<bool> isFollowing(String playlistId) async {
    return remoteDataSource.isFollowing(playlistId);
  }
}
