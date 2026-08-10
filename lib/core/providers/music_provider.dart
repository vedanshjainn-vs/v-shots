// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Provider Architecture: MusicProvider interface
// ═════════════════════════════════════════════════════════════════════════════

import 'provider_models.dart';
import 'provider_result.dart';

/// A capability a [MusicProvider] may or may not support. Checked via
/// [MusicProvider.supports] before [ProviderManager] routes a request
/// to that capability's method.
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
  /// Stable identifier used for logging/config (e.g. `"youtube"`).
  String get id;

  /// Human-readable name for any future debug/settings UI.
  String get displayName;

  /// Capabilities this provider actually supports.
  Set<ProviderCapability> get capabilities;

  bool supports(ProviderCapability capability) =>
      capabilities.contains(capability);

  /// One-time setup.
  Future<void> initialize();

  /// Cheap connectivity/availability check.
  Future<ProviderHealth> healthCheck();

  /// Searches for tracks matching [query].
  Future<ProviderResult<List<ProviderTrack>>> search(
    String query, {
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  });

  /// Fetches metadata for a single track by provider-specific [id].
  Future<ProviderResult<ProviderTrack>> getTrack(String id);

  /// Resolves a playable audio stream URL for licensed content.
  Future<ProviderResult<String>> getStream(String id);

  /// Returns the best-known artwork URL for a track.
  Future<ProviderResult<String>> getArtwork(String id);

  /// Fetches lyrics for a track, if supported.
  Future<ProviderResult<ProviderLyrics>> getLyrics({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  });

  /// Returns a currently-trending set of tracks, if supported.
  Future<ProviderResult<List<ProviderTrack>>> getTrending({int limit = 15});

  /// Returns recommended tracks given [excludeIds].
  Future<ProviderResult<List<ProviderTrack>>> getRecommendations({
    required Set<String> excludeIds,
    int limit = 10,
  });

  /// Releases held resources.
  Future<void> dispose();
}
