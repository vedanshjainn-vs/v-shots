// ════════════════════════════════════════════════
// Project Lyra — Library Repository Interface
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/library_entities.dart';

typedef Result<T> = Either<Failure, T>;

abstract class LibraryRepository {
  Future<Result<Library>> getLibrary({bool forceRefresh = false});
  Future<Result<void>> likeSong(String trackId);
  Future<Result<void>> unlikeSong(String trackId);
  Future<Result<void>> saveAlbum(String albumId);
  Future<Result<void>> removeAlbum(String albumId);
  Future<Result<void>> followArtist(String artistId);
  Future<Result<void>> unfollowArtist(String artistId);
  Future<Result<void>> savePlaylist(String playlistId);
  Future<Result<void>> removePlaylist(String playlistId);
  Future<Result<List<SavedTrack>>> getLikedSongs({int page = 1, int limit = 50});
  Future<Result<List<SavedAlbum>>> getSavedAlbums({int page = 1, int limit = 20});
  Future<Result<List<SavedArtist>>> getFollowedArtists({int page = 1, int limit = 20});
  Future<Result<List<RecentlyPlayed>>> getRecentlyPlayed({int limit = 50});
  Future<Result<void>> syncLibrary();
  Future<Result<void>> addToRecentlyPlayed(RecentlyPlayed item);
  Future<bool> isLiked(String trackId);
  Future<bool> isAlbumSaved(String albumId);
  Future<bool> isArtistFollowed(String artistId);
  Stream<Library> get libraryStream;
}
