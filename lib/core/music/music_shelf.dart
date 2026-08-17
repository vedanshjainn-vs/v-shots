// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music shelf model
// ═════════════════════════════════════════════════════════════════════════════

import 'music_candidate.dart';

enum HomeShelfType {
  forYou,
  continueListening,
  quickMix,
  trending,
  newReleases,
  becauseYouListened,
  favoriteArtists,
  freshDiscoveries,
  moods,
  regional,
  international,
  popular,
}

class MusicShelf {
  const MusicShelf({
    required this.type,
    required this.title,
    required this.items,
    this.subtitle,
  });

  final HomeShelfType type;
  final String title;
  final String? subtitle;
  final List<MusicCandidate> items;

  /// Empty shelves must never be rendered (see MusicShelfBuilder minimums).
  bool get isEmpty => items.isEmpty;
}
