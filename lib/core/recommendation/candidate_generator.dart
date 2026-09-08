// ═════════════════════════════════════════════════════════════════════════
// V Shots — Recommendation Engine: Candidate Generation (V2 Engine)
// ═════════════════════════════════════════════════════════════════════════

import 'dart:math';

import '../storage/local_library.dart';
import '../storage/personalization_store.dart';
import 'recommendation_config.dart';
import 'taste_profile.dart';

enum CandidateSource {
  similarArtist,
  genreTag,
  recentlyPlayedPattern,
  likedMusic,
  searchBehavior,
  playlistTheme,
  trending,
  newContent,
  exploration,
}

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
    'Devotional': 'bhajan devotional songs official audio',
    '90s': '90s hindi evergreen songs official',
    '2000s': '2000s bollywood hit songs official',
  };

  static const _languageQueries = {
    'Hindi': 'hindi songs official audio',
    'Punjabi': 'punjabi songs official audio',
    'English': 'english pop songs official audio',
    'Tamil': 'tamil hit songs official audio',
    'Telugu': 'telugu hit songs official audio',
    'Bengali': 'bengali hit songs official audio',
    'Marathi': 'marathi hit songs official audio',
    'Gujarati': 'gujarati garba folk songs official',
  };

  List<CandidateQuery> generate(TasteProfile profile, {int count = 12}) {
    if (!profile.hasEnoughHistoryForPersonalization) {
      return _coldStartCandidates(count: count, profile: profile);
    }

    final candidates = <CandidateQuery>[];
    final topArtists = profile.topArtists.take(5).toList();

    // 1. Search Behavior — Explicit search queries
    final topSearches = profile.topSearches.take(3).toList();
    for (final q in topSearches) {
      candidates.add(
        CandidateQuery(
          query: '$q songs official audio',
          source: CandidateSource.searchBehavior,
          seedArtist: q,
        ),
      );
    }

    // 2. Similar artists
    for (final artist in topArtists) {
      final template = _genreDiscoveryTemplates[_random.nextInt(
        _genreDiscoveryTemplates.length,
      )];
      candidates.add(
        CandidateQuery(
          query: template.replaceAll('{artist}', artist),
          source: CandidateSource.similarArtist,
          seedArtist: artist,
        ),
      );
    }

    // 3. Genre/tag-based candidates from top genres
    for (final genre in profile.topGenres.take(3)) {
      final q = _allKnownGenreQueries[genre];
      if (q != null) {
        candidates.add(
          CandidateQuery(
            query: q,
            source: CandidateSource.genreTag,
            seedGenre: genre,
          ),
        );
      }
    }

    // 4. Recently played patterns
    for (final artist in topArtists.take(3)) {
      candidates.add(
        CandidateQuery(
          query: '$artist songs official audio',
          source: CandidateSource.recentlyPlayedPattern,
          seedArtist: artist,
        ),
      );
    }

    // 5. Liked music artists
    final likedArtists = LocalLibrary.instance.likedSongs.value
        .map((t) => t['artist'] as String? ?? '')
        .where((a) => a.isNotEmpty)
        .toSet()
        .take(3);
    for (final artist in likedArtists) {
      candidates.add(
        CandidateQuery(
          query: '$artist best songs',
          source: CandidateSource.likedMusic,
          seedArtist: artist,
        ),
      );
    }

    // 6. Playlist Theme candidates
    for (final pl in profile.playlistAffinity.keys.take(2)) {
      candidates.add(
        CandidateQuery(
          query: '$pl songs official audio',
          source: CandidateSource.playlistTheme,
        ),
      );
    }

    // 7. Trending content
    candidates.add(
      const CandidateQuery(
        query: 'trending music today official audio',
        source: CandidateSource.trending,
      ),
    );

    // 8. New content
    candidates.add(
      const CandidateQuery(
        query: 'new music releases official audio',
        source: CandidateSource.newContent,
      ),
    );

    // 9. Controlled exploration — strictly outside user's current top genres
    final userTopGenres = profile.topGenres.toSet();
    final unexploredGenres = _allKnownGenreQueries.keys
        .where((g) => !userTopGenres.contains(g))
        .toList()
      ..shuffle(_random);
    for (final genre in unexploredGenres.take(2)) {
      candidates.add(
        CandidateQuery(
          query: _allKnownGenreQueries[genre]!,
          source: CandidateSource.exploration,
          seedGenre: genre,
        ),
      );
    }

    candidates.shuffle(_random);
    return candidates.take(count).toList();
  }

  List<CandidateQuery> _coldStartCandidates({
    required int count,
    TasteProfile? profile,
  }) {
    final store = PersonalizationStore.instance;
    final ordered = <CandidateQuery>[];
    final seenQueries = <String>{};

    void addPref(String query, CandidateSource source, String? seed) {
      if (query.isEmpty || !seenQueries.add(query)) return;
      ordered.add(
        CandidateQuery(query: query, source: source, seedGenre: seed),
      );
    }

    // Explicit search queries take immediate priority even during cold start
    if (profile != null) {
      for (final q in profile.topSearches) {
        addPref('$q songs official audio', CandidateSource.searchBehavior, q);
      }
      for (final a in profile.topArtists) {
        addPref('$a songs official audio', CandidateSource.recentlyPlayedPattern, a);
      }
    }

    // 1. Preferred genres first (stated taste from onboarding)
    for (final genre in store.preferredGenres) {
      final q = _allKnownGenreQueries[genre];
      if (q != null) addPref(q, CandidateSource.genreTag, genre);
    }

    // 2. Preferred languages
    for (final lang in store.preferredLanguages) {
      final q = _languageQueries[lang];
      if (q != null) addPref(q, CandidateSource.exploration, lang);
    }

    // 3. Safe broad discovery defaults
    final defaults = <CandidateQuery>[
      const CandidateQuery(
        query: 'trending music today official audio',
        source: CandidateSource.trending,
      ),
      const CandidateQuery(
        query: 'global top hits official music',
        source: CandidateSource.trending,
      ),
      const CandidateQuery(
        query: 'bollywood hit songs official audio',
        source: CandidateSource.exploration,
        seedGenre: 'Bollywood',
      ),
      const CandidateQuery(
        query: 'hindi songs official audio',
        source: CandidateSource.exploration,
        seedGenre: 'Hindi',
      ),
      const CandidateQuery(
        query: 'punjabi hit songs official audio',
        source: CandidateSource.exploration,
        seedGenre: 'Punjabi',
      ),
      const CandidateQuery(
        query: 'english pop songs official audio',
        source: CandidateSource.exploration,
        seedGenre: 'English',
      ),
      const CandidateQuery(
        query: 'hip hop rap songs official audio',
        source: CandidateSource.exploration,
        seedGenre: 'Hip-Hop',
      ),
      const CandidateQuery(
        query: 'edm dance party songs official audio',
        source: CandidateSource.exploration,
        seedGenre: 'EDM',
      ),
      const CandidateQuery(
        query: 'new music releases official audio',
        source: CandidateSource.newContent,
      ),
    ]..shuffle(_random);

    for (final candidate in defaults) {
      if (seenQueries.add(candidate.query)) ordered.add(candidate);
    }

    return ordered.take(count).toList();
  }
}
