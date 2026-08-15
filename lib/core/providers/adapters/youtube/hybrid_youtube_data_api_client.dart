// V Shots — Hybrid YouTube discovery client
//
// InnerTube is used for live YouTube Music discovery/search metadata. The
// existing Data API client remains the resilience fallback for environments
// where InnerTube changes or blocks a request.

import 'youtube_data_api_client.dart';
import 'youtube_innertube_client.dart';

class HybridYouTubeDataApiClient extends YouTubeDataApiClient {
  HybridYouTubeDataApiClient({
    super.apiKey,
  }) : _innerTube = YouTubeInnerTubeClient();

  final YouTubeInnerTubeClient _innerTube;

  @override
  Future<List<YouTubeVideoItem>> searchMusicVideos(
    String query, {
    String order = 'relevance',
    int maxResults = 20,
    Set<String> excludeIds = const {},
  }) async {
    try {
      final live = await _innerTube.search(
        query,
        limit: maxResults.clamp(1, 50),
        excludeIds: excludeIds,
      );
      if (live.isNotEmpty) {
        return live
            .map(
              (item) => YouTubeVideoItem(
                id: item.id,
                title: item.title,
                channelTitle: item.artist,
                thumbnailUrl: item.thumbnailUrl,
                durationSeconds: item.durationSeconds,
                category: 'music',
              ),
            )
            .toList();
      }
    } catch (_) {
      // Fall through to the existing Data API/fallback catalog.
    }

    return super.searchMusicVideos(
      query,
      order: order,
      maxResults: maxResults,
      excludeIds: excludeIds,
    );
  }

  @override
  Future<PaginatedSearchResult> searchMusicVideosPaginated(
    String query, {
    String order = 'relevance',
    int maxResults = 20,
    Set<String> excludeIds = const {},
    String? pageToken,
  }) async {
    // InnerTube currently has no dependency on Data-API page tokens in this
    // app. For the first page we use the live Music search; continuation is
    // intentionally disabled so the UI stops cleanly instead of pretending a
    // token exists. The base client remains the fallback.
    if (pageToken == null || pageToken.isEmpty) {
      try {
        final live = await _innerTube.search(
          query,
          limit: maxResults.clamp(1, 50),
          excludeIds: excludeIds,
        );
        if (live.isNotEmpty) {
          return PaginatedSearchResult(
            items: live
                .map(
                  (item) => YouTubeVideoItem(
                    id: item.id,
                    title: item.title,
                    channelTitle: item.artist,
                    thumbnailUrl: item.thumbnailUrl,
                    durationSeconds: item.durationSeconds,
                    category: 'music',
                  ),
                )
                .toList(),
            nextPageToken: null,
          );
        }
      } catch (_) {
        // Fall through to Data API.
      }
    }

    return super.searchMusicVideosPaginated(
      query,
      order: order,
      maxResults: maxResults,
      excludeIds: excludeIds,
      pageToken: pageToken,
    );
  }

  @override
  void dispose() {
    _innerTube.dispose();
    super.dispose();
  }
}