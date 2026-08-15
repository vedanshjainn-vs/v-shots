// ═════════════════════════════════════════════════════════════════════════
// V Shots — ContentPersonalizationService (Phase 3, 4, 5, 11)
//
// Centralized query-generation engine. EVERY Home and Discover query must pass
// through here so country + language + genre + vibe constraints come from ONE
// source of truth (UserPreferences), never decided independently by widgets.
//
// Strategy (Phase 5 recommended distribution):
//   70% preferred country/language content
//   20% global content matching taste
//   10% exploration
// These ratios are configurable.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:math';
import 'user_preferences.dart';

class ContentPersonalizationService {
  ContentPersonalizationService._();
  static final ContentPersonalizationService instance =
      ContentPersonalizationService._();

  final _random = Random();

  // Phase 5 configurable distribution.
  double primaryWeight = 0.70;
  double globalWeight = 0.20;
  double explorationWeight = 0.10;

  /// Map of country -> default languages (used when the user hasn't picked).
  static const Map<String, List<String>> _countryLanguages = {
    'India': ['Hindi', 'English'],
    'United States': ['English'],
    'United Kingdom': ['English'],
    'Canada': ['English'],
    'Australia': ['English'],
    'Pakistan': ['Urdu', 'English'],
    'Bangladesh': ['Bengali', 'English'],
    'Nepal': ['Nepali', 'English'],
    'UAE': ['English', 'Arabic'],
    'Saudi Arabia': ['Arabic', 'English'],
  };

  /// Language -> YouTube query keyword + catalog category hint.
  static const Map<String, String> _langQuery = {
    'Hindi': 'hindi',
    'Punjabi': 'punjabi',
    'English': 'english',
    'Tamil': 'tamil',
    'Telugu': 'telugu',
    'Bengali': 'bengali',
    'Marathi': 'marathi',
    'Gujarati': 'gujarati',
    'Kannada': 'kannada',
    'Malayalam': 'malayalam',
    'Urdu': 'urdu',
    'Nepali': 'nepali',
    'Arabic': 'arabic',
  };

  /// Vibe -> query keyword(s).
  static const Map<String, List<String>> _vibeQueries = {
    'Romantic': ['romantic', 'love songs'],
    'Heartbroken & Sad': ['sad', 'heartbreak', 'emotional'],
    'Chill': ['chill', 'lofi', 'ambient', 'relax'],
    'Workout': ['workout', 'gym', 'high energy', 'motivation'],
    'Party': ['party', 'dance', 'celebration'],
    'Devotional': ['devotional', 'bhajan', 'aarti'],
    'Focus & Study': ['lofi', 'study', 'focus', 'instrumental'],
    'Road Trip Drive': ['road trip', 'driving', 'travel'],
    'Bollywood': ['bollywood'],
    'Punjabi': ['punjabi'],
    'Hip-Hop': ['hip hop', 'rap'],
    'EDM': ['edm', 'electronic', 'dance'],
    'Indie': ['indie', 'acoustic'],
    'Lo-fi': ['lofi', 'chill beats'],
    'Workout & Hype': ['gym', 'hype', 'workout'],
    'Night Drive': ['night drive', 'late night', 'drive'],
    'Throwback': ['90s', 'retro', 'classic', 'nostalgia'],
    'Global Pop': ['pop', 'billboard', 'international'],
    'K-pop': ['k-pop', 'korean pop'],
    'Classical': ['classical', 'instrumental'],
  };

  /// Returns the user's effective languages: explicit picks, else country
  /// defaults, else English.
  List<String> effectiveLanguages(UserPreferences prefs) {
    if (prefs.languages.isNotEmpty) return prefs.languages;
    final fromCountry = _countryLanguages[prefs.country];
    if (fromCountry != null && fromCountry.isNotEmpty) return fromCountry;
    return const ['English'];
  }

  /// Builds a Home/Discover section query that is country + language aware.
  ///
  /// [categoryIntent] = e.g. 'latest songs', 'romantic songs', 'workout songs'.
  /// When [forcePreferredLanguages] is true (strongly-constrained sections),
  /// the query is built from the user's preferred languages only.
  String buildQuery(
    UserPreferences prefs, {
    required String categoryIntent,
    bool forcePreferredLanguages = false,
  }) {
    final langs = effectiveLanguages(prefs);
    final primaryLang = langs.isNotEmpty ? langs.first : 'English';
    final langKw = _langQuery[primaryLang] ?? primaryLang.toLowerCase();

    // A strong, language-aware intent: "hindi romantic songs" / "punjabi latest songs".
    return '$langKw $categoryIntent';
  }

  /// Builds a vibe query that combines the selected vibe with preferred
  /// language context (used by Discover).
  String buildVibeQuery(
    UserPreferences prefs,
    String vibe, {
    bool forcePreferredLanguages = false,
  }) {
    final langs = effectiveLanguages(prefs);
    final primaryLang = langs.isNotEmpty ? langs.first : 'English';
    final langKw = _langQuery[primaryLang] ?? primaryLang.toLowerCase();
    final vibeKws = _vibeQueries[vibe] ?? [vibe];
    final vibeKw = vibeKws.join(' ');
    return '$langKw $vibeKw';
  }

  /// Cold-start query set (Phase 15): no listening history yet, so blend
  /// country + languages + genres + trending.
  List<String> coldStartQueries(UserPreferences prefs, {int count = 6}) {
    final langs = effectiveLanguages(prefs);
    final results = <String>[];
    for (final lang in langs.take(3)) {
      final kw = _langQuery[lang] ?? lang.toLowerCase();
      results.add('$kw latest songs official');
      results.add('$kw trending hits');
    }
    for (final g in prefs.genres.take(3)) {
      results.add('$g songs official audio');
    }
    // Ensure we return at least `count` distinct-ish queries.
    if (results.length < count) {
      results.add('top trending music today');
    }
    return results.take(count).toList();
  }

  /// Phase 5 distribution selector: returns 'primary' | 'global' | 'exploration'
  /// based on the configured weights.
  String pickContentBucket() {
    final roll = _random.nextDouble();
    if (roll < primaryWeight) return 'primary';
    if (roll < primaryWeight + globalWeight) return 'global';
    return 'exploration';
  }
}
