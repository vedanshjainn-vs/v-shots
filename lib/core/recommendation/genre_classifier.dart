// ════════════════════════════════════════════════
// V Shots — Recommendation Engine: lightweight genre classification
// ════════════════════════════════════════════════
//
// HONEST SCOPE NOTE: this is NOT audio-content analysis (no ML model,
// no acoustic feature extraction — YouTube's API exposes no such data,
// and building/shipping one is far outside "UI motion + recommendation
// engine" scope). This is a keyword-heuristic classifier over track
// title/artist text and the ORIGINAL SEARCH QUERY that surfaced a
// track — genuinely useful for content-based similarity (Part H/J)
// without pretending to be more sophisticated than it is.
//
// The genre vocabulary matches the ALREADY-EXISTING categories Home
// and Search use (Bollywood/Punjabi/Hindi/English/Hip-Hop/EDM/Chill —
// see main.dart's HomeScreen._sections and SearchScreen._categories)
// so "genre affinity" means the same thing across the whole app, not
// a second, divergent taxonomy invented just for recommendations.
// ════════════════════════════════════════════════

class GenreClassifier {
  GenreClassifier._();
  static final GenreClassifier instance = GenreClassifier._();

  static const Map<String, List<String>> _genreKeywords = {
    'Bollywood': ['bollywood', 'hindi film', 'filmi'],
    'Punjabi': ['punjabi', 'bhangra'],
    'Hindi': ['hindi'],
    'English': ['english pop', 'pop song'],
    'Hip-Hop': ['hip hop', 'rap', 'trap'],
    'EDM': ['edm', 'dance', 'electronic', 'house music', 'techno'],
    'Chill': ['lofi', 'lo-fi', 'chill', 'acoustic', 'ambient'],
    'Romantic': ['romantic', 'love song'],
    'Sad': ['sad song', 'heartbreak', 'breakup'],
    'Workout': ['workout', 'gym', 'motivation'],
    'K-Pop': ['k-pop', 'kpop', 'korean'],
    'Indie': ['indie'],
    'RnB': ['rnb', 'r&b', 'slow jam'],
  };

  /// Returns the best-guess genre tags for a track, using its title,
  /// artist, and (if known) the search query that originally surfaced
  /// it — e.g. a track found via the "punjabi hit songs official
  /// audio" query is confidently tagged "Punjabi" even if neither the
  /// title nor artist string mentions it explicitly, which is common
  /// for real YouTube video titles.
  Set<String> classify({
    required String title,
    required String artist,
    String? sourceQuery,
  }) {
    final haystack =
        '${title.toLowerCase()} ${artist.toLowerCase()} ${(sourceQuery ?? '').toLowerCase()}';
    final tags = <String>{};
    for (final entry in _genreKeywords.entries) {
      if (entry.value.any(haystack.contains)) {
        tags.add(entry.key);
      }
    }
    return tags;
  }

  /// Cosine-similarity-style overlap between two tag sets — a simple,
  /// honest content-based similarity score (Part H: "content-based
  /// filtering... similarity scoring"). Returns 0.0-1.0.
  double similarity(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    return union == 0 ? 0.0 : intersection / union; // Jaccard similarity
  }
}
