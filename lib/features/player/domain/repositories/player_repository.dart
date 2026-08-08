// ════════════════════════════════════════════════
// Project Lyra — Player Repository Interface
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/player_entities.dart';

typedef Result<T> = Either<Failure, T>;

abstract class PlayerRepository {
  Future<Result<Track>> getTrack(String trackId);
  Future<Result<Album>> getAlbum(String albumId);
  Future<Result<String>> getStreamUrl(String trackId);
  Future<Result<Lyrics>> getLyrics(String trackId);
  Future<Result<List<Track>>> getQueue();
  Future<Result<void>> savePlaybackState(PlaybackSession session);
  Future<Result<PlaybackSession?>> restorePlaybackState();
  Future<Result<void>> recordPlay(String trackId);
  Stream<PlaybackSession> get playbackStream;
}
