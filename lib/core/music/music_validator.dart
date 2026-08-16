// ═════════════════════════════════════════════════════════════════════════════
// V Shots — MusicContentValidator
// ═════════════════════════════════════════════════════════════════════════════
//
// The hard boundary between "random YouTube video" and "music item". Every
// track that reaches the primary Home/Discovery feed must pass this.
//
//   • STRONG non-music signals (gaming / news / sports / podcast / reaction /
//     tutorial / vlog / meme / comedy / interview / explanation …) REJECT the
//     item outright (reuse the shared discovery_relevance keyword set).
//   • Otherwise a deterministic confidence score is computed from real
//     signals: official/verified badge, artist presence, plausible song
//     duration, sane title, absence of unofficial-upload signals.
//   • Items below the threshold are rejected (no generic fallback).
//
// Not fabricated: confidence only reflects metadata we actually have.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

import '../innertube/discovery_relevance.dart';
import 'music_canonicalizer.dart';
import 'music_models.dart';

class MusicContentValidator {
  const MusicContentValidator();

  /// Confidence below which an item is not considered music.
  static const double threshold = 0.35;

  /// Unofficial-upload signals — music-ish but not a canonical release.
  static const _unofficial = [
    'lyrics',
    'lyrical',
    'karaoke',
    'slowed',
    'reverb',
    'nightcore',
    'mashup',
    'status video',
    'whatsapp status',
    'full screen status',
    'sped up',
    'edit audio',
    'cover song',
  ];

  MusicValidationResult validate(Map<String, dynamic> track) {
    final title = (track['title'] as String?) ?? '';
    final artist = (track['artist'] as String?) ?? '';
    final duration = track['duration'] as int? ?? 0;
    final isOfficial = track['isOfficial'] == true;

    // STRONG non-music rejection (shared keyword set).
    if (isIrrelevantContent(title, artist)) {
      return const MusicValidationResult(
        isMusic: false,
        confidence: 0.02,
        reasons: ['NON_MUSIC_CREATOR'],
        rejectionReason: 'NON_MUSIC_CREATOR',
      );
    }

    final lowerTitle = title.toLowerCase();
    var confidence = 0.25;

    final reasons = <String>[];
    if (isOfficial) {
      confidence += 0.35;
      reasons.add('OFFICIAL_VERIFIED');
    }
    if (artist.isNotEmpty && artist.toLowerCase() != 'unknown artist') {
      confidence += 0.12;
      reasons.add('ARTIST_PRESENT');
    }
    if (duration >= 45 && duration <= 900) {
      confidence += 0.10;
      reasons.add('SONG_DURATION');
    }
    if (title.length >= 2 && title.length <= 110) {
      confidence += 0.08;
      reasons.add('TITLE_OK');
    }
    final unofficialHits = _unofficial.where(lowerTitle.contains).toList();
    if (unofficialHits.isNotEmpty) {
      confidence -= 0.12 * unofficialHits.length;
      reasons.add('UNOFFICIAL_SIGNAL');
    }

    confidence = confidence.clamp(0.0, 1.0);
    if (confidence >= threshold) {
      return MusicValidationResult(
        isMusic: true,
        confidence: confidence,
        reasons: reasons,
      );
    }
    return MusicValidationResult(
      isMusic: false,
      confidence: confidence,
      reasons: reasons,
      rejectionReason: 'LOW_MUSIC_CONFIDENCE',
    );
  }
}

/// Validates, logs rejections, and returns ONLY the music items from [tracks].
/// Also canonical-deduplicates (same song → one representation). Used by Home
/// and Discovery as the single safety gate. Never fabricates content.
List<Map<String, dynamic>> validateAndFilterMusic(
  List<Map<String, dynamic>> tracks, {
  String label = '',
}) {
  const validator = MusicContentValidator();
  final kept = <Map<String, dynamic>>[];
  for (final track in tracks) {
    final result = validator.validate(track);
    if (!result.isMusic) {
      debugPrint(
        '[MusicValidator] REJECTED "${track['title']}" '
        'reason=${result.rejectionReason ?? "unknown"} '
        'confidence=${result.confidence.toStringAsFixed(2)}',
      );
      continue;
    }
    kept.add(track);
  }
  return deduplicateMusicItems(kept);
}
