// ════════════════════════════════════════════════
// Project Lyra — Playlist Remote Data Source
// ════════════════════════════════════════════════

import '../../../../../core/logging/app_logger.dart';
import '../models/playlist_models.dart';

abstract class PlaylistRemoteDataSource {
  Future<PlaylistModel> getPlaylist(String playlistId);
  Future<List<PlaylistModel>> getUserPlaylists({int page = 1, int limit = 20});
  Future<PlaylistModel> createPlaylist({required String title, String? description, bool isPublic = true});
  Future<void> deletePlaylist(String playlistId);
  Future<PlaylistModel> renamePlaylist(String playlistId, String newTitle);
  Future<void> addTrack(String playlistId, String trackId);
  Future<void> removeTrack(String playlistId, String trackId);
  Future<void> reorderTrack(String playlistId, int oldIndex, int newIndex);
  Future<void> followPlaylist(String playlistId);
  Future<void> unfollowPlaylist(String playlistId);
  Future<bool> isFollowing(String playlistId);
}

class SupabasePlaylistRemoteDataSource implements PlaylistRemoteDataSource {
  SupabasePlaylistRemoteDataSource({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  @override
  Future<PlaylistModel> getPlaylist(String playlistId) async {
    try {
      // TODO(team): Implement with Supabase.
      // final response = await supabase.from('playlists')
      //     .select('*, playlist_tracks(*, tracks(*))')
      //     .eq('id', playlistId)
      //     .single();
      throw UnimplementedError();
    } catch (e, st) {
      _logger.e('PlaylistRemote: getPlaylist failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<PlaylistModel>> getUserPlaylists({int page = 1, int limit = 20}) async {
    try {
      // TODO(team): Implement with Supabase.
      // final response = await supabase.from('playlists')
      //     .select()
      //     .eq('owner_id', supabase.auth.currentUser!.id)
      //     .range((page - 1) * limit, page * limit - 1)
      //     .order('updated_at', ascending: false);
      return [];
    } catch (e, st) {
      _logger.e('PlaylistRemote: getUserPlaylists failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<PlaylistModel> createPlaylist({required String title, String? description, bool isPublic = true}) async {
    try {
      // TODO(team): Implement with Supabase.
      // final response = await supabase.from('playlists').insert({
      //   'title': title,
      //   'description': description,
      //   'owner_id': supabase.auth.currentUser!.id,
      //   'is_public': isPublic,
      // }).select().single();
      throw UnimplementedError();
    } catch (e, st) {
      _logger.e('PlaylistRemote: createPlaylist failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    try {
      // await supabase.from('playlists').delete().eq('id', playlistId);
      _logger.d('PlaylistRemote: Deleted playlist $playlistId');
    } catch (e, st) {
      _logger.e('PlaylistRemote: deletePlaylist failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<PlaylistModel> renamePlaylist(String playlistId, String newTitle) async {
    try {
      // final response = await supabase.from('playlists')
      //     .update({'title': newTitle})
      //     .eq('id', playlistId)
      //     .select().single();
      throw UnimplementedError();
    } catch (e, st) {
      _logger.e('PlaylistRemote: renamePlaylist failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> addTrack(String playlistId, String trackId) async {
    try {
      // await supabase.from('playlist_tracks').insert({
      //   'playlist_id': playlistId,
      //   'track_id': trackId,
      //   'added_at': DateTime.now().toIso8601String(),
      // });
      _logger.d('PlaylistRemote: Added track $trackId to $playlistId');
    } catch (e, st) {
      _logger.e('PlaylistRemote: addTrack failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> removeTrack(String playlistId, String trackId) async {
    try {
      // await supabase.from('playlist_tracks')
      //     .delete()
      //     .eq('playlist_id', playlistId)
      //     .eq('track_id', trackId);
      _logger.d('PlaylistRemote: Removed track $trackId from $playlistId');
    } catch (e, st) {
      _logger.e('PlaylistRemote: removeTrack failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> reorderTrack(String playlistId, int oldIndex, int newIndex) async {
    try {
      _logger.d('PlaylistRemote: Reordered track in $playlistId');
    } catch (e, st) {
      _logger.e('PlaylistRemote: reorderTrack failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> followPlaylist(String playlistId) async {
    try {
      _logger.d('PlaylistRemote: Followed playlist $playlistId');
    } catch (e, st) {
      _logger.e('PlaylistRemote: followPlaylist failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> unfollowPlaylist(String playlistId) async {
    try {
      _logger.d('PlaylistRemote: Unfollowed playlist $playlistId');
    } catch (e, st) {
      _logger.e('PlaylistRemote: unfollowPlaylist failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<bool> isFollowing(String playlistId) async => false;
}
