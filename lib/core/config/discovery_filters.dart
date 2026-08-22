// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Discovery filter configuration (V SHOTS DISCOVER taxonomy)
// ═════════════════════════════════════════════════════════════════════════════
//
// A. QUICK EXPLORE (single-select): Trending / New Releases / Rising Now /
//    For You / Surprise Me — For You & Surprise Me = engine sources (NULL
//    query). B. MOOD (10) C. LANGUAGE (12) D. GENRE (11) E. DECADES (4)
//    F. ACTIVITY (8).
// ═════════════════════════════════════════════════════════════════════════════

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
  final String? query;
  final String order;
}

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
  DiscoverySource(id: 'for_you', label: 'For You', icon: '🎯'),
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
    id: 'rising_now',
    label: 'Rising Now',
    icon: '📈',
    query: 'rising viral songs official audio 2026',
    order: 'viewCount',
  ),
  DiscoverySource(id: 'surprise_me', label: 'Surprise Me', icon: '🎲'),
];

const List<DiscoveryMood> kDiscoveryMoods = [
  DiscoveryMood(id: 'chill', label: 'Chill', icon: '😌', query: 'chill'),
  DiscoveryMood(id: 'happy', label: 'Happy', icon: '😄', query: 'happy'),
  DiscoveryMood(id: 'sad', label: 'Sad', icon: '😢', query: 'sad'),
  DiscoveryMood(
      id: 'romantic', label: 'Romantic', icon: '❤️', query: 'romantic'),
  DiscoveryMood(
      id: 'energetic', label: 'Energetic', icon: '⚡', query: 'energetic'),
  DiscoveryMood(id: 'party', label: 'Party', icon: '💃', query: 'party'),
  DiscoveryMood(id: 'focus', label: 'Focus', icon: '🎧', query: 'focus'),
  DiscoveryMood(id: 'sleep', label: 'Sleep', icon: '😴', query: 'sleep'),
  DiscoveryMood(id: 'workout', label: 'Workout', icon: '🏋️', query: 'workout'),
  DiscoveryMood(
      id: 'devotional', label: 'Devotional', icon: '🛕', query: 'devotional'),
];

const List<DiscoveryFilterOption> kDiscoveryLanguages = [
  DiscoveryFilterOption(id: 'hindi', label: 'Hindi', token: 'hindi'),
  DiscoveryFilterOption(id: 'punjabi', label: 'Punjabi', token: 'punjabi'),
  DiscoveryFilterOption(id: 'english', label: 'English', token: 'english'),
  DiscoveryFilterOption(id: 'telugu', label: 'Telugu', token: 'telugu'),
  DiscoveryFilterOption(id: 'tamil', label: 'Tamil', token: 'tamil'),
  DiscoveryFilterOption(id: 'bhojpuri', label: 'Bhojpuri', token: 'bhojpuri'),
  DiscoveryFilterOption(id: 'haryanvi', label: 'Haryanvi', token: 'haryanvi'),
  DiscoveryFilterOption(id: 'marathi', label: 'Marathi', token: 'marathi'),
  DiscoveryFilterOption(id: 'bengali', label: 'Bengali', token: 'bengali'),
  DiscoveryFilterOption(id: 'gujarati', label: 'Gujarati', token: 'gujarati'),
  DiscoveryFilterOption(
      id: 'malayalam', label: 'Malayalam', token: 'malayalam'),
  DiscoveryFilterOption(id: 'kannada', label: 'Kannada', token: 'kannada'),
];

const List<DiscoveryFilterOption> kDiscoveryGenres = [
  DiscoveryFilterOption(
      id: 'bollywood', label: 'Bollywood', token: 'bollywood'),
  DiscoveryFilterOption(id: 'indie', label: 'Indie', token: 'indie'),
  DiscoveryFilterOption(id: 'pop', label: 'Pop', token: 'pop'),
  DiscoveryFilterOption(id: 'hiphop', label: 'Hip-Hop', token: 'hip hop'),
  DiscoveryFilterOption(id: 'edm', label: 'EDM', token: 'edm'),
  DiscoveryFilterOption(id: 'rock', label: 'Rock', token: 'rock'),
  DiscoveryFilterOption(id: 'lofi', label: 'Lo-Fi', token: 'lofi'),
  DiscoveryFilterOption(
      id: 'classical', label: 'Classical', token: 'classical'),
  DiscoveryFilterOption(id: 'ghazal', label: 'Ghazal', token: 'ghazal'),
  DiscoveryFilterOption(id: 'sufi', label: 'Sufi', token: 'sufi'),
  DiscoveryFilterOption(id: 'regional', label: 'Regional', token: 'regional'),
];

const List<DiscoveryFilterOption> kDiscoveryDecades = [
  DiscoveryFilterOption(id: '90s', label: '90s', token: '90s hits'),
  DiscoveryFilterOption(id: '2000s', label: '2000s', token: '2000s hits'),
  DiscoveryFilterOption(id: '2010s', label: '2010s', token: '2010s hits'),
  DiscoveryFilterOption(id: '2020s', label: '2020s', token: '2020s hits'),
];

const List<DiscoveryFilterOption> kDiscoveryActivities = [
  DiscoveryFilterOption(id: 'workout', label: 'Workout', token: 'workout'),
  DiscoveryFilterOption(
      id: 'road_trip', label: 'Road Trip', token: 'road trip'),
  DiscoveryFilterOption(
      id: 'late_night', label: 'Late Night', token: 'late night'),
  DiscoveryFilterOption(id: 'morning', label: 'Morning', token: 'morning'),
  DiscoveryFilterOption(id: 'party', label: 'Party', token: 'party'),
  DiscoveryFilterOption(id: 'study', label: 'Study', token: 'study'),
  DiscoveryFilterOption(id: 'travel', label: 'Travel', token: 'travel'),
  DiscoveryFilterOption(
      id: 'rainy_day', label: 'Rainy Day', token: 'rainy day'),
];

class DiscoveryFilterConfig {
  const DiscoveryFilterConfig({
    required this.source,
    this.moods = const [],
    this.languages = const [],
    this.genres = const [],
    this.decades = const [],
    this.activities = const [],
  });

  final DiscoverySource source;
  final List<DiscoveryMood> moods;
  final List<DiscoveryFilterOption> languages;
  final List<DiscoveryFilterOption> genres;
  final List<DiscoveryFilterOption> decades;
  final List<DiscoveryFilterOption> activities;

  static final initial = DiscoveryFilterConfig(source: kDiscoverySources.first);

  bool matches(DiscoveryFilterConfig other) =>
      source.id == other.source.id &&
      _ids(moods) == _ids(other.moods) &&
      _ids(languages) == _ids(other.languages) &&
      _ids(genres) == _ids(other.genres) &&
      _ids(decades) == _ids(other.decades) &&
      _ids(activities) == _ids(other.activities);

  bool get hasOnlySource =>
      moods.isEmpty &&
      languages.isEmpty &&
      genres.isEmpty &&
      decades.isEmpty &&
      activities.isEmpty;

  static String _ids(List<dynamic> items) =>
      items.map((e) => (e as dynamic).id as String).toList().join(',');

  DiscoveryFilterConfig copyWith({
    DiscoverySource? source,
    List<DiscoveryMood>? moods,
    List<DiscoveryFilterOption>? languages,
    List<DiscoveryFilterOption>? genres,
    List<DiscoveryFilterOption>? decades,
    List<DiscoveryFilterOption>? activities,
  }) =>
      DiscoveryFilterConfig(
        source: source ?? this.source,
        moods: moods ?? this.moods,
        languages: languages ?? this.languages,
        genres: genres ?? this.genres,
        decades: decades ?? this.decades,
        activities: activities ?? this.activities,
      );
}

String buildDiscoveryQuery({
  required DiscoverySource source,
  List<DiscoveryMood> moods = const [],
  List<DiscoveryFilterOption> languages = const [],
  List<DiscoveryFilterOption> genres = const [],
  List<DiscoveryFilterOption> decades = const [],
  List<DiscoveryFilterOption> activities = const [],
}) {
  final parts = <String>[];
  if (source.query != null && source.query!.isNotEmpty) {
    parts.add(source.query!);
  }
  parts.addAll(moods.map((m) => m.query));
  parts.addAll(languages.map((l) => l.token));
  parts.addAll(genres.map((g) => g.token));
  parts.addAll(decades.map((d) => d.token));
  parts.addAll(activities.map((a) => a.token));
  var query = parts.join(' ');
  if (query.trim().isEmpty) query = 'songs';
  if (!query.toLowerCase().contains('official')) {
    query = '$query official music';
  }
  return query.trim();
}

String discoveryFilterSummary({
  required DiscoverySource source,
  List<DiscoveryMood> moods = const [],
  List<DiscoveryFilterOption> languages = const [],
  List<DiscoveryFilterOption> genres = const [],
  List<DiscoveryFilterOption> decades = const [],
  List<DiscoveryFilterOption> activities = const [],
}) {
  final extras = <String>[
    ...moods.map((m) => m.label),
    ...languages.map((l) => l.label),
    ...genres.map((g) => g.label),
    ...decades.map((d) => d.label),
    ...activities.map((a) => a.label),
  ];
  if (extras.isNotEmpty) return extras.join(' · ');
  return source.label;
}
