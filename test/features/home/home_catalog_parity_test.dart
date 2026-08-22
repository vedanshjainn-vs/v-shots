// ─────────────────────────────────────────────────────────────────────────────
// V Shots — Home catalog parity tests (PHASE 10)
// Every category in the COMPILED default Home must be representable as a CMS
// row with the same semantic behavior (kind), and personalized categories
// must never degrade into literal YouTube searches.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/features/home/home_feed_service.dart';

/// Stable CMS keys used by the production seed
/// (supabase/migrations/20260821000006_home_catalog_parity.sql) and the
/// Admin panel. This test fails if the app-side key map drifts.
const Map<String, HomeShelfKind> cmsKeyToKind = {
  'trending_now': HomeShelfKind.catalog,
  'new_releases': HomeShelfKind.catalog,
  'made_for_you': HomeShelfKind.madeForYou,
  'because_listened': HomeShelfKind.becauseYouListenedTo,
  'india_hits': HomeShelfKind.catalog,
  'punjabi': HomeShelfKind.catalog,
  'hindi_indie': HomeShelfKind.catalog,
  'international': HomeShelfKind.catalog,
  'chill_lofi': HomeShelfKind.catalog,
  'trending_for_you': HomeShelfKind.trendingForYou,
  'artists_for_you': HomeShelfKind.artistsForYou,
  'official_music': HomeShelfKind.officialMusic,
  'discover_something_new': HomeShelfKind.discoverSomethingNew,
  'hiphop': HomeShelfKind.catalog,
  'romantic': HomeShelfKind.catalog,
  'classics': HomeShelfKind.catalog,
};

/// Compiled-default id → the CMS key that represents it in production.
const Map<String, String> compiledIdToCmsKey = {
  'mfy': 'made_for_you',
  'byld': 'because_listened',
  'trending': 'trending_now',
  'new': 'new_releases',
  'tfy': 'trending_for_you',
  'artists': 'artists_for_you',
  'official': 'official_music',
  'discover': 'discover_something_new',
  'bollywood': 'india_hits',
  'punjabi': 'punjabi',
  'global': 'international',
  'lofi': 'chill_lofi',
  'hiphop': 'hiphop',
  'romantic': 'romantic',
  'classics': 'classics',
  // 'continue' is intentionally NOT a CMS row — the app auto-inserts it.
};

List<Map<String, dynamic>> parityFixture() {
  var sort = 1;
  return cmsKeyToKind.keys.map((key) {
    final personalized = cmsKeyToKind[key] != HomeShelfKind.catalog &&
        cmsKeyToKind[key] != HomeShelfKind.manual;
    return {
      'id': key,
      'section_key': key,
      'title': key,
      'section_type': personalized ? 'personalized' : 'home_section',
      'source_type': personalized ? 'personalized' : 'youtube_search',
      // Deliberately wrong query for personalized keys — the key map must
      // win over any literal query (behavior preservation).
      'query': 'some literal youtube search that must be ignored',
      'source_value': 'some literal youtube search that must be ignored',
      'sort_order': sort++,
      'visible': true,
      'published': true,
      'max_items': 12,
    };
  }).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home catalog parity', () {
    test('compiled defaults expose the full authoritative category list', () {
      final shelves = HomeFeedService().buildShelfDescriptors(
        enableRemoteHome: false,
      );
      final ids = shelves.map((s) => s.id).toList();
      expect(
        ids,
        containsAll([
          'continue',
          'mfy',
          'byld',
          'trending',
          'new',
          'tfy',
          'artists',
          'official',
          'discover',
          'bollywood',
          'punjabi',
          'global',
          'lofi',
          'hiphop',
          'romantic',
          'classics',
        ]),
      );
      expect(shelves.first.kind, HomeShelfKind.continueListening);
    });

    test('every compiled category maps to a CMS key', () {
      expect(compiledIdToCmsKey.length, 15); // 16 shelves minus auto-continue
      for (final key in compiledIdToCmsKey.values) {
        expect(cmsKeyToKind.containsKey(key), isTrue,
            reason: 'CMS key $key missing from production map');
      }
    });

    test('CMS fixture keeps every category with its semantic kind', () {
      final shelves = HomeFeedService().buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: parityFixture(),
      );
      for (final entry in cmsKeyToKind.entries) {
        final shelf = shelves.where((s) => s.id == entry.key).toList();
        expect(shelf.length, 1, reason: '${entry.key} should render once');
        expect(
          shelf.single.kind,
          entry.value,
          reason: '${entry.key} kind drift',
        );
      }
      // Auto-inserted Continue at top.
      expect(shelves.first.kind, HomeShelfKind.continueListening);
    });

    test('personalized keys beat a literal query (never a YouTube search)', () {
      final shelves = HomeFeedService().buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: parityFixture(),
      );
      for (final entry in cmsKeyToKind.entries) {
        if (entry.value == HomeShelfKind.catalog) continue;
        final shelf = shelves.singleWhere((s) => s.id == entry.key);
        expect(
          shelf.kind,
          isNot(HomeShelfKind.catalog),
          reason: '${entry.key} must stay personalized',
        );
        expect(shelf.query, isNull,
            reason: '${entry.key} must not carry a literal query');
      }
    });

    test('CMS sort_order controls app order', () {
      final fixture = parityFixture();
      // Reverse the order.
      var n = fixture.length;
      for (final row in fixture) {
        row['sort_order'] = n--;
      }
      final shelves = HomeFeedService().buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: fixture,
      );
      // Continue is auto-inserted first; the rest follow the reversed order.
      final afterContinue = shelves.skip(1).map((s) => s.id).toList();
      final expected = cmsKeyToKind.keys.toList().reversed.toList();
      expect(afterContinue, expected);
    });

    test('visible=false and published=false both hide a category', () {
      final hiddenVisible = parityFixture();
      hiddenVisible.first['visible'] = false;
      final shelves1 = HomeFeedService().buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: hiddenVisible,
      );
      expect(
        shelves1.where((s) => s.id == cmsKeyToKind.keys.first).length,
        0,
      );

      final hiddenPublished = parityFixture();
      hiddenPublished.first['published'] = false;
      final shelves2 = HomeFeedService().buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: hiddenPublished,
      );
      expect(
        shelves2.where((s) => s.id == cmsKeyToKind.keys.first).length,
        0,
      );
    });

    test('CMS unavailable falls back to compiled defaults', () {
      // enableRemoteHome false + rows present → compiled defaults.
      final off = HomeFeedService().buildShelfDescriptors(
        enableRemoteHome: false,
        cmsSections: parityFixture(),
      );
      expect(off.any((s) => s.id == 'mfy'), isTrue);
      expect(off.any((s) => s.id == 'hiphop'), isTrue);

      // Remote enabled but zero rows → compiled defaults.
      final empty = HomeFeedService().buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: const [],
      );
      expect(empty.any((s) => s.id == 'mfy'), isTrue);
      expect(empty.any((s) => s.id == 'hiphop'), isTrue);
    });
  });
}
