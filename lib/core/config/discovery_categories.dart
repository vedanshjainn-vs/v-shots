// ═════════════════════════════════════════════════════════════════════════
// V Shots — Discovery Category Configuration (Single Source of Truth)
//
// This is the ONE place that maps a Discovery category -> YouTube search
// query. The Discovery screen, the mood picker, and the fallback catalog all
// read from here, so the "displayed label" and the "active fetch filter" can
// never drift apart (the root cause of the filter bug where the label changed
// but the underlying query didn't).
//
// NOTE: This hardcoded map is the runtime fallback. In production it is
// overridden by the Supabase `discovery_categories` remote-config table (see
// lib/core/remote_config/), but the app always has this default so it works
// offline and before any remote config arrives.
// ═════════════════════════════════════════════════════════════════════════

/// A single Discovery category: display label + emoji + the YouTube search
/// query that drives its candidate pool + the fallback catalog category tag.
class DiscoveryCategory {
  const DiscoveryCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.query,
    required this.fallbackCategory,
  });

  final String id;
  final String label;
  final String icon;

  /// The exact YouTube search query string for this category. Every category
  /// has a DISTINCT query — this is what guarantees filters actually change
  /// the returned content.
  final String query;

  /// The fallback-catalog category tag used when the live API is unavailable
  /// (must match `category` values in youtube_data_api_client.dart).
  final String fallbackCategory;
}

/// The authoritative, ordered Discovery category list (default / offline).
///
/// The FIRST entry ("For You") has an EMPTY query — that is the signal for
/// the Discovery feed to build the batch from the RecommendationEngine
/// (personalized: signals -> taste profile -> candidates -> ranked feed)
/// instead of a fixed category query. Every other category has a DISTINCT
/// query, which is what guarantees the mood selector actually changes the
/// returned content.
const List<DiscoveryCategory> kDiscoveryCategories = [
  DiscoveryCategory(
    id: 'for_you',
    label: 'For You',
    icon: '✨',
    query: '',
    fallbackCategory: 'global',
  ),
  DiscoveryCategory(
    id: 'trending',
    label: 'Trending',
    icon: '🌟',
    query: 'trending songs 2026 official video',
    fallbackCategory: 'global',
  ),
  DiscoveryCategory(
    id: 'hindi',
    label: 'Hindi',
    icon: '🎤',
    query: 'latest hindi songs official audio',
    fallbackCategory: 'bollywood',
  ),
  DiscoveryCategory(
    id: 'bollywood',
    label: 'Bollywood',
    icon: '🎬',
    query: 'top bollywood hindi songs official music video',
    fallbackCategory: 'bollywood',
  ),
  DiscoveryCategory(
    id: 'punjabi',
    label: 'Punjabi',
    icon: '🎸',
    query: 'punjabi songs official video 2026',
    fallbackCategory: 'punjabi',
  ),
  DiscoveryCategory(
    id: 'english',
    label: 'English',
    icon: '🌍',
    query: 'top english pop billboard hits official audio',
    fallbackCategory: 'global',
  ),
  DiscoveryCategory(
    id: 'romantic',
    label: 'Romantic',
    icon: '💖',
    query: 'romantic love songs hindi punjabi official',
    fallbackCategory: 'bollywood',
  ),
  DiscoveryCategory(
    id: 'sad',
    label: 'Sad',
    icon: '🌧️',
    query: 'sad heartbreak emotional songs hindi official',
    fallbackCategory: 'nostalgia',
  ),
  DiscoveryCategory(
    id: 'happy',
    label: 'Happy',
    icon: '😄',
    query: 'happy feel good upbeat songs official audio',
    fallbackCategory: 'global',
  ),
  DiscoveryCategory(
    id: 'party',
    label: 'Party',
    icon: '🔥',
    query: 'party dance songs bollywood punjabi official',
    fallbackCategory: 'punjabi',
  ),
  DiscoveryCategory(
    id: 'chill',
    label: 'Chill',
    icon: '😌',
    query: 'chill relaxing songs official audio',
    fallbackCategory: 'ambient',
  ),
  DiscoveryCategory(
    id: 'lofi',
    label: 'Lo-Fi',
    icon: '🎧',
    query: 'lofi chill study beats instrumental',
    fallbackCategory: 'ambient',
  ),
  DiscoveryCategory(
    id: 'workout',
    label: 'Workout',
    icon: '⚡',
    query: 'gym workout hype songs official',
    fallbackCategory: 'workout',
  ),
  DiscoveryCategory(
    id: 'devotional',
    label: 'Devotional',
    icon: '🙏',
    query: 'bhajan devotional songs official',
    fallbackCategory: 'devotional',
  ),
  DiscoveryCategory(
    id: 'classics',
    label: 'Classics',
    icon: '🏛️',
    query: 'evergreen classic hindi songs official',
    fallbackCategory: 'nostalgia',
  ),
  DiscoveryCategory(
    id: '90s',
    label: '90s',
    icon: '📼',
    query: '90s hindi evergreen songs official',
    fallbackCategory: 'nostalgia',
  ),
  DiscoveryCategory(
    id: '2000s',
    label: '2000s',
    icon: '📀',
    query: '2000s bollywood hit songs official',
    fallbackCategory: 'nostalgia',
  ),
  DiscoveryCategory(
    id: 'indie',
    label: 'Indie',
    icon: '🌱',
    query: 'hindi indie acoustic songs official audio',
    fallbackCategory: 'indie',
  ),
  DiscoveryCategory(
    id: 'hiphop',
    label: 'Hip-Hop',
    icon: '🎤',
    query: 'hip hop rap desi english songs official',
    fallbackCategory: 'workout',
  ),
  DiscoveryCategory(
    id: 'rock',
    label: 'Rock',
    icon: '🎸',
    query: 'best rock songs classic and modern official',
    fallbackCategory: 'global',
  ),
  DiscoveryCategory(
    id: 'electronic',
    label: 'Electronic',
    icon: '🎛️',
    query: 'electronic edm dance music hits official',
    fallbackCategory: 'ambient',
  ),
  DiscoveryCategory(
    id: 'global',
    label: 'Global',
    icon: '🌐',
    query: 'global pop hits official video',
    fallbackCategory: 'global',
  ),
  DiscoveryCategory(
    id: 'latenight',
    label: 'Late Night Chill',
    icon: '🌙',
    query: 'chill late night songs official',
    fallbackCategory: 'ambient',
  ),
  DiscoveryCategory(
    id: 'focus',
    label: 'Focus & Study',
    icon: '🧘',
    query: 'lofi focus study instrumental',
    fallbackCategory: 'ambient',
  ),
  DiscoveryCategory(
    id: 'roadtrip',
    label: 'Road Trip Drive',
    icon: '🚗',
    query: 'road trip driving songs playlist official',
    fallbackCategory: 'workout',
  ),
  DiscoveryCategory(
    id: 'sufi',
    label: 'Sufi & Ghazals',
    icon: '✨',
    query: 'sufi ghazal songs official',
    fallbackCategory: 'sufi',
  ),
  DiscoveryCategory(
    id: 'wedding',
    label: 'Wedding & Sangeet',
    icon: '💍',
    query: 'wedding sangeet songs bollywood official',
    fallbackCategory: 'bollywood',
  ),
  DiscoveryCategory(
    id: 'monsoon',
    label: 'Monsoon Vibes',
    icon: '☔',
    query: 'monsoon rain songs hindi official',
    fallbackCategory: 'bollywood',
  ),
  DiscoveryCategory(
    id: 'motivational',
    label: 'Motivational',
    icon: '🏆',
    query: 'motivational songs hindi official',
    fallbackCategory: 'global',
  ),
];

/// Looks up a category by its id.
DiscoveryCategory? discoveryCategoryById(String id) {
  for (final c in kDiscoveryCategories) {
    if (c.id == id) return c;
  }
  return null;
}

/// Looks up a category by its display label.
DiscoveryCategory? discoveryCategoryByLabel(String label) {
  for (final c in kDiscoveryCategories) {
    if (c.label == label) return c;
  }
  return null;
}
