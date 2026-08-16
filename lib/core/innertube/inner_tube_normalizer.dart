// ═════════════════════════════════════════════════════════════════════════════
// V Shots — InnerTube normalizer
// ═════════════════════════════════════════════════════════════════════════════
//
// InnerTube → Normalizer → Recommendation Engine → Home / Discovery / Search.
//
// Maps raw InnerTube video items into the app's unified `ProviderTrack`
// shape and applies the same quality filter the Data API provider uses
// (podcast/compilation/etc. exclusion + duration caps), so every provider
// produces the same clean, playable music surface. One videoId identity
// flows through the whole pipeline.
// ═════════════════════════════════════════════════════════════════════════════

import '../../shared/utils/text_utils.dart';
import '../providers/provider_models.dart';
import 'inner_tube_models.dart';

class InnerTubeNormalizer {
  const InnerTubeNormalizer();

  static const _nonMusicKeywords = [
    'podcast',
    'compilation',
    'interview',
    'reaction',
    'tutorial',
    'jukebox',
    'full album',
    'mixtape',
  ];

  /// True if [item] looks like a real, playable music track rather than a
  /// podcast / compilation / multi-hour jukebox.
  bool isPlayableMusic(
    InnerTubeVideoItem item, {
    int maxMinutes = 15,
    int minMinutes = 0,
  }) {
    final title = item.title.toLowerCase();
    final durationMinutes = item.durationSeconds / 60.0;
    if (durationMinutes > maxMinutes) return false;
    if (minMinutes > 0 && durationMinutes < minMinutes) return false;
    if (_nonMusicKeywords.any(title.contains)) return false;
    return true;
  }

  ProviderTrack toProviderTrack(InnerTubeVideoItem item) {
    return ProviderTrack(
      id: item.videoId,
      title: cleanTitle(item.title, item.channelName),
      artist: item.channelName.isEmpty ? 'Unknown Artist' : item.channelName,
      artworkUrl: item.thumbnailUrl,
      durationSeconds: item.durationSeconds,
    );
  }

  /// Filters + maps a batch of InnerTube items in one pass.
  List<ProviderTrack> mapSearchResults(
    List<InnerTubeVideoItem> items, {
    required int limit,
    int maxMinutes = 15,
    int minMinutes = 0,
    Set<String> excludeIds = const {},
  }) {
    final result = <ProviderTrack>[];
    final seen = <String>{...excludeIds};
    for (final item in items) {
      if (!seen.add(item.videoId)) continue;
      if (!isPlayableMusic(
        item,
        maxMinutes: maxMinutes,
        minMinutes: minMinutes,
      )) {
        continue;
      }
      result.add(toProviderTrack(item));
      if (result.length >= limit) break;
    }
    return result;
  }
}
