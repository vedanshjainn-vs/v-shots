// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Discovery filter configuration (source / mood / language / region)
// ═════════════════════════════════════════════════════════════════════════════
//
// Single source of truth for the Discovery filter hierarchy:
//
//   DISCOVER (source)   →  For You / Trending / New Releases / Viral /
//                          Popular / Latest Music
//   MOOD                →  Romantic / Sad / Energetic / Chill / Late Night /
//                          Party / Workout / Peaceful / Feel Good
//   LANGUAGE            →  Hindi / English / Punjabi / …  (secondary)
//   REGION / CULTURE    →  Bollywood / Punjabi / South Indian / …  (secondary)
//
// Selecting a source/mood/language/region MUST change the actual YouTube query
// (via [buildDiscoveryQuery]) — never just a chip label. "For You" has a NULL
// query: that signals the personalized recommendation-engine path. Query
// tokens are kept BARE (e.g. "hindi", "romantic") so they compose into a clean,
// strongly-constrained query instead of repetitive "...songs ...songs" noise.
// ═════════════════════════════════════════════════════════════════════════════

/// A discovery SOURCE — the primary "what kind of content" selector.
class DiscoverySource {
  const DiscoverySource({
    required this.id,
    required this.label,
    required this.icon,
    this.query,
  });

  final String id;
  final String label;
  final String icon;

  /// Exact YouTube query. NULL → personalized ("For You" engine path).
  final String? query;
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

  /// Bare mood token appended to the query (e.g. "romantic").
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

  /// Bare query token (e.g. "hindi", "bollywood").
  final String token;
}

const List<DiscoverySource> kDiscoverySources = [
  DiscoverySource(id: 'for_you', label: 'For You', icon: '✨'),
  DiscoverySource(
    id: 'trending',
    label: 'Trending',
    icon: '🔥',
    query: 'trending songs official video 2026',
  ),
  DiscoverySource(
    id: 'new',
    label: 'New Releases',
    icon: '🆕',
    query: 'new music releases official audio 2026',
  ),
  DiscoverySource(
    id: 'viral',
    label: 'Viral',
    icon: '📈',
    query: 'viral trending songs official audio 2026',
  ),
  DiscoverySource(
    id: 'popular',
    label: 'Popular',
    icon: '🎧',
    query: 'top songs official audio 2026',
  ),
  DiscoverySource(
    id: 'latest',
    label: 'Latest Music',
    icon: '🎵',
    query: 'latest songs official audio 2026',
  ),
];

const List<DiscoveryMood> kDiscoveryMoods = [
  DiscoveryMood(
      id: 'romantic', label: 'Romantic', icon: '❤️', query: 'romantic'),
  DiscoveryMood(id: 'sad', label: 'Sad', icon: '😢', query: 'sad'),
  DiscoveryMood(id: 'chill', label: 'Chill', icon: '😌', query: 'chill'),
  DiscoveryMood(
      id: 'energetic', label: 'Energetic', icon: '⚡', query: 'energetic'),
  DiscoveryMood(id: 'party', label: 'Party', icon: '💃', query: 'party'),
  DiscoveryMood(id: 'workout', label: 'Workout', icon: '🔥', query: 'workout'),
  DiscoveryMood(
      id: 'latenight', label: 'Late Night', icon: '🌙', query: 'late night'),
  DiscoveryMood(
      id: 'feelgood', label: 'Feel Good', icon: '✨', query: 'feel good'),
  DiscoveryMood(
      id: 'peaceful', label: 'Peaceful', icon: '🧘', query: 'peaceful'),
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
      id: 'malayalam', label: 'Malayalam', token: 'malayalam'),
  DiscoveryFilterOption(id: 'kannada', label: 'Kannada', token: 'kannada'),
];

const List<DiscoveryFilterOption> kDiscoveryRegions = [
  DiscoveryFilterOption(
      id: 'bollywood', label: 'Bollywood', token: 'bollywood'),
  DiscoveryFilterOption(id: 'punjabi', label: 'Punjabi', token: 'punjabi hits'),
  DiscoveryFilterOption(
      id: 'south', label: 'South Indian', token: 'south indian'),
  DiscoveryFilterOption(
      id: 'indie', label: 'Indie India', token: 'hindi indie'),
  DiscoveryFilterOption(
      id: 'international', label: 'International', token: 'international hits'),
];

/// Builds the final YouTube discovery query from the selected filters.
/// Pure + deterministic (unit-tested). [source.query] == null means the
/// personalized "For You" path (the engine), in which case the mood/language/
/// region tokens still form the fallback pool query. An "official music"
/// intent is appended when the composed query has none, so filters strongly
/// constrain toward official music content.
String buildDiscoveryQuery({
  required DiscoverySource source,
  DiscoveryMood? mood,
  DiscoveryFilterOption? language,
  DiscoveryFilterOption? region,
}) {
  final parts = <String>[];
  if (source.query != null && source.query!.isNotEmpty) {
    parts.add(source.query!);
  }
  if (mood != null) parts.add(mood.query);
  if (language != null) parts.add(language.token);
  if (region != null) parts.add(region.token);
  var query = parts.join(' ');
  if (query.trim().isEmpty) query = 'songs';
  if (!query.toLowerCase().contains('official')) {
    query = '$query official music';
  }
  return query.trim();
}

/// Human-readable summary of the active filters for the compact top pill,
/// e.g. "For You", "Trending", "Romantic · Hindi", "Chill · English".
String discoveryFilterSummary({
  required DiscoverySource source,
  DiscoveryMood? mood,
  DiscoveryFilterOption? language,
  DiscoveryFilterOption? region,
}) {
  final extras = <String>[
    if (mood != null) mood.label,
    if (language != null) language.label,
    if (region != null) region.label,
  ];
  if (extras.isNotEmpty) {
    // When mood/language/region carry the intent, they are the headline.
    return extras.join(' · ');
  }
  return source.label;
}
