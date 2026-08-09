// ════════════════════════════════════════════════
// V Shots — Home Content Models
// ════════════════════════════════════════════════
//
// Clean separation of content from UI.
// ════════════════════════════════════════════════

/// Section types for the home feed.
enum HomeSectionType {
  trending,
  newReleases,
  topIndia,
  globalHits,
  mood,
  artists,
  albums,
  recentlyPlayed,
  recommendations,
}

/// A section in the home feed.
class HomeSection {
  final HomeSectionType type;
  final String title;
  final String? subtitle;
  final List<HomeItem> items;

  const HomeSection({
    required this.type,
    required this.title,
    this.subtitle,
    this.items = const [],
  });
}

/// An item in a home section.
class HomeItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? artwork;
  final int? durationSeconds;
  final String type; // track, album, artist, playlist
  final Map<String, dynamic> metadata;

  const HomeItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.artwork,
    this.durationSeconds,
    this.type = 'track',
    this.metadata = const {},
  });
}

/// The complete home feed.
class HomeFeed {
  final List<HomeSection> sections;
  final DateTime? lastUpdated;

  const HomeFeed({
    this.sections = const [],
    this.lastUpdated,
  });
}
