// ════════════════════════════════════════════════
// V Shots — YouTube provider: Video -> ProviderTrack mapping/filtering
// ════════════════════════════════════════════════
//
// Consolidates filtering logic that previously existed as THREE
// separate, near-identical copies:
//   - HomeScreen._search() in main.dart
//   - SearchScreen._search() in main.dart
//   - ForYouFeedService.fetchNextBatch() in for_you_feed_service.dart
// All three filtered out podcasts/compilations and over-long videos,
// with slightly different duration caps (15 min for Home/Search, 12
// min + a 1-min floor for the For You feed) and slightly different
// title-cleaning (see shared/utils/text_utils.dart's file header for
// the cleanTitle() duplication this also fixes). This file is the one
// place that logic now lives — YouTubeMusicProvider.search()/
// getTrending()/getRecommendations() all call into this.
// ════════════════════════════════════════════════

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../../shared/utils/text_utils.dart';
import '../../provider_models.dart';

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
  /// than a podcast/compilation/etc. [maxMinutes]/[minMinutes] let
  /// call sites keep their own existing thresholds (Home/Search used
  /// 15 min max with no floor; the For You feed used 12 min max with a
  /// 1 min floor) rather than silently changing behavior that was
  /// already tuned per-surface.
  bool isPlayableMusic(Video video, {int maxMinutes = 15, int minMinutes = 0}) {
    final title = video.title.toLowerCase();
    final durationMinutes = video.duration?.inMinutes ?? 0;
    if (durationMinutes > maxMinutes) return false;
    if (minMinutes > 0 && durationMinutes < minMinutes) return false;
    if (_nonMusicKeywords.any(title.contains)) return false;
    return true;
  }

  ProviderTrack toProviderTrack(Video video) {
    return ProviderTrack(
      id: video.id.value,
      title: cleanTitle(video.title, video.author),
      artist: video.author,
      artworkUrl: video.thumbnails.highResUrl.toString(),
      durationSeconds: video.duration?.inSeconds ?? 0,
    );
  }

  /// Filters + maps a raw YouTube search result list in one pass —
  /// the exact sequence every existing call site already performed
  /// inline (whereType<Video> -> where(isPlayableMusic) -> take(limit)
  /// -> map(toProviderTrack)).
  List<ProviderTrack> mapSearchResults(
    List<dynamic> rawResults, {
    required int limit,
    int maxMinutes = 15,
    int minMinutes = 0,
    Set<String> excludeIds = const {},
  }) {
    return rawResults
        .whereType<Video>()
        .where((v) => !excludeIds.contains(v.id.value))
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
