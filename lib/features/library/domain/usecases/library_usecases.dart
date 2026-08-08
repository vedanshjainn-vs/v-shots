// ════════════════════════════════════════════════
// Project Lyra — Library Use Cases
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/library_entities.dart';
import '../repositories/library_repository.dart';

class GetLibrary implements UseCase<Library, GetLibraryParams> {
  const GetLibrary(this.repository);
  final LibraryRepository repository;
  @override
  Future<Either<Failure, Library>> call(GetLibraryParams params) =>
      repository.getLibrary(forceRefresh: params.forceRefresh);
}

class GetLibraryParams extends Equatable {
  const GetLibraryParams({this.forceRefresh = false});
  final bool forceRefresh;
  @override
  List<Object?> get props => [forceRefresh];
}

class LikeSong implements UseCaseVoid<String> {
  const LikeSong(this.repository);
  final LibraryRepository repository;
  @override
  Future<Either<Failure, void>> call(String trackId) => repository.likeSong(trackId);
}

class UnlikeSong implements UseCaseVoid<String> {
  const UnlikeSong(this.repository);
  final LibraryRepository repository;
  @override
  Future<Either<Failure, void>> call(String trackId) => repository.unlikeSong(trackId);
}

class SaveAlbum implements UseCaseVoid<String> {
  const SaveAlbum(this.repository);
  final LibraryRepository repository;
  @override
  Future<Either<Failure, void>> call(String albumId) => repository.saveAlbum(albumId);
}

class RemoveAlbum implements UseCaseVoid<String> {
  const RemoveAlbum(this.repository);
  final LibraryRepository repository;
  @override
  Future<Either<Failure, void>> call(String albumId) => repository.removeAlbum(albumId);
}

class SyncLibrary implements UseCaseVoid<NoParams> {
  const SyncLibrary(this.repository);
  final LibraryRepository repository;
  @override
  Future<Either<Failure, void>> call(NoParams params) => repository.syncLibrary();
}

class GetLikedSongs implements UseCase<List<SavedTrack>, PageParams> {
  const GetLikedSongs(this.repository);
  final LibraryRepository repository;
  @override
  Future<Either<Failure, List<SavedTrack>>> call(PageParams params) =>
      repository.getLikedSongs(page: params.page, limit: params.limit);
}

class GetRecentlyPlayed implements UseCase<List<RecentlyPlayed>, GetRecentParams> {
  const GetRecentlyPlayed(this.repository);
  final LibraryRepository repository;
  @override
  Future<Either<Failure, List<RecentlyPlayed>>> call(GetRecentParams params) =>
      repository.getRecentlyPlayed(limit: params.limit);
}

class GetRecentParams extends Equatable {
  const GetRecentParams({this.limit = 50});
  final int limit;
  @override
  List<Object?> get props => [limit];
}
