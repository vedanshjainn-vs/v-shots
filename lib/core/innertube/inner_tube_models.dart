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
  });

  final String videoId;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final int durationSeconds;
  final int viewCount;
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
