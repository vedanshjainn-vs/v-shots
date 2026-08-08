// ════════════════════════════════════════════════
// Project Lyra — Library Remote Data Source
// ════════════════════════════════════════════════

import '../../../../../core/logging/app_logger.dart';
import '../models/library_models.dart';

/// Remote data source for library operations.
abstract class LibraryRemoteDataSource {
  Future<LibraryModel> getLibrary();
  Future<void> likeSong(String trackId);
  Future<void> unlikeSong(String trackId);
  Future<void> saveAlbum(String albumId);
  Future<void> removeAlbum(String albumId);
  Future<void> followArtist(String artistId);
  Future<void> unfollowArtist(String artistId);
  Future<void> savePlaylist(String playlistId);
  Future<void> removePlaylist(String playlistId);
  Future<List<SavedTrackModel>> getLikedSongs({int page = 1, int limit = 50});
  Future<List<SavedAlbumModel>> getSavedAlbums({int page = 1, int limit = 20});
  Future<List<SavedArtistModel>> getFollowedArtists({int page = 1, int limit = 20});
  Future<List<RecentlyPlayedModel>> getRecentlyPlayed({int limit = 50});
  Future<void> addToRecentlyPlayed(RecentlyPlayedModel item);
  Future<bool> isLiked(String trackId);
  Future<bool> isAlbumSaved(String albumId);
  Future<bool> isArtistFollowed(String artistId);
}

/// Supabase implementation of [LibraryRemoteDataSource].
class SupabaseLibraryRemoteDataSource implements LibraryRemoteDataSource {
  SupabaseLibraryRemoteDataSource({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  @override
  Future<LibraryModel> getLibrary() async {
    try {
      // TODO(team): Implement with Supabase queries.
      // final userId = supabase.auth.currentUser!.id;
      // final likedSongs = await supabase.from('liked_songs')
      //     .select('*, tracks(*)')
      //     .eq('user_id', userId)
      //     .order('liked_at', ascending: false);
      // final savedAlbums = await supabase.from('saved_albums')
      //     .select('*, albums(*)')
      //     .eq('user_id', userId);
      // ...
      return const LibraryModel();
    } catch (e, st) {
      _logger.e('LibraryRemote: getLibrary failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> likeSong(String trackId) async {
    try {
      // await supabase.from('liked_songs').insert({
      //   'user_id': supabase.auth.currentUser!.id,
      //   'track_id': trackId,
      //   'liked_at': DateTime.now().toIso8601String(),
      // });
      _logger.d('LibraryRemote: Liked track $trackId');
    } catch (e, st) {
      _logger.e('LibraryRemote: likeSong failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> unlikeSong(String trackId) async {
    try {
      // await supabase.from('liked_songs')
      //     .delete()
      //     .eq('user_id', supabase.auth.currentUser!.id)
      //     .eq('track_id', trackId);
      _logger.d('LibraryRemote: Unliked track $trackId');
    } catch (e, st) {
      _logger.e('LibraryRemote: unlikeSong failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> saveAlbum(String albumId) async {
    try {
      _logger.d('LibraryRemote: Saved album $albumId');
    } catch (e, st) {
      _logger.e('LibraryRemote: saveAlbum failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> removeAlbum(String albumId) async {
    try {
      _logger.d('LibraryRemote: Removed album $albumId');
    } catch (e, st) {
      _logger.e('LibraryRemote: removeAlbum failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> followArtist(String artistId) async {
    try {
      _logger.d('LibraryRemote: Followed artist $artistId');
    } catch (e, st) {
      _logger.e('LibraryRemote: followArtist failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> unfollowArtist(String artistId) async {
    try {
      _logger.d('LibraryRemote: Unfollowed artist $artistId');
    } catch (e, st) {
      _logger.e('LibraryRemote: unfollowArtist failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> savePlaylist(String playlistId) async {
    try {
      _logger.d('LibraryRemote: Saved playlist $playlistId');
    } catch (e, st) {
      _logger.e('LibraryRemote: savePlaylist failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> removePlaylist(String playlistId) async {
    try {
      _logger.d('LibraryRemote: Removed playlist $playlistId');
    } catch (e, st) {
      _logger.e('LibraryRemote: removePlaylist failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<SavedTrackModel>> getLikedSongs({int page = 1, int limit = 50}) async {
    try {
      return [];
    } catch (e, st) {
      _logger.e('LibraryRemote: getLikedSongs failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<SavedAlbumModel>> getSavedAlbums({int page = 1, int limit = 20}) async {
    try {
      return [];
    } catch (e, st) {
      _logger.e('LibraryRemote: getSavedAlbums failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<SavedArtistModel>> getFollowedArtists({int page = 1, int limit = 20}) async {
    try {
      return [];
    } catch (e, st) {
      _logger.e('LibraryRemote: getFollowedArtists failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<RecentlyPlayedModel>> getRecentlyPlayed({int limit = 50}) async {
    try {
      return [];
    } catch (e, st) {
      _logger.e('LibraryRemote: getRecentlyPlayed failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> addToRecentlyPlayed(RecentlyPlayedModel item) async {
    try {
      _logger.d('LibraryRemote: Added to recently played: ${item.id}');
    } catch (e, st) {
      _logger.e('LibraryRemote: addToRecentlyPlayed failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<bool> isLiked(String trackId) async => false;

  @override
  Future<bool> isAlbumSaved(String albumId) async => false;

  @override
  Future<bool> isArtistFollowed(String artistId) async => false;
}
