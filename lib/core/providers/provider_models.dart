// ════════════════════════════════════════════════
// V Shots — Provider Architecture: shared data models
// ════════════════════════════════════════════════
//
// WHY THIS FILE EXISTS:
// The app's existing playback/search code (main.dart, for_you_feed_*)
// passes tracks around as raw `Map<String, dynamic>` — that data shape
// is NOT changing (it is load-bearing: LocalLibrary persists it as
// JSON, the UI reads `track['title']` etc. everywhere). `ProviderTrack`
// below is a typed wrapper used ONLY at the provider-boundary (i.e.
// what a provider's search()/getTrack()/getTrending() methods return),
// with `toTrackMap()`/`ProviderTrack.fromTrackMap()` converters at each
// end so the rest of the app keeps working exactly as before. This is
// intentionally a thin adapter layer, not a rewrite of the app's data
// model.
// ════════════════════════════════════════════════

/// Which catalog/content provider produced a given result. Only
/// `youtube` is implemented right now (see
/// adapters/youtube/youtube_music_provider.dart) — this enum exists so
/// the architecture can add a second provider later (Phase 6/Future)
/// without changing this type's shape.
enum ProviderId { youtube }

/// A single track/video result, as returned by any [MusicProvider].
/// Deliberately mirrors the fields the app's existing
/// `Map<String, dynamic>` track records already use
/// (id/title/artist/artwork/duration), so converting to/from the
/// app's real data shape is lossless.
class ProviderTrack {
  const ProviderTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.durationSeconds,
    this.providerId = ProviderId.youtube,
    this.isOfficial = false,
    this.channelId,
    this.viewCount,
    this.publishedDaysAgo,
  });

  final String id;
  final String title;
  final String artist;
  final String artworkUrl;
  final int durationSeconds;
  final ProviderId providerId;

  /// True when the uploader carries an official/verified creator badge
  /// (InnerTube metadata). Used to prefer and badge original artist uploads.
  /// NEVER true just because a channel name contains "official"/"music".
  final bool isOfficial;

  /// Uploader channel id (YouTube `UC...`) when available, else null.
  final String? channelId;

  /// Real view count when the source provides one (InnerTube/Data API).
  final int? viewCount;

  /// Approximate days since upload, when the source provides a publish time.
  final int? publishedDaysAgo;

  /// Converts to the app's existing `Map<String, dynamic>` track shape
  /// — this is what actually flows into `currentQueue`, `LocalLibrary`,
  /// `playTrack()`, etc. Field names/values are UNCHANGED from what
  /// main.dart's own `_search()`/`ForYouFeedService.fetchNextBatch()`
  /// already produced; `isOfficial`/`channelId` are ADDITIVE keys, so no
  /// downstream consumer breaks.
  Map<String, dynamic> toTrackMap() => {
    'id': id,
    'title': title,
    'artist': artist,
    'artwork': artworkUrl,
    'duration': durationSeconds,
    if (isOfficial) 'isOfficial': true,
    if (channelId != null && channelId!.isNotEmpty) 'channelId': channelId,
    if (viewCount != null) 'views': viewCount,
    if (publishedDaysAgo != null) 'ageDays': publishedDaysAgo,
  };

  /// Builds a [ProviderTrack] from the app's existing
  /// `Map<String, dynamic>` shape — used where existing code already
  /// has a track map and needs to hand it to a provider method that
  /// expects a [ProviderTrack] (currently unused in the live app, kept
  /// for provider-internal symmetry/tests).
  factory ProviderTrack.fromTrackMap(
    Map<String, dynamic> map, {
    ProviderId providerId = ProviderId.youtube,
  }) {
    return ProviderTrack(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      artist: (map['artist'] as String?) ?? '',
      artworkUrl: (map['artwork'] as String?) ?? '',
      durationSeconds: map['duration'] is int ? map['duration'] as int : 0,
      providerId: providerId,
      isOfficial: map['isOfficial'] == true,
      channelId: map['channelId'] as String?,
      viewCount: map['views'] is int ? map['views'] as int : null,
      publishedDaysAgo: map['ageDays'] is int ? map['ageDays'] as int : null,
    );
  }
}

/// One line of time-synced (or plain) lyrics — mirrors
/// `core/lyrics/lyrics_service.dart`'s existing `LyricLine`/
/// `LyricsResult` shape closely enough to convert without loss, but
/// kept as its own type here so `music_provider.dart`'s interface
/// doesn't need to import the lyrics feature's file directly (keeps
/// the provider layer's dependency direction one-way: providers know
/// about core services, core services don't need to know about the
/// provider layer).
class ProviderLyrics {
  const ProviderLyrics({
    this.plainText,
    this.hasSynced = false,
    this.instrumental = false,
  });

  final String? plainText;
  final bool hasSynced;
  final bool instrumental;

  bool get hasAny => plainText != null || hasSynced || instrumental;

  static const notFound = ProviderLyrics();
}

/// One page of paginated search results — the unified shape both the
/// InnerTube provider (continuation tokens) and the YouTube Data API
/// provider (pageToken) return through the shared provider interface,
/// so Search / Discovery can page through results provider-agnostically.
class ProviderSearchPage {
  const ProviderSearchPage({required this.tracks, this.nextPageToken});

  final List<ProviderTrack> tracks;
  final String? nextPageToken;
}

/// Health-check result for a provider — used by [ProviderManager] to
/// decide whether a provider is currently usable. Kept deliberately
/// simple (bool + optional message) — this is NOT a full metrics/SLA
/// system (that would be over-engineering for a single-provider,
/// personal-hobby app; see PROVIDER_ARCHITECTURE.md's `ProviderMetrics`
/// row, which remains an unimplemented future idea, not something this
/// task claims to have built).
class ProviderHealth {
  const ProviderHealth({required this.healthy, this.message});
  final bool healthy;
  final String? message;
}
