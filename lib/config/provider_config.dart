// ════════════════════════════════════════════════
// Project Lyra — Provider Configuration
// ════════════════════════════════════════════════
//
// Simple, static configuration for music providers.
// Change these values to switch providers.
// No database, no dashboard, no admin panel.
// ════════════════════════════════════════════════

/// Music provider configuration.
///
/// Edit these constants to change which provider is active.
///
/// To add a new provider:
/// 1. Create a class implementing IMusicProvider
/// 2. Register it in ProviderRegistry
/// 3. Set activeProvider to its id
class ProviderConfig {
  ProviderConfig._();

  /// The currently active provider ID.
  /// Change this to switch providers.
  static const String activeProvider = 'development';

  /// Optional fallback provider ID.
  /// Used when the active provider fails.
  /// Set to null to disable fallback.
  static const String? fallbackProvider = null;

  /// Whether to use fallback when active provider fails.
  static const bool allowFallback = true;

  /// Whether to cache provider responses.
  static const bool cacheEnabled = true;

  /// Cache duration for metadata (tracks, albums, artists).
  static const Duration metadataCacheDuration = Duration(hours: 1);

  /// Cache duration for search results.
  static const Duration searchCacheDuration = Duration(minutes: 5);

  /// Cache duration for stream URLs.
  static const Duration streamCacheDuration = Duration(minutes: 30);

  /// Maximum retries before failing.
  static const int maxRetries = 3;

  /// Request timeout duration.
  static const Duration requestTimeout = Duration(seconds: 15);
}
