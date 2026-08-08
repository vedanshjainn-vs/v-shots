// ════════════════════════════════════════════════
// Project Lyra — Library Repository Implementation
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/mapper/failure_mapper.dart';
import '../../../../core/events/bus/app_event_bus.dart';
import '../../../../core/events/types/app_event.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/library_entities.dart';
import '../../domain/repositories/library_repository.dart';
import '../datasources/local/library_local_datasource.dart';
import '../datasources/remote/library_remote_datasource.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  LibraryRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.eventBus,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final LibraryRemoteDataSource remoteDataSource;
  final LibraryLocalDataSource localDataSource;
  final AppEventBus eventBus;
  final AppLogger _logger;

  @override
  Future<Either<Failure, Library>> getLibrary({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        final cached = await localDataSource.getCachedLibrary();
        if (cached != null) {
          _logger.d('LibraryRepo: Cache hit');
          return Right(cached.toEntity());
        }
      }

      final library = await remoteDataSource.getLibrary();
      await localDataSource.cacheLibrary(library);
      return Right(library.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> likeSong(String trackId) async {
    try {
      // Optimistic update.
      await localDataSource.addLikedTrack(trackId);
      eventBus.emit(TrackLikedEvent(trackId: trackId));

      // Sync to server.
      await remoteDataSource.likeSong(trackId);
      return const Right(null);
    } catch (e, st) {
      // Rollback on failure.
      await localDataSource.removeLikedTrack(trackId);
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> unlikeSong(String trackId) async {
    try {
      await localDataSource.removeLikedTrack(trackId);
      eventBus.emit(TrackUnlikedEvent(trackId: trackId));

      await remoteDataSource.unlikeSong(trackId);
      return const Right(null);
    } catch (e, st) {
      await localDataSource.addLikedTrack(trackId);
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> saveAlbum(String albumId) async {
    try {
      await remoteDataSource.saveAlbum(albumId);
      eventBus.emit(ContentSavedEvent(contentId: albumId, contentType: 'album'));
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> removeAlbum(String albumId) async {
    try {
      await remoteDataSource.removeAlbum(albumId);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> followArtist(String artistId) async {
    try {
      await remoteDataSource.followArtist(artistId);
      eventBus.emit(ContentSavedEvent(contentId: artistId, contentType: 'artist'));
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> unfollowArtist(String artistId) async {
    try {
      await remoteDataSource.unfollowArtist(artistId);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> savePlaylist(String playlistId) async {
    try {
      await remoteDataSource.savePlaylist(playlistId);
      eventBus.emit(ContentSavedEvent(contentId: playlistId, contentType: 'playlist'));
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> removePlaylist(String playlistId) async {
    try {
      await remoteDataSource.removePlaylist(playlistId);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<SavedTrack>>> getLikedSongs({int page = 1, int limit = 50}) async {
    try {
      final models = await remoteDataSource.getLikedSongs(page: page, limit: limit);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<SavedAlbum>>> getSavedAlbums({int page = 1, int limit = 20}) async {
    try {
      final models = await remoteDataSource.getSavedAlbums(page: page, limit: limit);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<SavedArtist>>> getFollowedArtists({int page = 1, int limit = 20}) async {
    try {
      final models = await remoteDataSource.getFollowedArtists(page: page, limit: limit);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<RecentlyPlayed>>> getRecentlyPlayed({int limit = 50}) async {
    try {
      final models = await remoteDataSource.getRecentlyPlayed(limit: limit);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> syncLibrary() async {
    try {
      _logger.d('LibraryRepo: Syncing library');
      final library = await remoteDataSource.getLibrary();
      await localDataSource.cacheLibrary(library);
      await localDataSource.setLikedTrackIds(
        library.likedSongs.map((t) => t.id).toSet(),
      );
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> addToRecentlyPlayed(RecentlyPlayed item) async {
    try {
      await remoteDataSource.addToRecentlyPlayed(RecentlyPlayedModel(
        id: item.id,
        title: item.title,
        subtitle: item.subtitle,
        imageUrl: item.imageUrl,
        contentType: item.contentType,
        playedAt: item.playedAt?.toIso8601String(),
      ));
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<bool> isLiked(String trackId) async {
    return localDataSource.getLikedTrackIds().then((ids) => ids.contains(trackId));
  }

  @override
  Future<bool> isAlbumSaved(String albumId) async {
    return localDataSource.getSavedAlbumIds().then((ids) => ids.contains(albumId));
  }

  @override
  Future<bool> isArtistFollowed(String artistId) async {
    return localDataSource.getFollowedArtistIds().then((ids) => ids.contains(artistId));
  }

  @override
  Stream<Library> get libraryStream => const Stream.empty();
}
