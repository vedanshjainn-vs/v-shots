// ════════════════════════════════════════════════
// V Shots — Provider Architecture: MusicProvider interface
// ════════════════════════════════════════════════
//
// This is the abstract interface every content provider must
// implement — the real, code-level version of what
// docs/architecture/PROVIDER_ARCHITECTURE.md described but was never
// actually built (confirmed during the read-only audit: zero
// `class.*Provider` matches existed in lib/ before this file).
//
// DESIGN NOTE — what this interface deliberately does NOT do:
// It does not force every provider to support every capability. A
// provider that genuinely can't do something (e.g. YouTube has no
// first-party "get album" concept the way Spotify does) reports that
// honestly via `ProviderCapability` rather than the app pretending it
// works with fake/empty data. This matches the task's explicit
// instruction: "Do not force unsupported capabilities to pretend they
// work."
// ════════════════════════════════════════════════

import 'provider_models.dart';
import 'provider_result.dart';

/// A capability a [MusicProvider] may or may not support. Checked via
/// [MusicProvider.supports] before [ProviderManager] routes a request
/// to that capability's method — callers get an honest
/// `ProviderResult.failure('not supported')` rather than a silently
/// empty/fake result.
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
/// See `adapters/youtube/youtube_music_provider.dart` for the current
/// (and, for now, only) real implementation — it wraps the app's
/// EXISTING `YoutubeExplode` client and `resolveAudioStreamUrlLogged()`
/// stream resolver rather than reimplementing YouTube access.
abstract class MusicProvider {
  /// Stable identifier used for logging/config (e.g. `"youtube"`).
  String get id;

  /// Human-readable name for any future debug/settings UI.
  String get displayName;

  /// Capabilities this provider actually supports. [ProviderManager]
  /// consults this before routing — see [ProviderCapability]'s doc.
  Set<ProviderCapability> get capabilities;

  bool supports(ProviderCapability capability) =>
      capabilities.contains(capability);

  /// One-time setup (e.g. constructing an HTTP client). Must be safe
  /// to call multiple times (no-op after the first successful call).
  Future<void> initialize();

  /// Cheap connectivity/availability check — used by [ProviderManager]
  /// to decide whether this provider is currently usable. This is NOT
  /// a full request (see [ProviderHealth]'s doc for scope).
  Future<ProviderHealth> healthCheck();

  /// Searches for tracks matching [query]. [limit] caps result count
  /// (providers may return fewer). [maxDurationMinutes]/
  /// [minDurationMinutes] let callers preserve per-surface tuning that
  /// existed before this provider layer was introduced (Home/Search
  /// used a 15-min cap with no floor; the For You feed used a 12-min
  /// cap with a 1-min floor — see YoutubeMusicMapper's doc for why
  /// these differ per call site rather than being one hardcoded
  /// constant).
  Future<ProviderResult<List<ProviderTrack>>> search(
    String query, {
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  });

  /// Fetches metadata for a single track by provider-specific [id].
  Future<ProviderResult<ProviderTrack>> getTrack(String id);

  /// Resolves a playable audio stream URL for the track with
  /// provider-specific [id]. This is the ONLY place a provider may
  /// touch actual stream resolution — see
  /// `YouTubeMusicProvider.getStream()`'s doc comment for why it must
  /// delegate to the existing `resolveAudioStreamUrlLogged()` rather
  /// than duplicating that logic.
  Future<ProviderResult<String>> getStream(String id);

  /// Returns the best-known artwork URL for a track. For providers
  /// where artwork is already embedded in search/track results (true
  /// for YouTube thumbnails), this may just echo back
  /// `getTrack(id).artworkUrl` rather than making a second request.
  Future<ProviderResult<String>> getArtwork(String id);

  /// Fetches lyrics for a track, if this provider supports it.
  /// Returns `ProviderResult.failure(...)` (not fake data) if
  /// `!supports(ProviderCapability.getLyrics)`.
  Future<ProviderResult<ProviderLyrics>> getLyrics({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  });

  /// Returns a currently-trending set of tracks, if supported.
  Future<ProviderResult<List<ProviderTrack>>> getTrending({int limit = 15});

  /// Returns recommended tracks given [excludeIds] already seen this
  /// session — used by the Discover/For You feed and Home's "Made For
  /// You" section.
  Future<ProviderResult<List<ProviderTrack>>> getRecommendations({
    required Set<String> excludeIds,
    int limit = 10,
  });

  /// Releases any held resources (HTTP clients, etc.). Not currently
  /// called anywhere in the live app (the single shared `sharedYt`
  /// instance is intentionally kept alive for the app's whole
  /// lifetime — see stream_resolver.dart/main.dart's own notes on why
  /// closing it prematurely broke things before) — implemented for
  /// interface completeness and for provider-level unit tests that
  /// construct/dispose their own instances.
  Future<void> dispose();
}
