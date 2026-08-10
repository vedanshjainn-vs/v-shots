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
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) async {
    final result = await _manager.search(
      query,
      limit: limit,
      maxDurationMinutes: maxDurationMinutes,
      minDurationMinutes: minDurationMinutes,
      excludeIds: excludeIds,
    );
    return result.orElse(const []).map((t) => t.toTrackMap()).toList();
  }

  /// Detailed search that preserves success/failure distinction.
  Future<({bool success, List<Map<String, dynamic>> tracks, String? error})>
  searchDetailed(
    String query, {
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) async {
    final result = await _manager.search(
      query,
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

  Future<List<Map<String, dynamic>>> getTrending({int limit = 15}) async {
    final result = await _manager.getTrending(limit: limit);
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

  /// Resolves a playable stream URL for licensed / UGC content.
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
