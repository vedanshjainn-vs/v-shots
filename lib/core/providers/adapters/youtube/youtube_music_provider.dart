// ════════════════════════════════════════════════
// V Shots — YouTubeMusicProvider (real content source, wrapped)
// ════════════════════════════════════════════════
//
// THIS DOES NOT REPLACE ANY EXISTING YOUTUBE CODE. It wraps:
//   - the app's single shared `YoutubeExplode` instance (constructed
//     in main.dart as `sharedYt` and passed in here — NOT a second
//     client)
//   - the EXISTING `resolveAudioStreamUrlLogged()` from
//     core/audio/stream_resolver.dart for all stream resolution (the
//     androidVr -> ios -> android fallback chain, its 15-min URL
//     cache, and its logging are all untouched — see that file's own
//     header for why a second/duplicate resolver must never be
//     created)
//   - `YoutubeMusicMapper` for the filter/clean/map logic that
//     previously existed as 3 near-duplicate inline copies
//
// Every method below is a thin adapter around code that already
// existed and already worked — this file's job is ONLY to expose that
// existing behavior through the `MusicProvider` interface so UI code
// can depend on `ProviderManager` instead of calling
// `sharedYt.search.search(...)` directly.
// ════════════════════════════════════════════════

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../audio/stream_resolver.dart';
import '../../../lyrics/lyrics_service.dart';
import '../../music_provider.dart';
import '../../provider_models.dart';
import '../../provider_result.dart';
import 'youtube_music_mapper.dart';

class YouTubeMusicProvider extends MusicProvider {
  YouTubeMusicProvider(
    this._yt, {
    YoutubeMusicMapper mapper = const YoutubeMusicMapper(),
    LyricsService? lyricsService,
  })  : _mapper = mapper,
        _lyrics = lyricsService ?? LyricsService.instance;

  /// The app's single shared instance (main.dart's `sharedYt`) — this
  /// class never constructs its own `YoutubeExplode()`. Constructing a
  /// second instance here would reintroduce exactly the "three
  /// separate YoutubeExplode instances" problem main.dart's own
  /// comments describe having already fixed once.
  final YoutubeExplode _yt;
  final YoutubeMusicMapper _mapper;
  final LyricsService _lyrics;

  @override
  String get id => 'youtube';

  @override
  String get displayName => 'YouTube';

  @override
  Set<ProviderCapability> get capabilities => const {
        ProviderCapability.search,
        ProviderCapability.getTrack,
        ProviderCapability.getStream,
        ProviderCapability.getArtwork,
        ProviderCapability.getLyrics,
        ProviderCapability.getTrending,
        ProviderCapability.getRecommendations,
        // NOTE: no getAlbum/getArtist/getPlaylist here (unlike
        // PROVIDER_ARCHITECTURE.md's aspirational interface) — YouTube
        // has no first-party equivalent the way Spotify/Apple Music
        // do, and this codebase does not fake one. See this class's
        // file header + music_provider.dart's design note.
      };

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    // `_yt` is constructed once in main.dart before this provider is
    // ever created — nothing to do here except mark readiness. Kept as
    // a real method (not a no-op stub) so the interface stays
    // meaningful for a future provider that DOES need async setup
    // (e.g. an OAuth token fetch).
    _initialized = true;
  }

  @override
  Future<ProviderHealth> healthCheck() async {
    if (!_initialized) {
      return const ProviderHealth(healthy: false, message: 'not initialized');
    }
    // A real, cheap connectivity check: YouTube search with a fixed,
    // guaranteed-to-return-something query, with a short timeout. This
    // deliberately reuses the same `_yt.search.search()` path real
    // requests use (not a separate ping endpoint YouTube doesn't
    // offer), capped so a slow/dead network fails fast rather than
    // hanging ProviderManager's failover loop.
    try {
      await _yt.search.search('a').timeout(const Duration(seconds: 6));
      return const ProviderHealth(healthy: true);
    } catch (e) {
      return ProviderHealth(healthy: false, message: '$e');
    }
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> search(
    String query, {
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) async {
    try {
      final results = await _yt.search.search(query);
      final tracks = _mapper.mapSearchResults(
        results,
        limit: limit,
        maxMinutes: maxDurationMinutes,
        minMinutes: minDurationMinutes,
        excludeIds: excludeIds,
      );
      return ProviderResult.success(tracks);
    } catch (e) {
      return ProviderResult.failure('YouTube search failed: $e');
    }
  }

  @override
  Future<ProviderResult<ProviderTrack>> getTrack(String id) async {
    try {
      final video = await _yt.videos.get(id);
      return ProviderResult.success(_mapper.toProviderTrack(video));
    } catch (e) {
      return ProviderResult.failure('YouTube getTrack failed: $e');
    }
  }

  @override
  Future<ProviderResult<String>> getStream(String id) async {
    // Delegates to the app's ONE existing, shared stream resolver —
    // see this file's header. Never re-implements
    // getManifest()/client-fallback logic here.
    final url = await resolveAudioStreamUrlLogged(_yt, id, tag: 'Provider');
    if (url == null) {
      return ProviderResult.failure(
        'Could not resolve a playable stream for $id',
      );
    }
    return ProviderResult.success(url);
  }

  @override
  Future<ProviderResult<String>> getArtwork(String id) async {
    // YouTube thumbnails are already embedded in search/track results
    // (see ProviderTrack.artworkUrl) — a caller that already has a
    // ProviderTrack should just use that field. This method exists for
    // interface completeness (a caller that only has an id) and does
    // one extra lookup via getTrack() rather than duplicating
    // thumbnail-URL logic.
    final trackResult = await getTrack(id);
    if (trackResult.isFailure) {
      return ProviderResult.failure(trackResult.error!);
    }
    return ProviderResult.success(trackResult.data!.artworkUrl);
  }

  @override
  Future<ProviderResult<ProviderLyrics>> getLyrics({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  }) async {
    // Delegates to the app's existing LRCLIB-backed LyricsService
    // (core/lyrics/lyrics_service.dart) — not a YouTube API at all
    // (YouTube has no lyrics endpoint), but exposed through this
    // provider because lyrics are conceptually "content for a track,"
    // matching the interface's getLyrics() slot. See
    // music_provider.dart's interface doc for why capabilities are
    // reported honestly rather than forced.
    final result = await _lyrics.fetch(
      trackName: trackName,
      artistName: artistName,
      durationSeconds: durationSeconds,
    );
    if (!result.hasAny) {
      return ProviderResult.failure('No lyrics found');
    }
    return ProviderResult.success(
      ProviderLyrics(
        plainText: result.plainText,
        hasSynced: result.hasSynced,
        instrumental: result.instrumental,
      ),
    );
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> getTrending({
    int limit = 15,
  }) async {
    // Matches HomeScreen's existing "Trending Now" query exactly (see
    // docs/CURRENT_BASELINE.md Section 4) — not a new/different query.
    return search('trending music today official audio', limit: limit);
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> getRecommendations({
    required Set<String> excludeIds,
    int limit = 10,
  }) async {
    // NOTE: this is a generic, non-personalized fallback
    // implementation (a fixed query filtered against excludeIds) —
    // the app's REAL personalization logic (recency-weighted taste
    // profile, similar-artist discovery, time-of-day buckets) lives in
    // ForYouFeedService and is intentionally NOT duplicated here (see
    // MusicRepository's doc comment for why ForYouFeedService keeps
    // calling this provider's search() directly for now rather than
    // this method being the only path). This method exists so the
    // MusicProvider interface is complete and testable in isolation.
    try {
      final results = await _yt.search.search('popular music hits');
      final tracks = _mapper.mapSearchResults(
        results,
        limit: limit,
        excludeIds: excludeIds,
      );
      return ProviderResult.success(tracks);
    } catch (e) {
      return ProviderResult.failure('YouTube getRecommendations failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    // Deliberately does NOT call `_yt.close()` — `_yt` is the app-wide
    // shared instance (main.dart's `sharedYt`), owned by main.dart's
    // lifetime, not this provider's. See for_you_feed_screen.dart's
    // own comment about the exact same real bug this would otherwise
    // reintroduce (a screen/provider closing the shared HTTP client
    // out from under the rest of the app).
  }
}
