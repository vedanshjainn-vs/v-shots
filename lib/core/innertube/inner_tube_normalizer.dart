// ═════════════════════════════════════════════════════════════════════════════
// V Shots — InnerTube normalizer
// ═════════════════════════════════════════════════════════════════════════════
//
// InnerTube → Normalizer → Recommendation Engine → Home / Discovery / Search.
//
// Maps raw InnerTube video items into the app's unified `ProviderTrack`
// shape and applies a quality filter so every provider produces a clean,
// playable, ORIGINAL-artist-first music surface. One videoId identity flows
// through the whole pipeline.
//
// Content policy:
//   • Official/verified uploads (OFFICIAL_ARTIST_BADGE, VERIFIED…) are
//     surfaced FIRST, so results favour real artist/label uploads over
//     fan and lyrics channels.
//   • Clearly non-music (podcast / interview / reaction / tutorial) and
//     strong unofficial-upload signals (lyrics / karaoke / slowed / reverb /
//     mashup / status) are dropped in the strict pass.
//   • If the strict pass leaves nothing, a RELAXED pass still returns
//     content (only non-music + duration excluded) so a shelf never appears
//     empty just because a query's results were dominated by unofficial
//     uploads.
// ═════════════════════════════════════════════════════════════════════════════

import '../../shared/utils/text_utils.dart';
import '../providers/provider_models.dart';
import 'inner_tube_models.dart';

class InnerTubeNormalizer {
  const InnerTubeNormalizer();

  /// Clearly non-music — filtered in BOTH passes.
  static const _nonMusicKeywords = [
    'podcast',
    'interview',
    'reaction',
    'tutorial',
  ];

  /// Strong "unofficial upload" signals — filtered in the STRICT pass only
  /// (a lyrics/status/slowed upload is almost never the original song).
  static const _unofficialKeywords = [
    'lyrics',
    'lyrical',
    'karaoke',
    'slowed',
    'reverb',
    'mashup',
    'whatsapp status',
    'status video',
    'full screen status',
  ];

  bool _isNonMusic(String title) => _nonMusicKeywords.any(title.contains);

  bool _isUnofficial(String title) => _unofficialKeywords.any(title.contains);

  bool _withinDuration(
    InnerTubeVideoItem item, {
    required int maxMinutes,
    required int minMinutes,
  }) {
    final durationMinutes = item.durationSeconds / 60.0;
    if (durationMinutes > maxMinutes) return false;
    if (minMinutes > 0 && durationMinutes < minMinutes) return false;
    return true;
  }

  /// Strict playability: non-music, unofficial uploads, and duration caps.
  bool isPlayableMusic(
    InnerTubeVideoItem item, {
    int maxMinutes = 15,
    int minMinutes = 0,
  }) {
    final title = item.title.toLowerCase();
    if (_isNonMusic(title)) return false;
    if (_isUnofficial(title)) return false;
    return _withinDuration(
      item,
      maxMinutes: maxMinutes,
      minMinutes: minMinutes,
    );
  }

  /// Relaxed playability: only non-music + duration caps (used as a fallback
  /// so a shelf is never empty when a query is dominated by unofficial
  /// uploads).
  bool _isPlayableRelaxed(
    InnerTubeVideoItem item, {
    int maxMinutes = 15,
    int minMinutes = 0,
  }) {
    final title = item.title.toLowerCase();
    if (_isNonMusic(title)) return false;
    return _withinDuration(
      item,
      maxMinutes: maxMinutes,
      minMinutes: minMinutes,
    );
  }

  ProviderTrack toProviderTrack(InnerTubeVideoItem item) {
    return ProviderTrack(
      id: item.videoId,
      title: cleanTitle(item.title, item.channelName),
      artist: item.channelName.isEmpty ? 'Unknown Artist' : item.channelName,
      artworkUrl: item.thumbnailUrl,
      durationSeconds: item.durationSeconds,
      isOfficial: item.isOfficial,
      channelId: item.channelId,
    );
  }

  /// Filters + maps a batch of InnerTube items in one pass, official-first.
  List<ProviderTrack> mapSearchResults(
    List<InnerTubeVideoItem> items, {
    required int limit,
    int maxMinutes = 15,
    int minMinutes = 0,
    Set<String> excludeIds = const {},
  }) {
    // De-duplicate by id first, preserving first-seen order.
    final seen = <String>{...excludeIds};
    final unique = <InnerTubeVideoItem>[];
    for (final item in items) {
      if (seen.add(item.videoId)) unique.add(item);
    }
    if (unique.isEmpty) return const [];

    // Official/verified uploads first (stable partition), then the rest.
    final official = <InnerTubeVideoItem>[];
    final rest = <InnerTubeVideoItem>[];
    for (final item in unique) {
      (item.isOfficial ? official : rest).add(item);
    }
    final ordered = <InnerTubeVideoItem>[...official, ...rest];

    final strict = _select(
      ordered,
      strict: true,
      limit: limit,
      maxMinutes: maxMinutes,
      minMinutes: minMinutes,
    );
    if (strict.isNotEmpty) return strict;

    // Relaxed fallback: only non-music + duration, so shelves never go empty.
    return _select(
      ordered,
      strict: false,
      limit: limit,
      maxMinutes: maxMinutes,
      minMinutes: minMinutes,
    );
  }

  List<ProviderTrack> _select(
    List<InnerTubeVideoItem> items, {
    required bool strict,
    required int limit,
    required int maxMinutes,
    required int minMinutes,
  }) {
    final result = <ProviderTrack>[];
    for (final item in items) {
      final ok = strict
          ? isPlayableMusic(
              item,
              maxMinutes: maxMinutes,
              minMinutes: minMinutes,
            )
          : _isPlayableRelaxed(
              item,
              maxMinutes: maxMinutes,
              minMinutes: minMinutes,
            );
      if (!ok) continue;
      result.add(toProviderTrack(item));
      if (result.length >= limit) break;
    }
    return result;
  }
}
