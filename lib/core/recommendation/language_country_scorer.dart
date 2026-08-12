// ═════════════════════════════════════════════════════════════════════════
// V Shots — LanguageCountryScorer (Phases 4, 5, 6)
//
// Confidence-based language + country scoring against the user's preferences.
// It does NOT pretend Latin-script Hindi is always detectable; unknown stays
// UNKNOWN and scores neutral, never forced to a wrong value. Country score is a
// real component derived from the user's preferred country + the language/country
// association of the candidate (unknown country -> neutral, not fabricated).
// ═════════════════════════════════════════════════════════════════════════

import '../preferences/user_preferences.dart';

/// Script/script+keyword detection signals. Confidence is heuristic.
class LanguageCountryScorer {
  // country -> default languages (association).
  static const Map<String, List<String>> _countryLanguages = {
    'India': [
      'Hindi',
      'English',
      'Punjabi',
      'Tamil',
      'Telugu',
      'Bengali',
      'Marathi',
      'Gujarati',
      'Kannada',
      'Malayalam',
      'Urdu'
    ],
    'United States': ['English', 'Spanish'],
    'United Kingdom': ['English'],
    'Canada': ['English', 'French'],
    'Australia': ['English'],
    'Pakistan': ['Urdu', 'English', 'Punjabi'],
    'Bangladesh': ['Bengali', 'English'],
    'Nepal': ['Nepali', 'English'],
    'UAE': ['English', 'Arabic', 'Hindi', 'Urdu'],
    'Saudi Arabia': ['Arabic', 'English'],
  };

  /// language -> title/channel keyword signals + script ranges.
  static const Map<String, List<String>> _langKeywords = {
    'Hindi': ['hindi', 'bollywood', 'arijit', 'hindi song'],
    'Punjabi': ['punjabi', 'diljit', 'aujla', 'shubh', 'bhangra'],
    'English': ['english', 'pop song', 'official music video'],
    'Tamil': ['tamil', 'anirudh'],
    'Telugu': ['telugu', 'tollywood'],
    'Malayalam': ['malayalam'],
    'Kannada': ['kannada'],
    'Bengali': ['bengali', 'bangla'],
    'Marathi': ['marathi'],
    'Gujarati': ['gujarati', 'garba'],
    'Urdu': ['urdu', 'ghazal', 'nusrat'],
    'Nepali': ['nepali'],
    'Spanish': ['spanish', 'latin', 'reggaeton', 'español'],
    'Korean': ['k-pop', 'kpop', 'korean'],
    'Arabic': ['arabic', 'arab'],
  };

  /// Detects the most likely language of a title/channel, with confidence.
  ///
  /// Returns (language, confidence). Unknown -> ('', 0). Latin-script Hindi is
  /// only tagged Hindi when a strong Hindi keyword is present (e.g. the channel
  /// name or title carries a Hindi marker); otherwise UNKNOWN.
  ({String language, double confidence}) detectLanguage(
    String title,
    String channel,
  ) {
    final haystack = '${title.toLowerCase()} ${channel.toLowerCase()}';

    // Highest-confidence: a distinctive language marker keyword.
    double best = 0;
    String bestLang = '';
    for (final entry in _langKeywords.entries) {
      final hits = entry.value.where(haystack.contains).length;
      if (hits > 0) {
        final score = 0.4 + (hits * 0.2);
        if (score > best) {
          best = score.clamp(0.0, 0.95);
          bestLang = entry.key;
        }
      }
    }
    return (language: bestLang, confidence: best);
  }

  /// Language score in [0,1]: how well the candidate's detected language matches
  /// the user's preferred languages. Unknown candidate -> neutral 0.4 (not
  /// forced to English, not 0).
  double languageScore({
    required String title,
    required String channel,
    required UserPreferences prefs,
  }) {
    final detected = detectLanguage(title, channel);
    if (detected.language.isEmpty) return 0.4; // unknown -> neutral
    final prefsList = prefs.languages.isNotEmpty
        ? prefs.languages
        : (_countryLanguages[prefs.country] ?? const ['English']);
    return prefsList.contains(detected.language) ? detected.confidence : 0.15;
  }

  /// Country score in [0,1]: whether the candidate's language/country aligns with
  /// the user's preferred country. Unknown -> neutral 0.4 (never fabricated).
  double countryScore({
    required String title,
    required String channel,
    required UserPreferences prefs,
  }) {
    final detected = detectLanguage(title, channel);
    final countryLangs = _countryLanguages[prefs.country] ?? const [];
    if (detected.language.isEmpty) return 0.4; // unknown -> neutral
    if (countryLangs.contains(detected.language)) return detected.confidence;
    // A strongly-detected language outside the preferred country still gets a
    // small cross-taste credit, not zero (country is a preference, not censorship).
    return 0.2;
  }

  /// Whether a candidate's language is an obvious mismatch (e.g. user is Hindi,
  /// candidate is clearly Korean/Spanish/Arabic) -> used as a rejection signal.
  bool isStrongLanguageMismatch({
    required String title,
    required String channel,
    required UserPreferences prefs,
  }) {
    final detected = detectLanguage(title, channel);
    if (detected.language.isEmpty) return false; // unknown can't be a mismatch
    final prefsList = prefs.languages.isNotEmpty
        ? prefs.languages
        : (_countryLanguages[prefs.country] ?? const ['English']);
    return !prefsList.contains(detected.language);
  }
}
