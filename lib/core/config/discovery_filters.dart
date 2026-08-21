// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Discovery filter configuration (source / moods / languages / regions)
// ═════════════════════════════════════════════════════════════════════════════
//
// Single source of truth for the Discovery filter hierarchy:
//
//   DISCOVER (source, single-select)  → For You / Trending / New Releases /
//                                        Viral / Popular / Latest Music
//   MOODS    (multi-select)           → Romantic / Sad / Energetic / …
//   LANGUAGES (multi-select)          → Hindi / English / Punjabi / …
//   REGIONS   (multi-select)          → Bollywood / Punjabi / South Indian / …
//
// Each SOURCE carries a distinct query AND a distinct ranking ORDER so the
// modes produce materially different feeds — never the same query renamed.
// "For You" has a NULL query: it uses the personalized recommendation engine,
// with moods/languages/regions composing the fallback pool query.
// ═════════════════════════════════════════════════════════════════════════════

/// A discovery SOURCE — the primary "what kind of content" selector.
class DiscoverySource {
  const DiscoverySource({
    required this.id,
    required this.label,
    required this.icon,
    this.query,
    this.order = 'relevance',
  });

  final String id;
  final String label;
  final String icon;

  /// Exact YouTube query. NULL → personalized ("For You" engine path).
  final String? query;

  /// Ranking order passed to the provider: 'relevance' | 'viewCount' | 'date'.
  /// This is what makes Trending/Viral/Popular rank differently from
  /// New Releases / Latest Music.
  final String order;
}

/// A discovery MOOD — biases the candidate pool emotionally.
class DiscoveryMood {
  const DiscoveryMood({
    required this.id,
    required this.label,
    required this.icon,
    required this.query,
  });

  final String id;
  final String label;
  final String icon;
  final String query;
}

/// A simple labelled query token for the secondary Filters sheet.
class DiscoveryFilterOption {
  const DiscoveryFilterOption({
    required this.id,
    required this.label,
    required this.token,
  });

  final String id;
  final String label;
  final String token;
}

const List<DiscoverySource> kDiscoverySources = [
  DiscoverySource(id: 'for_you', label: 'For You', icon: '✨'),
  DiscoverySource(
    id: 'trending',
    label: 'Trending',
    icon: '🔥',
    query: 'trending songs official video 2026',
    order: 'viewCount',
  ),
  DiscoverySource(
    id: 'new',
    label: 'New Releases',
    icon: '🆕',
    query: 'new music releases official audio 2026',
    order: 'date',
  ),
  DiscoverySource(
    id: 'viral',
    label: 'Viral',
    icon: '📈',
    query: 'viral trending songs official audio 2026',
    order: 'viewCount',
  ),
  DiscoverySource(
    id: 'popular',
    label: 'Popular',
    icon: '🎧',
    query: 'top songs official audio 2026',
    order: 'viewCount',
  ),
  DiscoverySource(
    id: 'latest',
    label: 'Latest Music',
    icon: '🎵',
    query: 'latest songs official audio 2026',
    order: 'date',
  ),
];

const List<DiscoveryMood> kDiscoveryMoods = [
  DiscoveryMood(
    id: 'romantic',
    label: 'Romantic',
    icon: '❤️',
    query: 'romantic',
  ),
  DiscoveryMood(id: 'sad', label: 'Sad', icon: '😢', query: 'sad'),
  DiscoveryMood(id: 'chill', label: 'Chill', icon: '😌', query: 'chill'),
  DiscoveryMood(
    id: 'energetic',
    label: 'Energetic',
    icon: '⚡',
    query: 'energetic',
  ),
  DiscoveryMood(id: 'party', label: 'Party', icon: '💃', query: 'party'),
  DiscoveryMood(id: 'workout', label: 'Workout', icon: '🔥', query: 'workout'),
  DiscoveryMood(
    id: 'latenight',
    label: 'Late Night',
    icon: '🌙',
    query: 'late night',
  ),
  DiscoveryMood(
    id: 'feelgood',
    label: 'Feel Good',
    icon: '✨',
    query: 'feel good',
  ),
  DiscoveryMood(
    id: 'peaceful',
    label: 'Peaceful',
    icon: '🧘',
    query: 'peaceful',
  ),
];

const List<DiscoveryFilterOption> kDiscoveryLanguages = [
  DiscoveryFilterOption(id: 'hindi', label: 'Hindi', token: 'hindi'),
  DiscoveryFilterOption(id: 'english', label: 'English', token: 'english'),
  DiscoveryFilterOption(id: 'punjabi', label: 'Punjabi', token: 'punjabi'),
  DiscoveryFilterOption(id: 'tamil', label: 'Tamil', token: 'tamil'),
  DiscoveryFilterOption(id: 'telugu', label: 'Telugu', token: 'telugu'),
  DiscoveryFilterOption(id: 'bengali', label: 'Bengali', token: 'bengali'),
  DiscoveryFilterOption(id: 'marathi', label: 'Marathi', token: 'marathi'),
  DiscoveryFilterOption(id: 'gujarati', label: 'Gujarati', token: 'gujarati'),
  DiscoveryFilterOption(id: 'bhojpuri', label: 'Bhojpuri', token: 'bhojpuri'),
  DiscoveryFilterOption(id: 'haryanvi', label: 'Haryanvi', token: 'haryanvi'),
  DiscoveryFilterOption(
    id: 'malayalam',
    label: 'Malayalam',
    token: 'malayalam',
  ),
  DiscoveryFilterOption(id: 'kannada', label: 'Kannada', token: 'kannada'),
];

const List<DiscoveryFilterOption> kDiscoveryRegions = [
  DiscoveryFilterOption(
    id: 'bollywood',
    label: 'Bollywood',
    token: 'bollywood',
  ),
  DiscoveryFilterOption(id: 'punjabi', label: 'Punjabi', token: 'punjabi hits'),
  DiscoveryFilterOption(
    id: 'south',
    label: 'South Indian',
    token: 'south indian',
  ),
  DiscoveryFilterOption(
    id: 'indie',
    label: 'Indie India',
    token: 'hindi indie',
  ),
  DiscoveryFilterOption(
    id: 'international',
    label: 'International',
    token: 'international hits',
  ),
];

/// The committed/applied Discovery filter configuration — a value object so
/// the Explore sheet can hold a DRAFT copy and compare it to the applied one.
class DiscoveryFilterConfig {
  const DiscoveryFilterConfig({
    required this.source,
    this.moods = const [],
    this.languages = const [],
    this.regions = const [],
  });

  final DiscoverySource source;
  final List<DiscoveryMood> moods;
  final List<DiscoveryFilterOption> languages;
  final List<DiscoveryFilterOption> regions;

  static final initial = DiscoveryFilterConfig(source: kDiscoverySources.first);

  bool matches(DiscoveryFilterConfig other) =>
      source.id == other.source.id &&
      _ids(moods) == _ids(other.moods) &&
      _ids(languages) == _ids(other.languages) &&
      _ids(regions) == _ids(other.regions);

  bool get hasOnlySource =>
      moods.isEmpty && languages.isEmpty && regions.isEmpty;

  static String _ids(List<dynamic> items) =>
      items.map((e) => (e as dynamic).id as String).toList().join(',');

  DiscoveryFilterConfig copyWith({
    DiscoverySource? source,
    List<DiscoveryMood>? moods,
    List<DiscoveryFilterOption>? languages,
    List<DiscoveryFilterOption>? regions,
  }) => DiscoveryFilterConfig(
    source: source ?? this.source,
    moods: moods ?? this.moods,
    languages: languages ?? this.languages,
    regions: regions ?? this.regions,
  );
}

/// Builds the final YouTube discovery query from the applied filters.
/// Pure + deterministic. [source.query] == null means the personalized
/// "For You" path; moods/languages/regions then compose the fallback query.
String buildDiscoveryQuery({
  required DiscoverySource source,
  List<DiscoveryMood> moods = const [],
  List<DiscoveryFilterOption> languages = const [],
  List<DiscoveryFilterOption> regions = const [],
}) {
  final parts = <String>[];
  if (source.query != null && source.query!.isNotEmpty) {
    parts.add(source.query!);
  }
  parts.addAll(moods.map((m) => m.query));
  parts.addAll(languages.map((l) => l.token));
  parts.addAll(regions.map((r) => r.token));
  var query = parts.join(' ');
  if (query.trim().isEmpty) query = 'songs';
  if (!query.toLowerCase().contains('official')) {
    query = '$query official music';
  }
  return query.trim();
}

/// Human-readable summary of the applied filters for the compact top pill.
String discoveryFilterSummary({
  required DiscoverySource source,
  List<DiscoveryMood> moods = const [],
  List<DiscoveryFilterOption> languages = const [],
  List<DiscoveryFilterOption> regions = const [],
}) {
  final extras = <String>[
    ...moods.map((m) => m.label),
    ...languages.map((l) => l.label),
    ...regions.map((r) => r.label),
  ];
  if (extras.isNotEmpty) return extras.join(' · ');
  return source.label;
}
