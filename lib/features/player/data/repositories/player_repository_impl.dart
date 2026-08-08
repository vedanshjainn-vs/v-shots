// ════════════════════════════════════════════════
// Project Lyra — Player Repository Implementation
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/mapper/failure_mapper.dart';
import '../../../../core/events/bus/app_event_bus.dart';
import '../../../../core/events/types/app_event.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/player_entities.dart';
import '../../domain/repositories/player_repository.dart';
import '../datasources/local/player_local_datasource.dart';
import '../datasources/remote/player_remote_datasource.dart';
import '../models/player_models.dart';

class PlayerRepositoryImpl implements PlayerRepository {
  PlayerRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.eventBus,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final PlayerRemoteDataSource remoteDataSource;
  final PlayerLocalDataSource localDataSource;
  final AppEventBus eventBus;
  final AppLogger _logger;

  @override
  Future<Either<Failure, Track>> getTrack(String trackId) async {
    try {
      // Check cache first.
      final cached = await localDataSource.getCachedTrack(trackId);
      if (cached != null) return Right(cached.toEntity());

      // Fetch from remote.
      final track = await remoteDataSource.getTrack(trackId);
      await localDataSource.cacheTrack(track);
      return Right(track.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, Album>> getAlbum(String albumId) async {
    try {
      final album = await remoteDataSource.getAlbum(albumId);
      return Right(album.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, String>> getStreamUrl(String trackId) async {
    try {
      final url = await remoteDataSource.getStreamUrl(trackId);
      return Right(url);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, Lyrics>> getLyrics(String trackId) async {
    try {
      final lyrics = await remoteDataSource.getLyrics(trackId);
      if (lyrics == null) return const Left(NotFoundFailure(message: 'Lyrics not found'));
      return Right(lyrics.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<Track>>> getQueue() async {
    try {
      final tracks = await localDataSource.getCachedQueue();
      return Right(tracks.map((t) => t.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> savePlaybackState(PlaybackSession session) async {
    try {
      await localDataSource.savePlaybackState(PlaybackSessionModel(
        id: session.id,
        currentTrackId: session.currentTrack?.id,
        currentIndex: session.currentIndex,
        queueIds: session.queue.map((t) => t.id).toList(),
        positionMs: session.position.inMilliseconds,
        durationMs: session.duration.inMilliseconds,
        isPlaying: session.isPlaying,
        shuffleEnabled: session.shuffleEnabled,
        repeatMode: session.repeatMode.name,
        speed: session.speed,
        startedAt: session.startedAt?.toIso8601String(),
      ));
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, PlaybackSession?>> restorePlaybackState() async {
    try {
      final session = await localDataSource.getSavedPlaybackState();
      if (session == null) return const Right(null);
      // TODO(team): Restore full session with track details.
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> recordPlay(String trackId) async {
    try {
      await remoteDataSource.recordPlay(trackId);
      eventBus.emit(TrackPlayedEvent(trackId: trackId, title: ''));
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Stream<PlaybackSession> get playbackStream => const Stream.empty();
}
