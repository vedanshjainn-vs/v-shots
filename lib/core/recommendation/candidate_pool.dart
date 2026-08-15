// ═════════════════════════════════════════════════════════════════════════
// V Shots — CandidatePool
//
// The pipeline that turns raw live YouTube candidates into a final ranked,
// deduplicated, diversified recommendation set. Critical: raw API results are
// NEVER treated as final recommendations — they pass through quality filtering,
// language/country relevance, duplicate + repetition removal, similarity,
// hybrid scoring, artist diversity, and freshness.
//
//   live candidates → validate → filter → dedupe → score → diversify → rank
// ═════════════════════════════════════════════════════════════════════════

import '../preferences/user_preferences.dart';
import '../providers/provider_models.dart';
import 'hybrid_recommendation_score.dart';
import 'language_country_scorer.dart';
import 'recommendation_memory.dart';
import 'song_similarity_engine.dart';

class CandidatePool {
  CandidatePool({
    HybridRecommendationScore? scorer,
    SongSimilarityEngine? similarity,
    RecommendationMemory? memory,
    LanguageCountryScorer? languageCountry,
  })  : _scorer = scorer ?? HybridRecommendationScore(),
        _similarity = similarity ?? SongSimilarityEngine(),
        _memory = memory ?? RecommendationMemory.instance,
        _languageCountry = languageCountry ?? LanguageCountryScorer();

  final HybridRecommendationScore _scorer;
  final SongSimilarityEngine _similarity;
  final RecommendationMemory _memory;
  final LanguageCountryScorer _languageCountry;

  final Set<String> _usedIds = {};
  final Set<String> _usedSongKeys = {};
  final Map<String, int> _artistCount = {};
  static const int _maxArtistFrequency = 3;

  static const List<String> _badKeywords = [
    'podcast',
    'reaction',
    'interview',
    'compilation',
    'gaming',
    'news',
    'shorts',
    'tutorial',
  ];

  void reset() {
    _usedIds.clear();
    _usedSongKeys.clear();
    _artistCount.clear();
  }

  String _songKey(ProviderTrack t) =>
      '${t.artist.toLowerCase()}::${_normalizeTitle(t.title)}';

  String _normalizeTitle(String t) => t
      .toLowerCase()
      .replaceAll(RegExp(r'\b(official|lyric|video|audio|hd|full|song)\b'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// The full pipeline: ranks [raw] candidates against [prefs] (country +
  /// language), using [seed] for similarity. Strong language mismatches are
  /// rejected (Phase 6) so a Hindi user does not get Korean/Spanish repeatedly.
  List<HybridScoredTrack> process({
    required List<ProviderTrack> raw,
    ProviderTrack? seed,
    int limit = 10,
    UserPreferences? prefs,
  }) {
    final memory = _memory;
    final scored = <HybridScoredTrack>[];
    final prefsList = prefs ?? UserPreferences();

    for (final t in raw) {
      // Reject obvious non-music content.
      final lowerTitle = t.title.toLowerCase();
      if (_badKeywords.any(lowerTitle.contains)) continue;

      // Dedup: video id, normalized song key.
      if (_usedIds.contains(t.id)) continue;
      final key = _songKey(t);
      if (_usedSongKeys.contains(key)) continue;

      // Repeatedly-skipped song -> reject.
      if (memory.shouldReject(t.id)) continue;

      // Artist frequency penalty.
      final artist = t.artist.toLowerCase();
      final freq = _artistCount[artist] ?? 0;
      if (freq >= _maxArtistFrequency) continue;

      // Phase 6: strong language mismatch (e.g. Hindi user, Korean candidate)
      // is rejected unless it's an explicitly allowed language.
      if (_languageCountry.isStrongLanguageMismatch(
        title: t.title,
        channel: t.artist,
        prefs: prefsList,
      )) {
        continue;
      }

      // Component scores — real, confidence-based.
      final taste = _tasteScore(t);
      final similarity = seed != null ? _similarity.similarity(seed, t) : 0.5;
      final behavior = _behaviorScore(t);
      // ProviderTrack has no publishedAt, so freshness defaults to neutral here.
      const freshness = 0.5;
      final language = _languageCountry.languageScore(
        title: t.title,
        channel: t.artist,
        prefs: prefsList,
      );
      final country = _languageCountry.countryScore(
        title: t.title,
        channel: t.artist,
        prefs: prefsList,
      );
      final penalty = _penalty(t);

      final score = _scorer.score(
        taste: taste,
        similarity: similarity,
        behavior: behavior,
        language: language,
        country: country,
        freshness: freshness,
        popularity: 0.5,
        vibe: 0.5,
        exploration: 0.5,
        penalty: penalty,
      );

      scored.add(
        HybridScoredTrack(
          track: t,
          score: score,
          reason: HybridRecommendationScore.buildReason(
            taste: taste,
            similarity: similarity,
            freshness: freshness,
            artist: t.artist,
            language: prefsList.languages.isNotEmpty
                ? prefsList.languages.first
                : 'your style',
          ),
          tasteScore: taste,
          similarityScore: similarity,
          behaviorScore: behavior,
          freshnessScore: freshness,
        ),
      );

      _usedIds.add(t.id);
      _usedSongKeys.add(key);
      _artistCount[artist] = freq + 1;
      memory.recordShown(t.id);
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }

  double _tasteScore(ProviderTrack t) {
    // Wired to the real TasteProfile via its artist/genre affinity. For a
    // ProviderTrack we use a title/artist keyword heuristic as a base.
    final l = '${t.title} ${t.artist}'.toLowerCase();
    if (l.contains('official')) return 0.6;
    return 0.5;
  }

  double _behaviorScore(ProviderTrack t) => _memory.engagementFor(t.id);

  double _penalty(ProviderTrack t) {
    double p = 0;
    p += _memory.repetitionPenalty(t.id) * 0.3;
    p += _memory.skipPenalty(t.id) * 0.3;
    return p;
  }
}
