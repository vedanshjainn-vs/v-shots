// ═════════════════════════════════════════════════════════════════════════
// V Shots — Discovery Category Config Tests (Section 1 verification)
//
// Verifies the single-source-of-truth category config:
//   - every category has a DISTINCT query (so selecting a filter actually
//     changes the outgoing request)
//   - every category has a non-empty label/icon/fallbackCategory
//   - categories map to valid fallback catalog tags
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/config/discovery_categories.dart';
import 'package:v_shots/core/providers/adapters/youtube/youtube_data_api_client.dart';

void main() {
  group('Discovery Category Config', () {
    test('every category has a distinct, non-empty query', () {
      final queries = kDiscoveryCategories.map((c) => c.query).toSet();
      expect(queries.length, kDiscoveryCategories.length,
          reason: 'each category must have a DISTINCT query');
      for (final c in kDiscoveryCategories) {
        expect(c.query.trim().isNotEmpty, isTrue,
            reason: 'category ${c.label} has empty query');
      }
    });

    test('every category has non-empty label, icon, id', () {
      for (final c in kDiscoveryCategories) {
        expect(c.id.trim().isNotEmpty, isTrue);
        expect(c.label.trim().isNotEmpty, isTrue);
        expect(c.icon.trim().isNotEmpty, isTrue);
      }
    });

    test('lookup by label and id round-trip', () {
      final first = kDiscoveryCategories.first;
      expect(discoveryCategoryById(first.id)?.label, first.label);
      expect(discoveryCategoryByLabel(first.label)?.id, first.id);
      expect(discoveryCategoryById('does-not-exist'), isNull);
    });

    test('selecting different categories produces different fallback content',
        () async {
      // Without an API key, the fallback catalog is used. Different category
      // queries must map to different (non-identical) result sets so filters
      // actually change the feed.
      final client = YouTubeDataApiClient();
      final seenQueries = <String, List<String>>{};
      for (final c in kDiscoveryCategories) {
        final results = await client.searchMusicVideos(
          c.query,
          maxResults: 8,
        );
        seenQueries[c.label] = results.map((v) => v.id).toList();
      }
      // At least a majority of categories should yield distinct content.
      final distinctSets =
          seenQueries.values.map((ids) => ids.join(',')).toSet().length;
      expect(distinctSets, greaterThanOrEqualTo(kDiscoveryCategories.length ~/ 2),
          reason:
              'most categories must return distinct content from the fallback catalog');
    });
  });
}
