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
const List<DiscoveryCategory> kDiscoveryCategories = [
  DiscoveryCategory(
    id: 'trending',
    label: 'Trending Hits',
    icon: '🌟',
    query: 'trending songs 2026 official video',
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
    id: 'romantic',
    label: 'Romantic & Love',
    icon: '💖',
    query: 'romantic love songs hindi punjabi official',
    fallbackCategory: 'bollywood',
  ),
  DiscoveryCategory(
    id: 'party',
    label: 'Party & Dance',
    icon: '🔥',
    query: 'party dance songs bollywood punjabi official',
    fallbackCategory: 'punjabi',
  ),
  DiscoveryCategory(
    id: 'workout',
    label: 'Gym & Hype',
    icon: '⚡',
    query: 'gym workout hype songs official',
    fallbackCategory: 'workout',
  ),
  DiscoveryCategory(
    id: 'sad',
    label: 'Heartbroken & Sad',
    icon: '🌧️',
    query: 'sad heartbreak songs hindi official',
    fallbackCategory: 'nostalgia',
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
    id: 'bollywood',
    label: 'Bollywood Hits',
    icon: '🎬',
    query: 'bollywood hit songs official video',
    fallbackCategory: 'bollywood',
  ),
  DiscoveryCategory(
    id: 'punjabi',
    label: 'Punjabi Bangers',
    icon: '🎸',
    query: 'punjabi songs official video 2026',
    fallbackCategory: 'punjabi',
  ),
  DiscoveryCategory(
    id: 'indie',
    label: 'Hindi Indie',
    icon: '🎧',
    query: 'hindi indie music official',
    fallbackCategory: 'indie',
  ),
  DiscoveryCategory(
    id: 'global',
    label: 'Global Pop 100',
    icon: '🌍',
    query: 'global pop hits official video',
    fallbackCategory: 'global',
  ),
  DiscoveryCategory(
    id: 'devotional',
    label: 'Devotional & Bhajans',
    icon: '🙏',
    query: 'bhajan devotional songs official',
    fallbackCategory: 'devotional',
  ),
  DiscoveryCategory(
    id: 'sufi',
    label: 'Sufi & Ghazals',
    icon: '✨',
    query: 'sufi ghazal songs official',
    fallbackCategory: 'sufi',
  ),
  DiscoveryCategory(
    id: 'nostalgia',
    label: '90s Nostalgia',
    icon: '📻',
    query: '90s hindi songs official',
    fallbackCategory: 'nostalgia',
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
