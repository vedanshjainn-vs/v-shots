// ════════════════════════════════════════════════
// Project Lyra — Playlist Repository Interface
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/playlist_entities.dart';

typedef Result<T> = Either<Failure, T>;

abstract class PlaylistRepository {
  Future<Result<Playlist>> getPlaylist(String playlistId);
  Future<Result<List<Playlist>>> getUserPlaylists({int page = 1, int limit = 20});
  Future<Result<Playlist>> createPlaylist({required String title, String? description, bool isPublic = true});
  Future<Result<void>> deletePlaylist(String playlistId);
  Future<Result<Playlist>> renamePlaylist(String playlistId, String newTitle);
  Future<Result<Playlist>> updateDescription(String playlistId, String? description);
  Future<Result<void>> addTrack(String playlistId, String trackId);
  Future<Result<void>> removeTrack(String playlistId, String trackId);
  Future<Result<void>> reorderTrack(String playlistId, int oldIndex, int newIndex);
  Future<Result<void>> followPlaylist(String playlistId);
  Future<Result<void>> unfollowPlaylist(String playlistId);
  Future<Result<void>> sharePlaylist(String playlistId);
  Future<Result<Playlist>> addCollaborator(String playlistId, String userId, CollaboratorRole role);
  Future<Result<Playlist>> removeCollaborator(String playlistId, String userId);
  Future<bool> isFollowing(String playlistId);
}
