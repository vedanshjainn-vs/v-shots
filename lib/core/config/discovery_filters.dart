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
//   Filters (•••)       →  Language + Region/Culture (secondary)
//
// Selecting a source/mood/lang/region MUST change the actual YouTube query
// (via [buildDiscoveryQuery]) — never just the chip label. "For You" has a
// NULL query: that signals the personalized recommendation-engine path.
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
  final String query;
}

/// A simple labelled query token for the secondary Filters sheet.
class DiscoveryFilterOption {
  const DiscoveryFilterOption(
      {required this.id, required this.label, required this.token});

  final String id;
  final String label;

  /// Query token appended to the source/mood query (e.g. "hindi songs").
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
      id: 'romantic',
      label: 'Romantic',
      icon: '❤️',
      query: 'romantic love songs'),
  DiscoveryMood(
      id: 'sad', label: 'Sad', icon: '😢', query: 'sad emotional songs'),
  DiscoveryMood(
      id: 'energetic',
      label: 'Energetic',
      icon: '⚡',
      query: 'energetic upbeat songs'),
  DiscoveryMood(
      id: 'chill', label: 'Chill', icon: '😌', query: 'chill relaxing songs'),
  DiscoveryMood(
      id: 'latenight',
      label: 'Late Night',
      icon: '🌙',
      query: 'late night chill songs'),
  DiscoveryMood(
      id: 'party', label: 'Party', icon: '💃', query: 'party dance songs'),
  DiscoveryMood(
      id: 'workout', label: 'Workout', icon: '🔥', query: 'workout gym songs'),
  DiscoveryMood(
      id: 'peaceful',
      label: 'Peaceful',
      icon: '🧘',
      query: 'peaceful calm songs'),
  DiscoveryMood(
      id: 'feelgood',
      label: 'Feel Good',
      icon: '✨',
      query: 'feel good happy songs'),
];

const List<DiscoveryFilterOption> kDiscoveryLanguages = [
  DiscoveryFilterOption(id: 'hindi', label: 'Hindi', token: 'hindi songs'),
  DiscoveryFilterOption(
      id: 'english', label: 'English', token: 'english songs'),
  DiscoveryFilterOption(
      id: 'punjabi', label: 'Punjabi', token: 'punjabi songs'),
  DiscoveryFilterOption(id: 'tamil', label: 'Tamil', token: 'tamil songs'),
  DiscoveryFilterOption(id: 'telugu', label: 'Telugu', token: 'telugu songs'),
  DiscoveryFilterOption(
      id: 'bengali', label: 'Bengali', token: 'bengali songs'),
  DiscoveryFilterOption(
      id: 'marathi', label: 'Marathi', token: 'marathi songs'),
  DiscoveryFilterOption(
      id: 'bhojpuri', label: 'Bhojpuri', token: 'bhojpuri songs'),
  DiscoveryFilterOption(
      id: 'haryanvi', label: 'Haryanvi', token: 'haryanvi songs'),
  DiscoveryFilterOption(
      id: 'malayalam', label: 'Malayalam', token: 'malayalam songs'),
  DiscoveryFilterOption(
      id: 'kannada', label: 'Kannada', token: 'kannada songs'),
];

const List<DiscoveryFilterOption> kDiscoveryRegions = [
  DiscoveryFilterOption(
      id: 'bollywood', label: 'Bollywood', token: 'bollywood songs'),
  DiscoveryFilterOption(id: 'punjabi', label: 'Punjabi', token: 'punjabi hits'),
  DiscoveryFilterOption(
      id: 'south', label: 'South Indian', token: 'south indian songs'),
  DiscoveryFilterOption(
      id: 'indie', label: 'Indie India', token: 'hindi indie songs'),
  DiscoveryFilterOption(
      id: 'international', label: 'International', token: 'international hits'),
];

/// Builds the final YouTube discovery query from the selected filters.
/// Pure + deterministic (unit-tested). [source.query] == null means the
/// personalized "For You" path (the engine), in which case only the mood's
/// query is returned so the fallback pool is mood-biased.
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
  return parts.join(' ');
}
