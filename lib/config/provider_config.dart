// ════════════════════════════════════════════════
// V Shots — Provider Configuration
// ════════════════════════════════════════════════

/// Music provider configuration.
///
/// Change activeProvider to switch providers.
/// No app update required.
class ProviderConfig {
  ProviderConfig._();

  /// The currently active provider ID.
  /// Change this to switch providers.
  static const String activeProvider = 'youtube_music';

  /// Optional fallback provider ID.
  /// Used when the active provider fails.
  static const String? fallbackProvider = null;

  /// Whether to use fallback when active provider fails.
  static const bool allowFallback = true;

  /// Whether to cache provider responses.
  static const bool cacheEnabled = true;

  /// Cache duration for metadata.
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
