// ═════════════════════════════════════════════════════════════════════════
// V Shots — LiveMusicDiscoveryService
//
// The LIVE music discovery engine for Home. Uses the official YouTube Data API
// (via YouTubeRepository) to fetch fresh, regional, language-aware content for
// each Home section, instead of the old stale/fallback catalog.
//
// PRIORITY:  LIVE → CACHED_LIVE → FALLBACK (fallback only as a last resort).
// Every result tracks its source so the debug layer can show whether a section
// is actually live.
//
// No scraping, no HTML parsing, no undocumented YouTube Music APIs, no stream
// extraction. Playback remains official YouTube IFrame.
// ═════════════════════════════════════════════════════════════════════════

import '../preferences/content_personalization_service.dart';
import '../preferences/user_preferences.dart';

/// Where a section's content actually came from.
enum ContentSource { live, cachedLive, fallback }

/// A normalized, validated, deduplicated Home section result.
class HomeSectionResult {
  HomeSectionResult({
    required this.title,
    required this.tracks,
    required this.source,
    this.fetchedAt,
    this.query = '',
    this.candidateCount = 0,
    this.validCount = 0,
    this.dedupedCount = 0,
  });

  final String title;
  final List<Map<String, dynamic>> tracks;
  final ContentSource source;
  final DateTime? fetchedAt;
  final String query;
  final int candidateCount;
  final int validCount;
  final int dedupedCount;

  bool get isLive => source == ContentSource.live;
}

/// Tracks live, region/language-aware query variants for a section intent.
class LiveMusicDiscoveryService {
  LiveMusicDiscoveryService();

  /// Region code per country (YouTube Data API regionCode param).
  static const Map<String, String> _regionCode = {
    'India': 'IN',
    'United States': 'US',
    'United Kingdom': 'GB',
    'Canada': 'CA',
    'Australia': 'AU',
    'Pakistan': 'PK',
    'Bangladesh': 'BD',
    'Nepal': 'NP',
    'UAE': 'AE',
    'Saudi Arabia': 'SA',
  };

  /// relevanceLanguage per preferred language (YouTube relevanceLanguage param).
  static const Map<String, String> _langCode = {
    'Hindi': 'hi',
    'Punjabi': 'pa',
    'English': 'en',
    'Tamil': 'ta',
    'Telugu': 'te',
    'Bengali': 'bn',
    'Marathi': 'mr',
    'Gujarati': 'gu',
    'Urdu': 'ur',
    'Nepali': 'ne',
    'Arabic': 'ar',
  };

  /// Builds a set of live query variants for a section intent, from the user's
  /// country + preferred languages (never a single generic query).
  List<String> buildLiveQueries(UserPreferences prefs, String intent) {
    final svc = ContentPersonalizationService.instance;
    final langs = svc.effectiveLanguages(prefs);
    final region = _regionCode[prefs.country];
    final primaryLang = langs.isNotEmpty ? langs.first : 'English';

    final queries = <String>[];
    // Primary: <language> + intent
    queries.add('$primaryLang $intent');
    // Official video variant
    queries.add('$primaryLang $intent official music video');
    // Fresh variant
    queries.add('$primaryLang latest $intent');
    // If we have a second language, include it too
    if (langs.length > 1) {
      queries.add('${langs[1]} $intent');
    }
    // Regional query (unused region var kept for clarity in logs)
    if (region != null) {
      queries.add('$primaryLang $intent $region');
    }
    return queries.toSet().toList();
  }

  /// The country region code, or null.
  String? regionCodeFor(UserPreferences prefs) => _regionCode[prefs.country];

  /// The relevance language code for the top preferred language.
  String relevanceLanguageFor(UserPreferences prefs) {
    final svc = ContentPersonalizationService.instance;
    final langs = svc.effectiveLanguages(prefs);
    final top = langs.isNotEmpty ? langs.first : 'English';
    return _langCode[top] ?? 'en';
  }

  /// Builds a Data-API-friendly query map for the given intent + prefs,
  /// used by the repository's live search.
  Map<String, String> liveParams(UserPreferences prefs, String intent) {
    final params = <String, String>{
      'q': buildLiveQueries(prefs, intent).first,
    };
    final region = regionCodeFor(prefs);
    if (region != null) params['regionCode'] = region;
    params['relevanceLanguage'] = relevanceLanguageFor(prefs);
    params['videoCategoryId'] = '10'; // Music
    return params;
  }
}
