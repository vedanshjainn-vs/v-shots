// ═════════════════════════════════════════════════════════════════════════
// V Shots — Recommendation Engine: Lightweight Genre & Content Classifier
// ═════════════════════════════════════════════════════════════════════════

class GenreClassifier {
  GenreClassifier._();
  static final GenreClassifier instance = GenreClassifier._();

  static const Map<String, List<String>> _genreKeywords = {
    'Bollywood': ['bollywood', 'hindi film', 'filmi', 't-series', 'zeemusic'],
    'Punjabi': ['punjabi', 'bhangra', 'sidhu', 'diljit', 'ap dhillon', 'karan aujla'],
    'Hindi': ['hindi', 'arijit', 'jubin', 'shreya', 'sonu nigam'],
    'English': ['english pop', 'pop song', 'billboard', 'taylor', 'ed sheeran'],
    'Hip-Hop': ['hip hop', 'rap', 'trap', 'desi hip hop', 'raftaar', 'emiway', 'divine'],
    'EDM': ['edm', 'dance', 'electronic', 'house music', 'techno', 'dj'],
    'Chill': ['lofi', 'lo-fi', 'chill', 'acoustic', 'ambient', 'slowed', 'reverb'],
    'Romantic': ['romantic', 'love song', 'tum hi ho', 'romance', 'love'],
    'Sad': ['sad song', 'heartbreak', 'breakup', 'dard', 'emotional'],
    'Workout': ['workout', 'gym', 'motivation', 'beast mode', 'fitness'],
    'K-Pop': ['k-pop', 'kpop', 'korean', 'bts', 'blackpink'],
    'Indie': ['indie', 'independent', 'prateek kuhad', 'anuv jain'],
    'RnB': ['rnb', 'r&b', 'slow jam', 'soul'],
    'Devotional': ['bhajan', 'aarti', 'devotional', 'kirtan', 'mantra', 'hanuman', 'krishna', 'shiva'],
    '90s': ['90s', '90s hindi', 'evergreen', 'retro', 'kumar sanu', 'alka yagnik', 'udit narayan'],
    '2000s': ['2000s', 'y2k', '2000s bollywood', 'kk', 'mohit chauhan', 'emraan hashmi'],
    'Tamil': ['tamil', 'kollywood', 'anirudh', 'ar rahman', 'yuvan'],
    'Telugu': ['telugu', 'tollywood', 'dsp', 'thaman'],
    'Bengali': ['bengali', 'bangla'],
    'Bhojpuri': ['bhojpuri', 'pawan singh', 'khesari'],
    'Haryanvi': ['haryanvi', 'sapna'],
    'Marathi': ['marathi', 'ajay atul'],
    'Gujarati': ['gujarati', 'garba'],
  };

  static const Map<String, List<String>> _languageKeywords = {
    'Hindi': ['hindi', 'bollywood', 't-series', 'arijit'],
    'Punjabi': ['punjabi', 'bhangra', 'sidhu', 'diljit', 'ap dhillon'],
    'English': ['english', 'pop', 'billboard', 'hollywood'],
    'Tamil': ['tamil', 'kollywood', 'anirudh'],
    'Telugu': ['telugu', 'tollywood', 'thaman'],
    'Bengali': ['bengali', 'bangla'],
    'Marathi': ['marathi'],
    'Gujarati': ['gujarati', 'garba'],
    'Bhojpuri': ['bhojpuri'],
    'Haryanvi': ['haryanvi'],
    'Malayalam': ['malayalam'],
    'Kannada': ['kannada'],
    'Korean': ['k-pop', 'kpop', 'korean'],
  };

  static const Map<String, List<String>> _moodKeywords = {
    'Romantic': ['romantic', 'love', 'romance', 'ishq', 'pyaar', 'dil'],
    'Chill': ['chill', 'lofi', 'lo-fi', 'relax', 'peaceful', 'calm', 'night'],
    'Party': ['party', 'dance', 'club', 'dj', 'nach', 'bhangra'],
    'Sad': ['sad', 'heartbreak', 'breakup', 'dard', 'alone', 'crying'],
    'Workout': ['workout', 'gym', 'pump', 'motivation', 'fitness', 'energy'],
    'Happy': ['happy', 'feel good', 'joy', 'smile', 'upbeat'],
    'Devotional': ['bhajan', 'aarti', 'spiritual', 'prayer', 'devotion'],
  };

  /// Returns the best-guess genre tags for a track.
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

  /// Detects matching languages from title/artist/query text.
  Set<String> detectLanguages(String text) {
    final lower = text.toLowerCase();
    final result = <String>{};
    for (final entry in _languageKeywords.entries) {
      if (entry.value.any(lower.contains)) {
        result.add(entry.key);
      }
    }
    return result;
  }

  /// Detects matching moods from title/artist/query text.
  Set<String> detectMoods(String text) {
    final lower = text.toLowerCase();
    final result = <String>{};
    for (final entry in _moodKeywords.entries) {
      if (entry.value.any(lower.contains)) {
        result.add(entry.key);
      }
    }
    return result;
  }

  /// Jaccard tag-overlap similarity between two sets. Returns 0.0-1.0.
  double similarity(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    return union == 0 ? 0.0 : intersection / union;
  }
}
