// ════════════════════════════════════════════════
// Project Lyra — Player Use Cases
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/player_entities.dart';
import '../repositories/player_repository.dart';

class GetTrack implements UseCase<Track, String> {
  const GetTrack(this.repository);
  final PlayerRepository repository;
  @override
  Future<Either<Failure, Track>> call(String trackId) => repository.getTrack(trackId);
}

class GetStreamUrl implements UseCase<String, String> {
  const GetStreamUrl(this.repository);
  final PlayerRepository repository;
  @override
  Future<Either<Failure, String>> call(String trackId) => repository.getStreamUrl(trackId);
}

class GetLyrics implements UseCase<Lyrics, String> {
  const GetLyrics(this.repository);
  final PlayerRepository repository;
  @override
  Future<Either<Failure, Lyrics>> call(String trackId) => repository.getLyrics(trackId);
}

class LoadQueue implements UseCase<List<Track>, NoParams> {
  const LoadQueue(this.repository);
  final PlayerRepository repository;
  @override
  Future<Either<Failure, List<Track>>> call(NoParams params) => repository.getQueue();
}

class SavePlaybackState implements UseCaseVoid<PlaybackSession> {
  const SavePlaybackState(this.repository);
  final PlayerRepository repository;
  @override
  Future<Either<Failure, void>> call(PlaybackSession session) =>
      repository.savePlaybackState(session);
}

class RestorePlaybackState implements UseCase<PlaybackSession?, NoParams> {
  const RestorePlaybackState(this.repository);
  final PlayerRepository repository;
  @override
  Future<Either<Failure, PlaybackSession?>> call(NoParams params) =>
      repository.restorePlaybackState();
}

class RecordPlay implements UseCaseVoid<String> {
  const RecordPlay(this.repository);
  final PlayerRepository repository;
  @override
  Future<Either<Failure, void>> call(String trackId) => repository.recordPlay(trackId);
}
