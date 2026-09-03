// -----------------------------------------------------------------------------
// V Shots - MusicCatalogService
// (ingest -> validate -> canonicalize -> dedupe)
// -----------------------------------------------------------------------------
//
// The single funnel through which raw provider results become MUSIC for the
// UI. Never lets raw API results reach the UI directly.
//
// API -> Normalizer -> Validator -> Canonicalizer
// -> Catalog -> Ranker -> UI
//
// Also produces per-ingest diagnostics (accepted/rejected/duplicates/variant
// distribution) so the validator can be tuned against real data.
// -----------------------------------------------------------------------------

import 'package:flutter/foundation.dart';

import 'music_canonicalizer.dart';
import 'music_models.dart';
import 'music_validator.dart';

class MusicCatalogResult {
  const MusicCatalogResult({
    required this.items,
    this.accepted = 0,
    this.rejected = 0,
    this.duplicates = 0,
    this.variants = const {},
  });

  final List<Map<String, dynamic>> items;
  final int accepted;
  final int rejected;
  final int duplicates;
  final Map<MusicVariantType, int> variants;
}

class MusicCatalogService {
  const MusicCatalogService();

  static const _validator = MusicContentValidator();

  // Home/Discovery are recommendation surfaces. For these surfaces we only
  // accept the real isOfficial signal produced by the provider normalizer.
  // Search and unrelated catalog consumers remain unchanged.
  static bool _officialOnlySurface(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized == '.discover' ||
        normalized.startsWith('.discover.')) {
      return true;
    }
    const homeIds = <String>{
      '.mfy',
      '.made_for_you',
      '.byld',
      '.because_listened',
      '.because_you_listened',
      '.tfy',
      '.trending',
      '.trending_now',
      '.new',
      '.new_releases',
      '.official',
      '.official_music',
      '.discover_something_new',
      '.bollywood',
      '.punjabi',
      '.global',
      '.lofi',
      '.hiphop',
      '.romantic',
      '.classics',
    };
    return homeIds.contains(normalized);
  }

  /// Ingests raw provider results: validates, canonical-deduplicates, and
  /// returns the accepted music items + diagnostics. Never fabricates.
  MusicCatalogResult ingest(
    List<Map<String, dynamic>> tracks, {
    String label = '',
  }) {
    final accepted = <Map<String, dynamic>>[];
    var rejected = 0;
    var duplicates = 0;
    final variants = <MusicVariantType, int>{};
    final officialOnly = _officialOnlySurface(label);

    final rawUnique = <String, Map<String, dynamic>>{};
    for (final track in tracks) {
      final id = (track['id'] as String?) ?? '';
      if (id.isNotEmpty && rawUnique.containsKey(id)) {
        duplicates++;
        continue;
      }
      rawUnique[id] = track;
    }

    for (final track in rawUnique.values) {
      if (officialOnly && track['isOfficial'] != true) {
        rejected++;
        debugPrint(
          '[MusicCatalog$label] REJECTED "${track['title']}" '
          'reason=NON_OFFICIAL_SOURCE',
        );
        continue;
      }
      final result = _validator.validate(track);
      if (!result.isMusic) {
        rejected++;
        debugPrint(
          '[MusicCatalog$label] REJECTED "${track['title']}" '
          'reason=${result.rejectionReason ?? 'unknown'} '
          'confidence=${result.confidence.toStringAsFixed(2)}',
        );
        continue;
      }
      variants[result.variant] = (variants[result.variant] ?? 0) + 1;
      accepted.add(track);
    }

    final canonical = deduplicateMusicItems(accepted);
    duplicates += accepted.length - canonical.length;

    if (accepted.isNotEmpty || rejected > 0) {
      debugPrint(
        '[MusicCatalog$label] accepted=${canonical.length} '
        'rejected=$rejected duplicates=$duplicates '
        'variants=${variants.toString()}',
      );
    }

    return MusicCatalogResult(
      items: canonical,
      accepted: canonical.length,
      rejected: rejected,
      duplicates: duplicates,
      variants: variants,
    );
  }
}

String musicCatalogCacheKey({
  required String mode,
  List<String> languages = const [],
  List<String> moods = const [],
  List<String> regions = const [],
  int signalVersion = 1,
}) {
  final parts = <String>[
    mode,
    if (languages.isNotEmpty) languages.join('+'),
    if (moods.isNotEmpty) moods.join('+'),
    if (regions.isNotEmpty) regions.join('+'),
    'v$signalVersion',
  ];
  return parts.join('|');
}
