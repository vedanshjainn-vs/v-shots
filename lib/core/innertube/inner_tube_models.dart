// ═════════════════════════════════════════════════════════════════════════════
// V Shots — InnerTube models (discovery metadata only)
// ═════════════════════════════════════════════════════════════════════════════
//
// Plain data classes for InnerTube discovery results. InnerTube is used
// strictly for METADATA (search / related / browse), never for stream
// extraction — playback always goes through the official YouTube IFrame
// player (see main.dart's ensureGlobalPlayer).
// ═════════════════════════════════════════════════════════════════════════════

/// One video result from an InnerTube response.
class InnerTubeVideoItem {
  const InnerTubeVideoItem({
    required this.videoId,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    required this.durationSeconds,
    this.viewCount = 0,
    this.isOfficial = false,
    this.channelId,
  });

  final String videoId;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final int durationSeconds;
  final int viewCount;

  /// True when the uploader carries a YouTube official/verified badge
  /// (OFFICIAL_ARTIST_BADGE / BADGE_STYLE_TYPE_VERIFIED…). Used to prefer
  /// original artist uploads over fan/lyrics channels.
  final bool isOfficial;

  /// Uploader channel id (YouTube `UC…`) when available, else null.
  final String? channelId;
}

/// One page of InnerTube search results plus an optional continuation token
/// for the next page (real pagination, mirrors the Data API's pageToken).
class InnerTubePage {
  const InnerTubePage({required this.items, this.continuationToken});

  const InnerTubePage.empty()
      : items = const [],
        continuationToken = null;

  final List<InnerTubeVideoItem> items;
  final String? continuationToken;
}
