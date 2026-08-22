import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/config/discovery_filters.dart';
import 'package:v_shots/core/config/discovery_remote.dart';

void main() {
  test('flag off uses compiled filters', () {
    final catalog = DiscoveryFilterCatalog.resolve(
      useRemote: false,
      rows: [
        {
          'id': 'remote_only',
          'name': 'Should not appear',
          'query': 'nope',
          'kind': 'source',
          'active': true,
        },
      ],
    );
    expect(catalog.sources, kDiscoverySources);
    expect(catalog.moods, kDiscoveryMoods);
  });

  test('empty remote falls back to compiled', () {
    final catalog = DiscoveryFilterCatalog.resolve(
      useRemote: true,
      rows: const [],
    );
    expect(catalog.sources.first.id, 'for_you');
    expect(catalog.moods, kDiscoveryMoods);
  });

  test('remote sources replace compiled when flag on', () {
    final catalog = DiscoveryFilterCatalog.resolve(
      useRemote: true,
      rows: [
        {
          'id': 'for_you',
          'name': 'For You',
          'emoji': '✨',
          'query': '',
          'kind': 'source',
          'sort_order': 0,
          'active': true,
        },
        {
          'id': 'punjabi',
          'name': 'Punjabi',
          'emoji': '🎸',
          'query': 'punjabi hits official',
          'kind': 'source',
          'ranking_order': 'viewCount',
          'sort_order': 1,
          'active': true,
        },
        {
          'id': 'romantic',
          'name': 'Romantic',
          'emoji': '❤️',
          'query': 'romantic',
          'kind': 'mood',
          'sort_order': 2,
          'active': true,
        },
      ],
    );
    expect(catalog.sources.map((s) => s.id), ['for_you', 'punjabi']);
    expect(catalog.sources.last.order, 'viewCount');
    expect(catalog.moods.single.id, 'romantic');
  });

  test('inactive / hidden rows are skipped', () {
    final catalog = DiscoveryFilterCatalog.fromRows([
      {
        'id': 'hidden',
        'name': 'Hidden',
        'query': 'x',
        'kind': 'source',
        'active': false,
      },
      {
        'id': 'invisible',
        'name': 'Invisible',
        'query': 'y',
        'kind': 'source',
        'visible': false,
      },
    ]);
    expect(catalog.sources.any((s) => s.id == 'hidden'), isFalse);
    expect(catalog.sources.any((s) => s.id == 'invisible'), isFalse);
    expect(catalog.sources.first.id, 'for_you');
  });

  test('malformed rows do not throw', () {
    final catalog = DiscoveryFilterCatalog.fromRows([
      {'id': 1, 'name': null, 'kind': 'mood'},
      {},
    ]);
    expect(catalog.sources, isNotEmpty);
  });
}
