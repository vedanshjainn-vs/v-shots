// ═════════════════════════════════════════════════════════════════════════════
// V Shots — YouTube provider: Video -> ProviderTrack mapping/filtering
// ═════════════════════════════════════════════════════════════════════════════
//
// Maps YouTube Data API v3 results into clean, unified `ProviderTrack` models.
// Filters out non-music content and applies length caps/floors.
// ═════════════════════════════════════════════════════════════════════════════

import '../../../../shared/utils/text_utils.dart';
import '../../provider_models.dart';
import 'youtube_data_api_client.dart';

class YoutubeMusicMapper {
  const YoutubeMusicMapper();

  static const _nonMusicKeywords = [
    'podcast',
    'compilation',
    'interview',
    'reaction',
    'tutorial',
  ];

  /// True if [video] looks like a real, playable music track rather
  /// than a podcast/compilation/etc.
  bool isPlayableMusic(
    YouTubeVideoItem video, {
    int maxMinutes = 15,
    int minMinutes = 0,
  }) {
    final title = video.title.toLowerCase();
    final durationMinutes = video.durationSeconds / 60.0;
    if (durationMinutes > maxMinutes) return false;
    if (minMinutes > 0 && durationMinutes < minMinutes) return false;
    if (_nonMusicKeywords.any(title.contains)) return false;
    return true;
  }

  ProviderTrack toProviderTrack(YouTubeVideoItem video) {
    return ProviderTrack(
      id: video.id,
      title: cleanTitle(video.title, video.channelTitle),
      artist: video.channelTitle,
      artworkUrl: video.thumbnailUrl,
      durationSeconds: video.durationSeconds,
      // The Data API search snippet has no official/verified badge signal,
      // so we stay honest: unknown → false/null (never guessed).
      isOfficial: false,
      channelId: null,
    );
  }

  /// Filters + maps raw YouTube search results in one pass.
  List<ProviderTrack> mapSearchResults(
    List<dynamic> rawResults, {
    required int limit,
    int maxMinutes = 15,
    int minMinutes = 0,
    Set<String> excludeIds = const {},
  }) {
    return rawResults
        .whereType<YouTubeVideoItem>()
        .where((v) => !excludeIds.contains(v.id))
        .where(
          (v) => isPlayableMusic(
            v,
            maxMinutes: maxMinutes,
            minMinutes: minMinutes,
          ),
        )
        .take(limit)
        .map(toProviderTrack)
        .toList();
  }
}
