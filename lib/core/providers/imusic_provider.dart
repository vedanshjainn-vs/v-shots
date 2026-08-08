// ════════════════════════════════════════════════
// Project Lyra — Music Provider Interface
// ════════════════════════════════════════════════
//
// The unified interface that ALL music providers must
// implement. The Flutter app only talks to this interface.
//
// Provider implementations are isolated behind this contract.
// The app NEVER knows which provider is active.
// ════════════════════════════════════════════════

import 'models/provider_models.dart';

/// Abstract music provider interface.
///
/// Every music catalog provider (Spotify, Apple Music, YouTube Music, etc.)
/// must implement this interface. The ProviderManager routes requests
/// to the currently active provider transparently.
///
/// ```dart
/// class SpotifyProvider implements IMusicProvider {
///   @override
///   Future<ProviderTrack> getTrack(String id) async { ... }
/// }
/// ```
abstract class IMusicProvider {
  /// Unique identifier for this provider (e.g., 'spotify', 'apple_music').
  String get id;

  /// Human-readable name (e.g., 'Spotify', 'Apple Music').
  String get name;

  /// Provider version for compatibility tracking.
  String get version;

  /// Capabilities this provider supports.
  ProviderCapabilities get capabilities;

  // ── Lifecycle ────────────────────────────────

  /// Initialize the provider (auth, connection setup).
  Future<void> initialize(ProviderInitConfig config);

  /// Check if the provider is healthy and available.
  Future<HealthStatus> healthCheck();

  /// Dispose resources.
  Future<void> dispose();

  // ── Search ───────────────────────────────────

  /// Search across all content types.
  Future<ProviderSearchResult> search(
    String query, {
    SearchFilter? filter,
    int page = 1,
    int limit = 20,
  });

  /// Get search suggestions/autocomplete.
  Future<List<String>> getSuggestions(String query);

  // ── Tracks ───────────────────────────────────

  /// Get track metadata by ID.
  Future<ProviderTrack> getTrack(String id);

  /// Get multiple tracks by IDs.
  Future<List<ProviderTrack>> getTracks(List<String> ids);

  /// Get stream URL for a track.
  Future<ProviderStreamInfo> getStream(String id, {StreamQuality? quality});

  /// Get lyrics for a track.
  Future<ProviderLyrics?> getLyrics(String id);

  // ── Albums ───────────────────────────────────

  /// Get album metadata by ID.
  Future<ProviderAlbum> getAlbum(String id);

  /// Get album tracks.
  Future<List<ProviderTrack>> getAlbumTracks(String id, {int page = 1, int limit = 50});

  // ── Artists ──────────────────────────────────

  /// Get artist metadata by ID.
  Future<ProviderArtist> getArtist(String id);

  /// Get artist's top tracks.
  Future<List<ProviderTrack>> getArtistTopTracks(String id, {int limit = 10});

  /// Get artist's albums.
  Future<List<ProviderAlbum>> getArtistAlbums(String id, {int page = 1, int limit = 20});

  /// Get related/similar artists.
  Future<List<ProviderArtist>> getRelatedArtists(String id, {int limit = 10});

  // ── Playlists ────────────────────────────────

  /// Get playlist metadata by ID.
  Future<ProviderPlaylist> getPlaylist(String id);

  /// Get playlist tracks.
  Future<List<ProviderTrack>> getPlaylistTracks(String id, {int page = 1, int limit = 50});

  // ── Recommendations ──────────────────────────

  /// Get personalized recommendations.
  Future<List<ProviderTrack>> getRecommendations({
    List<String>? seedTrackIds,
    List<String>? seedArtistIds,
    int limit = 20,
  });

  /// Get trending/popular content.
  Future<List<ProviderTrack>> getTrending({
    String? genre,
    String? region,
    int limit = 20,
  });

  /// Get new releases.
  Future<List<ProviderAlbum>> getNewReleases({
    String? region,
    int limit = 20,
  });

  // ── Artwork ──────────────────────────────────

  /// Get artwork URL for a content item.
  Future<String?> getArtwork(String id, {ArtworkSize size = ArtworkSize.medium});

  // ── Genres ───────────────────────────────────

  /// Get available genres.
  Future<List<String>> getGenres();
}

/// Capabilities that a provider supports.
class ProviderCapabilities {
  const ProviderCapabilities({
    required this.supportsSearch,
    required this.supportsStreaming,
    required this.supportsLyrics,
    required this.supportsRecommendations,
    required this.supportsTrending,
    required this.supportsOffline,
    required this.supportsHighQuality,
    required this.supportsPodcasts,
    required this.supportsAudiobooks,
    this.maxBitrate = 128,
    this.maxSearchResults = 50,
    this.supportedRegions = const [],
  });

  final bool supportsSearch;
  final bool supportsStreaming;
  final bool supportsLyrics;
  final bool supportsRecommendations;
  final bool supportsTrending;
  final bool supportsOffline;
  final bool supportsHighQuality;
  final bool supportsPodcasts;
  final bool supportsAudiobooks;
  final int maxBitrate;
  final int maxSearchResults;
  final List<String> supportedRegions;
}

/// Configuration for initializing a provider.
class ProviderInitConfig {
  const ProviderConfig({
    required this.apiKey,
    this.apiSecret,
    this.baseUrl,
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 3,
    this.enableLogging = false,
    this.custom = const {},
  });

  final String apiKey;
  final String? apiSecret;
  final String? baseUrl;
  final Duration timeout;
  final int maxRetries;
  final bool enableLogging;
  final Map<String, dynamic> custom;
}

/// Health status of a provider.
class HealthStatus {
  const HealthStatus({
    required this.isHealthy,
    this.latencyMs = 0,
    this.message,
    this.lastChecked,
  });

  final bool isHealthy;
  final int latencyMs;
  final String? message;
  final DateTime? lastChecked;
}

/// Search filter options.
class SearchFilter {
  const SearchFilter({
    this.types = const ['track', 'album', 'artist', 'playlist'],
    this.genre,
    this.year,
    this.region,
  });

  final List<String> types;
  final String? genre;
  final int? year;
  final String? region;
}
