// ════════════════════════════════════════════════
// Project Lyra — Player Remote Data Source
// ════════════════════════════════════════════════

import '../../../../../core/logging/app_logger.dart';
import '../models/player_models.dart';

abstract class PlayerRemoteDataSource {
  Future<TrackModel> getTrack(String trackId);
  Future<AlbumModel> getAlbum(String albumId);
  Future<String> getStreamUrl(String trackId);
  Future<LyricsModel?> getLyrics(String trackId);
  Future<void> recordPlay(String trackId);
}

class SupabasePlayerRemoteDataSource implements PlayerRemoteDataSource {
  SupabasePlayerRemoteDataSource({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  @override
  Future<TrackModel> getTrack(String trackId) async {
    try {
      // TODO(team): Implement with Supabase.
      // final response = await supabase.from('tracks').select().eq('id', trackId).single();
      // return TrackModel.fromJson(response);
      throw UnimplementedError('Track not found: $trackId');
    } catch (e, st) {
      _logger.e('PlayerRemote: getTrack failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<AlbumModel> getAlbum(String albumId) async {
    try {
      // TODO(team): Implement with Supabase.
      throw UnimplementedError('Album not found: $albumId');
    } catch (e, st) {
      _logger.e('PlayerRemote: getAlbum failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<String> getStreamUrl(String trackId) async {
    try {
      // TODO(team): Implement with Supabase Storage signed URL.
      // final response = await supabase.storage.from('tracks').createSignedUrl('$trackId.mp3', 3600);
      // return response;
      return 'https://stream.projectlyra.com/tracks/$trackId';
    } catch (e, st) {
      _logger.e('PlayerRemote: getStreamUrl failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<LyricsModel?> getLyrics(String trackId) async {
    try {
      // TODO(team): Implement with Supabase.
      return null;
    } catch (e, st) {
      _logger.e('PlayerRemote: getLyrics failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<void> recordPlay(String trackId) async {
    try {
      // TODO(team): Implement with Supabase insert.
      // await supabase.from('play_history').insert({
      //   'user_id': supabase.auth.currentUser!.id,
      //   'track_id': trackId,
      //   'played_at': DateTime.now().toIso8601String(),
      // });
      _logger.d('PlayerRemote: Recorded play for $trackId');
    } catch (e, st) {
      _logger.e('PlayerRemote: recordPlay failed', error: e, stackTrace: st);
    }
  }
}
