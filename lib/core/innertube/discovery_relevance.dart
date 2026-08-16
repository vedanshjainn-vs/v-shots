// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Discovery relevance filter (pure)
// ═════════════════════════════════════════════════════════════════════════════
//
// After InnerTube/YouTube results arrive, this drops obviously IRRELEVANT
// content (gaming, news, sports, podcasts, tutorials, reactions, vlogs, movie
// explanations…) so a filter like "Romantic + Hindi" never surfaces unrelated
// uploads. It is keyword-based and deliberately conservative: it only REJECTS
// strong non-music signals — it never fabricates relevance or official status.
// If filtering would empty the batch, callers keep the original batch
// (relaxed fallback, matching the strict→relaxed philosophy elsewhere).
// ═════════════════════════════════════════════════════════════════════════════

const List<String> kIrrelevantKeywords = [
  'gaming',
  'gameplay',
  'pubg',
  'free fire',
  'news',
  'breaking news',
  'sports',
  'cricket',
  'football',
  'podcast',
  'tutorial',
  'how to',
  'reaction',
  'reacting',
  'review',
  'explained',
  'movie explanation',
  'vlog',
  'daily vlog',
  'meme',
  'prank',
  'gossip',
  'unboxing',
  'cooking',
  'recipe',
  'comedy',
  'stand up',
];

/// True when a title/channel carries a strong IRRELEVANT signal for a music
/// discovery feed. Checks both title and channel text (lowercased).
bool isIrrelevantContent(String title, String channel) {
  final haystack = '${title.toLowerCase()} ${channel.toLowerCase()}';
  return kIrrelevantKeywords.any(haystack.contains);
}

/// Filters [tracks] (each a `Map` with title/artist keys) down to relevant
/// music. Returns the filtered list; if filtering empties the batch, returns
/// the original batch unchanged so a filter never leaves Discovery stuck.
List<Map<String, dynamic>> filterRelevantTracks(
  List<Map<String, dynamic>> tracks,
) {
  final kept = tracks.where((t) {
    final title = (t['title'] as String?) ?? '';
    final artist = (t['artist'] as String?) ?? '';
    return !isIrrelevantContent(title, artist);
  }).toList();
  return kept.isEmpty ? tracks : kept;
}
