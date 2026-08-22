// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Provider Architecture: MusicProvider interface
// ═════════════════════════════════════════════════════════════════════════════

import 'provider_models.dart';
import 'provider_result.dart';

/// A capability a [MusicProvider] may or may not support.
enum ProviderCapability {
  search,
  getTrack,
  getStream,
  getArtwork,
  getLyrics,
  getTrending,
  getRecommendations,
  getRelated,
  getPlaylist,
  getChannel,
}

/// Abstract interface every music/content provider must implement.
abstract class MusicProvider {
  String get id;
  String get displayName;
  Set<ProviderCapability> get capabilities;

  bool supports(ProviderCapability capability) =>
      capabilities.contains(capability);

  Future<void> initialize();
  Future<ProviderHealth> healthCheck();

  Future<ProviderResult<List<ProviderTrack>>> search(
    String query, {
    String order = 'relevance',
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  });

  /// Paginated search. Providers that support [ProviderCapability.search]
  /// must implement this too (InnerTube: continuation tokens; Data API:
  /// pageToken). Returns one page plus a token for the next page (null when
  /// exhausted).
  Future<ProviderResult<ProviderSearchPage>> searchPage(
    String query, {
    String order = 'relevance',
    int limit = 20,
    Set<String> excludeIds = const {},
    String? pageToken,
  });

  Future<ProviderResult<ProviderTrack>> getTrack(String id);
  Future<ProviderResult<String>> getStream(String id);
  Future<ProviderResult<String>> getArtwork(String id);

  Future<ProviderResult<ProviderLyrics>> getLyrics({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  });

  Future<ProviderResult<List<ProviderTrack>>> getTrending({
    int limit = 15,
    String region = '',
  });

  /// Tracks of a YouTube playlist (playlist order; unavailable entries
  /// skipped). Providers with native playlist browsing declare
  /// [ProviderCapability.getPlaylist]; the default fails and is never routed
  /// to.
  Future<ProviderResult<List<ProviderTrack>>> getPlaylistTracks(
    String playlistId, {
    int limit = 30,
  }) async {
    return ProviderResult.failure(
      'getPlaylistTracks not supported by this provider',
    );
  }

  /// Latest tracks of a YouTube channel. Providers with native channel
  /// browsing declare [ProviderCapability.getChannel]; default fails.
  Future<ProviderResult<List<ProviderTrack>>> getChannelTracks(
    String channelId, {
    int limit = 30,
  }) async {
    return ProviderResult.failure(
      'getChannelTracks not supported by this provider',
    );
  }

  Future<ProviderResult<List<ProviderTrack>>> getRecommendations({
    required Set<String> excludeIds,
    int limit = 10,
  });

  /// Related tracks for a given track ("More Like This"). Only providers
  /// with a native related-content endpoint (InnerTube's `/next`) implement
  /// this and declare [ProviderCapability.getRelated]; the default returns
  /// failure and is never routed to (ProviderManager only routes to
  /// providers whose `supports(getRelated)` is true).
  Future<ProviderResult<List<ProviderTrack>>> getRelated(
    String trackId, {
    int limit = 10,
  }) async {
    return ProviderResult.failure('getRelated not supported by this provider');
  }

  Future<void> dispose();
}
