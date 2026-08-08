// ════════════════════════════════════════════════
// Project Lyra — Playlist Use Cases
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/playlist_entities.dart';
import '../repositories/playlist_repository.dart';

class GetPlaylist implements UseCase<Playlist, String> {
  const GetPlaylist(this.repository);
  final PlaylistRepository repository;
  @override
  Future<Either<Failure, Playlist>> call(String id) => repository.getPlaylist(id);
}

class GetUserPlaylists implements UseCase<List<Playlist>, PageParams> {
  const GetUserPlaylists(this.repository);
  final PlaylistRepository repository;
  @override
  Future<Either<Failure, List<Playlist>>> call(PageParams params) =>
      repository.getUserPlaylists(page: params.page, limit: params.limit);
}

class CreatePlaylist implements UseCase<Playlist, CreatePlaylistParams> {
  const CreatePlaylist(this.repository);
  final PlaylistRepository repository;
  @override
  Future<Either<Failure, Playlist>> call(CreatePlaylistParams params) =>
      repository.createPlaylist(title: params.title, description: params.description, isPublic: params.isPublic);
}

class CreatePlaylistParams extends Equatable {
  const CreatePlaylistParams({required this.title, this.description, this.isPublic = true});
  final String title;
  final String? description;
  final bool isPublic;
  @override
  List<Object?> get props => [title, description, isPublic];
}

class DeletePlaylist implements UseCaseVoid<String> {
  const DeletePlaylist(this.repository);
  final PlaylistRepository repository;
  @override
  Future<Either<Failure, void>> call(String id) => repository.deletePlaylist(id);
}

class AddTrackToPlaylist implements UseCaseVoid<TrackPlaylistParams> {
  const AddTrackToPlaylist(this.repository);
  final PlaylistRepository repository;
  @override
  Future<Either<Failure, void>> call(TrackPlaylistParams params) =>
      repository.addTrack(params.playlistId, params.trackId);
}

class RemoveTrackFromPlaylist implements UseCaseVoid<TrackPlaylistParams> {
  const RemoveTrackFromPlaylist(this.repository);
  final PlaylistRepository repository;
  @override
  Future<Either<Failure, void>> call(TrackPlaylistParams params) =>
      repository.removeTrack(params.playlistId, params.trackId);
}

class TrackPlaylistParams extends Equatable {
  const TrackPlaylistParams({required this.playlistId, required this.trackId});
  final String playlistId;
  final String trackId;
  @override
  List<Object?> get props => [playlistId, trackId];
}
