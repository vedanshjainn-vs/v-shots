// ════════════════════════════════════════════════
// V Shots — Recommendation Engine: Candidate Generation (Phase 7, Part J)
// ════════════════════════════════════════════════
//
// Generates raw candidate SEARCH QUERIES (not tracks directly — actual
// track fetching still goes through the existing MusicRepository ->
// ProviderManager -> YouTubeMusicProvider chain from the Provider
// Architecture task, per this task's own "DO NOT change the current
// YouTube integration" constraint) from multiple real sources, per
// Part J's list:
//   1. Similar artists       -> topArtists' "similar to X" queries
//   2. Similar titles/tags   -> genre-tag-based queries
//   3. Recently played patterns -> topArtists' own-catalog queries
//   4. Liked music           -> queries built from liked tracks' artists
//   5. Search behavior       -> the user's own recent search queries
//   6. Trending content      -> a fixed trending query
//   7. New content           -> a fixed "new releases" query
//   8. Exploration candidates -> genre/mood queries OUTSIDE the user's
//      established top genres, for real discovery (Part O)
//
// HONEST SCOPE NOTE: "candidates" here means SEARCH QUERIES whose
// results become candidate tracks after going through the existing
// YoutubeMusicMapper filter (podcast/compilation/duration exclusion,
// already enforced by the Provider layer — Part U's requirement is
// satisfied by REUSING that existing filter, not reimplementing it).
// This is not pretending to have a track-level catalog index YouTube
// doesn't expose an API for.
// ════════════════════════════════════════════════

import 'dart:math';

import '../storage/local_library.dart';
import 'recommendation_config.dart';
import 'taste_profile.dart';

enum CandidateSource {
  similarArtist,
  genreTag,
  recentlyPlayedPattern,
  likedMusic,
  searchBehavior,
  trending,
  newContent,
  exploration,
}

/// One candidate query plus the source that generated it — the source
/// is threaded through to `RecommendationScorer` so contextMatch/
/// novelty scoring can weigh candidates differently depending on where
/// they came from (an exploration candidate SHOULD score high on
/// novelty even with zero user affinity, for example).
class CandidateQuery {
  const CandidateQuery({
    required this.query,
    required this.source,
    this.seedArtist,
    this.seedGenre,
  });

  final String query;
  final CandidateSource source;
  final String? seedArtist;
  final String? seedGenre;
}

class CandidateGenerator {
  CandidateGenerator({this.config = RecommendationConfig.defaultConfig});

  final RecommendationConfig config;
  final _random = Random();

  static const _genreDiscoveryTemplates = [
    'artists similar to {artist}',
    '{artist} type songs',
    'if you like {artist}',
    'songs like {artist} playlist',
  ];

  static const _allKnownGenreQueries = {
    'Bollywood': 'bollywood hit songs official audio',
    'Punjabi': 'punjabi hit songs official audio',
    'Hindi': 'hindi songs official audio',
    'English': 'english pop songs official audio',
    'Hip-Hop': 'hip hop rap songs official audio',
    'EDM': 'edm dance party songs official audio',
    'Chill': 'chill lofi songs official audio',
    'Romantic': 'romantic songs official audio',
    'Sad': 'sad songs that hit different',
    'Workout': 'workout gym motivation songs',
    'K-Pop': 'k-pop hits official',
    'Indie': 'indie songs official audio',
    'RnB': 'rnb slow jams',
  };

  /// Generates a pool of candidate queries from every real source
  /// available. [excludeIds]/session-level de-dup happens downstream
  /// (against actual fetched tracks) — this stage just decides WHICH
  /// QUERIES to try, already avoiding obvious duplicates (Part J: "Avoid
  /// returning the same songs repeatedly" — achieved by varying which
  /// query is picked, not by only ever using one).
  List<CandidateQuery> generate(TasteProfile profile, {int count = 12}) {
    final candidates = <CandidateQuery>[];

    if (!profile.hasEnoughHistoryForPersonalization) {
      // Part M — Cold Start: no meaningful history yet. Use trending +
      // regional/global popularity + genre diversity + exploration,
      // never an empty feed.
      return _coldStartCandidates(count: count);
    }

    // 1. Similar artists (content-based discovery seeded from top
    // artists, not just their own catalog).
    final topArtists = profile.topArtists.take(5).toList();
    for (final artist in topArtists) {
      final template =
          _genreDiscoveryTemplates[_random.nextInt(_genreDiscoveryTemplates.length)];
      candidates.add(CandidateQuery(
        query: template.replaceAll('{artist}', artist),
        source: CandidateSource.similarArtist,
        seedArtist: artist,
      ));
    }

    // 2. Genre/tag-based candidates from the user's real top genres.
    for (final genre in profile.topGenres.take(3)) {
      final q = _allKnownGenreQueries[genre];
      if (q != null) {
        candidates.add(CandidateQuery(
          query: q,
          source: CandidateSource.genreTag,
          seedGenre: genre,
        ));
      }
    }

    // 3. Recently played patterns — top artists' own catalog.
    for (final artist in topArtists.take(3)) {
      candidates.add(CandidateQuery(
        query: '$artist songs official audio',
        source: CandidateSource.recentlyPlayedPattern,
        seedArtist: artist,
      ));
    }

    // 4. Liked music — real LocalLibrary liked-songs artists (a signal
    // the pre-Phase-7 engine never used directly for query generation
    // at all, only via the merged recentlyPlayed-based affinity).
    final likedArtists = LocalLibrary.instance.likedSongs.value
        .map((t) => t['artist'] as String? ?? '')
        .where((a) => a.isNotEmpty)
        .toSet()
        .take(3);
    for (final artist in likedArtists) {
      candidates.add(CandidateQuery(
        query: '$artist best songs',
        source: CandidateSource.likedMusic,
        seedArtist: artist,
      ));
    }

    // 5. Search behavior — the user's own real recent searches are a
    // strong, direct signal of current interest.
    final recentSearches = LocalLibrary.instance.recentSearches.value
        .map((s) => s['query'] as String? ?? '')
        .where((q) => q.isNotEmpty)
        .take(2);
    for (final q in recentSearches) {
      candidates.add(CandidateQuery(query: q, source: CandidateSource.searchBehavior));
    }

    // 6. Trending content — always included, a real, live signal
    // (matches Home's existing "Trending Now" query).
    candidates.add(const CandidateQuery(
      query: 'trending music today official audio',
      source: CandidateSource.trending,
    ));

    // 7. New content.
    candidates.add(const CandidateQuery(
      query: 'new music releases official audio',
      source: CandidateSource.newContent,
    ));

    // 8. Exploration — genres OUTSIDE the user's current top genres,
    // for real discovery rather than an echo chamber (Part O).
    final unexploredGenres = _allKnownGenreQueries.keys
        .where((g) => !profile.topGenres.take(3).contains(g))
        .toList()
      ..shuffle(_random);
    for (final genre in unexploredGenres.take(2)) {
      candidates.add(CandidateQuery(
        query: _allKnownGenreQueries[genre]!,
        source: CandidateSource.exploration,
        seedGenre: genre,
      ));
    }

    candidates.shuffle(_random);
    return candidates.take(count).toList();
  }

  /// Part M — Cold Start. No play history yet: trending + regional
  /// popularity (Bollywood/Hindi/Punjabi as the app's established
  /// regional defaults, matching Home's own existing section order)
  /// + global popularity + genre diversity + exploration. Never
  /// returns an empty list.
  List<CandidateQuery> _coldStartCandidates({required int count}) {
    final pool = <CandidateQuery>[
      const CandidateQuery(
          query: 'trending music today official audio', source: CandidateSource.trending),
      const CandidateQuery(
          query: 'global top hits official music', source: CandidateSource.trending),
      const CandidateQuery(
          query: 'bollywood hit songs official audio',
          source: CandidateSource.exploration,
          seedGenre: 'Bollywood'),
      const CandidateQuery(
          query: 'hindi songs official audio',
          source: CandidateSource.exploration,
          seedGenre: 'Hindi'),
      const CandidateQuery(
          query: 'punjabi hit songs official audio',
          source: CandidateSource.exploration,
          seedGenre: 'Punjabi'),
      const CandidateQuery(
          query: 'english pop songs official audio',
          source: CandidateSource.exploration,
          seedGenre: 'English'),
      const CandidateQuery(
          query: 'hip hop rap songs official audio',
          source: CandidateSource.exploration,
          seedGenre: 'Hip-Hop'),
      const CandidateQuery(
          query: 'edm dance party songs official audio',
          source: CandidateSource.exploration,
          seedGenre: 'EDM'),
      const CandidateQuery(
          query: 'new music releases official audio', source: CandidateSource.newContent),
    ];
    pool.shuffle(_random);
    return pool.take(count).toList();
  }
}
