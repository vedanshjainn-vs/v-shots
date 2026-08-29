// ═════════════════════════════════════════════════════════════════════════════
// V Shots — MusicRepository (Unified Content Repository)
// ═════════════════════════════════════════════════════════════════════════════

import 'provider_manager.dart';
import 'provider_models.dart';

class MusicRepository {
  MusicRepository(this._manager);

  final ProviderManager _manager;

  /// Searches for tracks and returns them as `Map<String, dynamic>` track models.
  Future<List<Map<String, dynamic>>> search(
    String query, {
    String order = 'relevance',
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) async {
    final result = await _manager.search(
      query,
      order: order,
      limit: limit,
      maxDurationMinutes: maxDurationMinutes,
      minDurationMinutes: minDurationMinutes,
      excludeIds: excludeIds,
    );
    return result.orElse(const []).map((t) => t.toTrackMap()).toList();
  }

  /// Paginated search — returns one page of tracks plus a token for the next
  /// page (null when exhausted). Routed through ProviderManager, so the
  /// primary (InnerTube) provider is tried first with failover to YouTube.
  Future<({List<Map<String, dynamic>> tracks, String? nextPageToken})>
  searchPaginated(
    String query, {
    String order = 'relevance',
    int limit = 20,
    Set<String> excludeIds = const {},
    String? pageToken,
  }) async {
    final result = await _manager.searchPage(
      query,
      order: order,
      limit: limit,
      excludeIds: excludeIds,
      pageToken: pageToken,
    );
    final ({List<Map<String, dynamic>> tracks, String? nextPageToken}) page =
        result.isSuccess && result.data != null
        ? (
            tracks: result.data!.tracks.map((t) => t.toTrackMap()).toList(),
            nextPageToken: result.data!.nextPageToken,
          )
        : (tracks: <Map<String, dynamic>>[], nextPageToken: null);
    return page;
  }

  /// Detailed search that preserves success/failure distinction.
  Future<({bool success, List<Map<String, dynamic>> tracks, String? error})>
  searchDetailed(
    String query, {
    String order = 'relevance',
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) async {
    final result = await _manager.search(
      query,
      order: order,
      limit: limit,
      maxDurationMinutes: maxDurationMinutes,
      minDurationMinutes: minDurationMinutes,
      excludeIds: excludeIds,
    );
    return (
      success: result.isSuccess,
      tracks: result.orElse(const []).map((t) => t.toTrackMap()).toList(),
      error: result.error,
    );
  }

  /// Related tracks for [trackId] ("More Like This") via the primary
  /// provider (InnerTube's /next). Returns an empty list on failure, so
  /// callers can fall back gracefully.
  Future<List<Map<String, dynamic>>> getRelated(
    String trackId, {
    int limit = 10,
  }) async {
    final result = await _manager.getRelated(trackId, limit: limit);
    return result.orElse(const []).map((t) => t.toTrackMap()).toList();
  }

  Future<List<Map<String, dynamic>>> getTrending({
    int limit = 15,
    String region = '',
  }) async {
    final result = await _manager.getTrending(limit: limit, region: region);
    return result.orElse(const []).map((t) => t.toTrackMap()).toList();
  }

  /// Tracks of a YouTube playlist in playlist order (unavailable entries
  /// skipped). Empty on failure.
  Future<List<Map<String, dynamic>>> getPlaylistTracks(
    String playlistId, {
    int limit = 30,
  }) async {
    final result = await _manager.getPlaylistTracks(playlistId, limit: limit);
    return result.orElse(const []).map((t) => t.toTrackMap()).toList();
  }

  /// Latest uploads of a YouTube channel. Empty on failure.
  Future<List<Map<String, dynamic>>> getChannelTracks(
    String channelId, {
    int limit = 30,
  }) async {
    final result = await _manager.getChannelTracks(channelId, limit: limit);
    return result.orElse(const []).map((t) => t.toTrackMap()).toList();
  }

  Future<List<Map<String, dynamic>>> getRecommendations({
    required Set<String> excludeIds,
    int limit = 10,
  }) async {
    final result = await _manager.getRecommendations(
      excludeIds: excludeIds,
      limit: limit,
    );
    return result.orElse(const []).map((t) => t.toTrackMap()).toList();
  }

  Future<String?> getStream(String trackId) async {
    final result = await _manager.getStream(trackId);
    return result.isSuccess ? result.data : null;
  }

  Future<ProviderLyrics?> getLyrics({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  }) async {
    final result = await _manager.getLyrics(
      trackName: trackName,
      artistName: artistName,
      durationSeconds: durationSeconds,
    );
    return result.isSuccess ? result.data : null;
  }
}
