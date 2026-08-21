// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music shelf builder (dynamic, never-empty shelves)
// ═════════════════════════════════════════════════════════════════════════════
//
// Builds the ordered Home shelf list from candidate pools, HIDING any shelf
// that falls below the minimum item count (no fabricated fillers).
// ═════════════════════════════════════════════════════════════════════════════

import 'music_candidate.dart';
import 'music_shelf.dart';

class MusicShelfBuilder {
  const MusicShelfBuilder({this.minHorizontalShelf = 5});

  final int minHorizontalShelf;

  /// Builds shelves from a map of type → candidates (already ranked/
  /// diversified per shelf). Only shelves with enough items survive.
  List<MusicShelf> build(Map<HomeShelfType, List<MusicCandidate>> pools) {
    final order = <HomeShelfType>[
      HomeShelfType.forYou,
      HomeShelfType.continueListening,
      HomeShelfType.quickMix,
      HomeShelfType.trending,
      HomeShelfType.newReleases,
      HomeShelfType.becauseYouListened,
      HomeShelfType.favoriteArtists,
      HomeShelfType.freshDiscoveries,
      HomeShelfType.moods,
      HomeShelfType.regional,
      HomeShelfType.international,
      HomeShelfType.popular,
    ];

    final shelves = <MusicShelf>[];
    for (final type in order) {
      final items = pools[type] ?? const [];
      if (items.length < minHorizontalShelf) continue; // hide — never fabricate
      shelves.add(
        MusicShelf(
          type: type,
          title: _titleFor(type),
          subtitle: _subtitleFor(type),
          items: items,
        ),
      );
    }
    return shelves;
  }

  static String _titleFor(HomeShelfType type) => switch (type) {
    HomeShelfType.forYou => 'Made For You',
    HomeShelfType.continueListening => 'Continue Listening',
    HomeShelfType.quickMix => 'Quick Mix',
    HomeShelfType.trending => 'Trending Music',
    HomeShelfType.newReleases => 'New Releases',
    HomeShelfType.becauseYouListened => 'Because You Listened',
    HomeShelfType.favoriteArtists => 'From Your Favorite Artists',
    HomeShelfType.freshDiscoveries => 'Fresh Discoveries',
    HomeShelfType.moods => 'Mood',
    HomeShelfType.regional => 'Regional',
    HomeShelfType.international => 'International',
    HomeShelfType.popular => 'Popular',
  };

  static String? _subtitleFor(HomeShelfType type) => switch (type) {
    HomeShelfType.forYou => 'Personalized from your listening',
    HomeShelfType.trending => 'What the world is playing now',
    HomeShelfType.newReleases => 'Fresh official releases',
    _ => null,
  };
}
