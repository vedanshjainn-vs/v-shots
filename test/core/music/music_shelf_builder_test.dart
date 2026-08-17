// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music shelf builder tests (hide under-minimum shelves)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/music/music_candidate.dart';
import 'package:v_shots/core/music/music_shelf.dart';
import 'package:v_shots/core/music/music_shelf_builder.dart';
import 'package:v_shots/core/providers/provider_models.dart';

List<MusicCandidate> _items(int n, String artist) => List.generate(
      n,
      (i) => MusicCandidate(
        track: ProviderTrack(
          id: '$artist-$i',
          title: '$artist Song $i',
          artist: artist,
          artworkUrl: '',
          durationSeconds: 200,
        ),
        songId: '$artist-$i',
        source: 'trending',
        artist: artist,
      ),
    );

void main() {
  const builder = MusicShelfBuilder();

  test('hides shelves below the minimum item count', () {
    final pools = <HomeShelfType, List<MusicCandidate>>{
      HomeShelfType.trending: _items(4, 'A'), // too few → hidden
      HomeShelfType.newReleases: _items(6, 'B'), // enough → kept
    };
    final shelves = builder.build(pools);
    expect(shelves.map((s) => s.type), isNot(contains(HomeShelfType.trending)));
    expect(shelves.map((s) => s.type), contains(HomeShelfType.newReleases));
  });

  test('preserves the recommended shelf order', () {
    final pools = <HomeShelfType, List<MusicCandidate>>{
      HomeShelfType.popular: _items(5, 'P'),
      HomeShelfType.forYou: _items(5, 'F'),
      HomeShelfType.trending: _items(5, 'T'),
    };
    final shelves = builder.build(pools);
    final order = shelves.map((s) => s.type).toList();
    expect(order.indexOf(HomeShelfType.forYou),
        lessThan(order.indexOf(HomeShelfType.popular)));
  });

  test('never fabricates items to fill an empty pool', () {
    final shelves = builder.build({HomeShelfType.trending: const []});
    expect(shelves, isEmpty);
  });
}
