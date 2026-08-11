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

  Future<ProviderResult<ProviderTrack>> getTrack(String id);
  Future<ProviderResult<String>> getStream(String id);
  Future<ProviderResult<String>> getArtwork(String id);

  Future<ProviderResult<ProviderLyrics>> getLyrics({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  });

  Future<ProviderResult<List<ProviderTrack>>> getTrending({int limit = 15});

  Future<ProviderResult<List<ProviderTrack>>> getRecommendations({
    required Set<String> excludeIds,
    int limit = 10,
  });

  Future<void> dispose();
}
