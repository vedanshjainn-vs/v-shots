// ════════════════════════════════════════════════
// Project Lyra — Stream Manager
// ════════════════════════════════════════════════
//
// Manages audio stream URLs:
// - Request stream from provider
// - Validate stream URL
// - Handle expiry
// - Refresh authorization
// - Quality selection
// - Cache stream URLs
// ════════════════════════════════════════════════

import '../cache/cache_key.dart';
import '../cache/cache_manager.dart';
import '../cache/policies/cache_policy.dart';
import '../logging/app_logger.dart';
import '../providers/manager/provider_manager.dart';
import '../providers/models/provider_models.dart';

/// Manages audio stream URLs for playback.
///
/// Handles stream URL lifecycle: request, cache,
/// expiry detection, and refresh.
///
/// ```dart
/// final stream = await streamManager.getStream('track_123');
/// await player.play(stream.url);
/// ```
class StreamManager {
  StreamManager({
    required this.providerManager,
    required this.cacheManager,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final ProviderManager providerManager;
  final CacheManager cacheManager;
  final AppLogger _logger;

  final Map<String, ProviderStreamInfo> _activeStreams = {};

  /// Get a stream URL for a track.
  ///
  /// Returns cached stream if still valid, otherwise
  /// fetches a new one from the provider.
  Future<ProviderStreamInfo> getStream(
    String trackId, {
    StreamQuality? quality,
  }) async {
    // Check active streams cache.
    final cached = _activeStreams[trackId];
    if (cached != null && _isStreamValid(cached)) {
      _logger.d('StreamManager: Cache hit for $trackId');
      return cached;
    }

    // Fetch from provider.
    _logger.d('StreamManager: Fetching stream for $trackId');
    final stream = await providerManager.getStream(trackId, quality: quality);

    // Cache the stream URL.
    _activeStreams[trackId] = stream;

    // Cache in disk for offline playback.
    await cacheManager.putRaw(
      CacheKey(namespace: 'streams', id: trackId),
      stream.toJson().toString(),
    );

    return stream;
  }

  /// Get stream for offline playback.
  Future<ProviderStreamInfo?> getOfflineStream(String trackId) async {
    final cached = cacheManager.getRaw(CacheKey(namespace: 'streams', id: trackId));
    if (cached != null) {
      // TODO(team): Deserialize cached stream.
      return null;
    }
    return null;
  }

  /// Validate a stream URL.
  Future<bool> validateStream(String url) async {
    try {
      // TODO(team): Make a HEAD request to check if URL is still valid.
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear stream cache for a track.
  void invalidate(String trackId) {
    _activeStreams.remove(trackId);
  }

  /// Clear all cached streams.
  void clearCache() {
    _activeStreams.clear();
  }

  bool _isStreamValid(ProviderStreamInfo stream) {
    if (stream.expiresAt == null) return true;
    return DateTime.now().isBefore(stream.expiresAt!);
  }
}
