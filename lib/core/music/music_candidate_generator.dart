// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music candidate generator (pool-based, quota-driven)
// ═════════════════════════════════════════════════════════════════════════════
//
// Generates candidate pools (favorite/similar artists, genres, languages,
// recent, trending, new releases, regional, mood, exploration) with per-pool
// QUOTAS, then fetches through the shared search function. Each candidate is
// entity-resolved so the engine ranks MUSIC identities, never raw uploads.
// Cold start (empty profile) → trending/new/regional/exploration only.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:math';

import '../providers/provider_models.dart';
import '../recommendation/music_recommendation_config.dart';
import '../recommendation/music_recommendation_context.dart';
import '../recommendation/music_user_profile.dart';
import 'music_candidate.dart';
import 'music_entity_resolver.dart';
import 'music_validator.dart';

typedef MusicSearch = Future<List<Map<String, dynamic>>> Function(
  String query, {
  required int limit,
  Set<String> excludeIds,
});

class MusicCandidateGenerator {
  MusicCandidateGenerator({
    required MusicSearch search,
    MusicEntityResolver resolver = const MusicEntityResolver(),
    MusicContentValidator validator = const MusicContentValidator(),
    this.config = MusicRecommendationConfig.defaultConfig,
  })  : _search = search,
        _resolver = resolver,
        _validator = validator;

  final MusicSearch _search;
  final MusicEntityResolver _resolver;
  final MusicContentValidator _validator;
  final MusicRecommendationConfig config;

  static const Map<String, String> _genreQueries = {
    'Bollywood': 'bollywood songs official',
    'Punjabi': 'punjabi songs official',
    'Hindi': 'hindi songs official',
    'English': 'english pop songs official',
    'Hip-Hop': 'hip hop songs official',
    'EDM': 'edm songs official',
    'Chill': 'chill lofi songs official',
    'Romantic': 'romantic songs official',
    'Sad': 'sad songs official',
    'Workout': 'workout songs official',
    'Indie': 'indie songs official',
    'RnB': 'rnb songs official',
    'Lo-Fi': 'lofi songs official',
    'Party': 'party songs official',
    'Devotional': 'devotional songs official',
    'Rock': 'rock songs official',
    'Electronic': 'electronic songs official',
    'Global': 'global pop songs official',
  };

  /// Generates the candidate pool (quota-shaped, deduped, validated).
  Future<List<MusicCandidate>> generate({
    required MusicUserProfile profile,
    required MusicRecommendationContext context,
  }) async {
    final count = context.count;
    final quotas = _quotas(profile.isEmpty, count);
    _applyFilterQuotas(quotas, context, count);
    final queries = _buildQueries(profile, context, quotas);
    final candidates = <MusicCandidate>[];
    final seenVideo = <String>{...context.excludeIds};
    final seenSong = <String>{};

    // Bounded-parallel pool fetching (4-at-a-time waves): the old fully
    // sequential loop meant every generateForYou() paid for ~10+ round
    // trips one after another — the biggest Discover cold-start cost.
    // Results are merged in QUERY ORDER so ranking stays deterministic.
    const waveSize = 4;
    final perQuery =
        List<List<Map<String, dynamic>>?>.filled(queries.length, null);
    for (var i = 0; i < queries.length; i += waveSize) {
      final wave = queries.skip(i).take(waveSize).toList();
      final waveResults = await Future.wait(
        wave.map(
          (entry) => _search(
            entry.query,
            limit: entry.limit.clamp(1, 10),
            excludeIds: seenVideo,
          ),
        ),
      );
      for (var j = 0; j < waveResults.length; j++) {
        perQuery[i + j] = waveResults[j];
      }
    }

    for (var qi = 0; qi < queries.length; qi++) {
      final entry = queries[qi];
      final tracks = perQuery[qi] ?? const <Map<String, dynamic>>[];
      for (final map in tracks) {
        if (candidates.length >= count * 2) break;
        final track = ProviderTrack.fromTrackMap(map);
        final videoId = track.id;
        if (videoId.isEmpty || !seenVideo.add(videoId)) continue;
        if (!_validator.validate(map).isMusic) continue;
        final resolution = _resolver.resolveTrack(track);
        if (!seenSong.add(resolution.canonicalId)) continue;
        candidates.add(
          MusicCandidate(
            track: track,
            songId: resolution.canonicalId,
            source: entry.source,
            seedArtist: entry.seedArtist,
            seedGenre: entry.seedGenre,
            artist: track.artist,
            genre: resolution.genre ?? '',
            language: resolution.language ?? '',
            album: '',
          ),
        );
      }
      if (candidates.length >= count * 2) break;
    }
    return candidates;
  }

  /// Explore filters (Language / Mood / Genre picks) become real quotas:
  /// when the user selected filters, filtered pools must dominate the
  /// candidate mix — the previous build only gave moods a quota of 2 and
  /// IGNORED languages entirely, so filtered feeds looked random.
  void _applyFilterQuotas(
    Map<String, int> quotas,
    MusicRecommendationContext context,
    int count,
  ) {
    int qFrac(double fraction) => (count * fraction).round().clamp(0, count);
    if (context.languages.isNotEmpty) {
      quotas['language'] = max(1, qFrac(0.25));
    }
    if (context.moods.isNotEmpty) {
      quotas['mood'] = max(2, qFrac(0.25));
    }
    if (context.regions.isNotEmpty) {
      quotas['regional'] = max(1, qFrac(0.20));
    }
  }

  Map<String, int> _quotas(bool coldStart, int count) {
    int q(double fraction) => (count * fraction).round().clamp(0, count);
    if (coldStart) {
      return {
        'trending': q(0.35),
        'new_release': q(0.25),
        'regional': q(0.20),
        'exploration': q(0.20),
      };
    }
    return {
      'favorite_artist': q(config.favoriteArtistQuota),
      'similar_artist': q(config.favoriteArtistQuota / 2),
      'favorite_genre': q(config.genreLanguageQuota / 2),
      'favorite_language': q(config.genreLanguageQuota / 2),
      'recent_artist': q(config.recentQuota),
      'trending': q(config.trendingQuota),
      'new_release': q(config.newMusicQuota),
      'regional': q(2),
      'mood': q(2),
      'exploration': q(config.explorationQuota),
    };
  }

  List<_PoolQuery> _buildQueries(
    MusicUserProfile profile,
    MusicRecommendationContext context,
    Map<String, int> quotas,
  ) {
    final out = <_PoolQuery>[];
    void add(
      String source,
      String query,
      int limit, {
      String? seedArtist,
      String? seedGenre,
    }) {
      if (limit <= 0) return;
      out.add(
        _PoolQuery(
          source: source,
          query: query,
          limit: limit,
          seedArtist: seedArtist,
          seedGenre: seedGenre,
        ),
      );
    }

    final topArtists = profile.topArtists.take(3).toList();
    for (final artist in topArtists) {
      add(
        'favorite_artist',
        '$artist songs official audio',
        (quotas['favorite_artist']! / 3).ceil(),
        seedArtist: artist,
      );
    }
    for (final artist in topArtists.take(2)) {
      add(
        'similar_artist',
        'artists similar to $artist',
        (quotas['similar_artist']! / 2).ceil(),
        seedArtist: artist,
      );
    }
    for (final genre in profile.topGenres.take(3)) {
      final q = _genreQueries[genre];
      if (q != null) {
        add(
          'favorite_genre',
          q,
          (quotas['favorite_genre']! / 3).ceil(),
          seedGenre: genre,
        );
      }
    }
    for (final lang in profile.topLanguages.take(2)) {
      add(
        'favorite_language',
        '$lang songs official audio',
        (quotas['favorite_language']! / 2).ceil(),
      );
    }
    for (final artist in profile.recentArtists.take(2)) {
      add(
        'recent_artist',
        '$artist songs official audio',
        (quotas['recent_artist']! / 2).ceil(),
        seedArtist: artist,
      );
    }
    for (final mood in context.moods.take(2)) {
      add('mood', '$mood songs official audio', quotas['mood'] ?? 2);
    }
    // Explore Language picks → dedicated language pool (previously the
    // context.languages list was silently dropped).
    for (final lang in context.languages.take(2)) {
      add(
        'language',
        '$lang songs official audio',
        (quotas['language'] ?? 0) ~/ 2,
      );
    }

    // Filter tokens (mood + language + genre picks) are appended to the
    // trending / new pools too, so every pool respects an active filter.
    final filterTokens = <String>[
      ...context.moods.take(1),
      ...context.languages.take(1),
      ...context.regions.take(1),
    ].where((t) => t.trim().isNotEmpty).join(' ');

    add(
      'trending',
      filterTokens.isEmpty
          ? 'trending songs official video 2026'
          : 'trending $filterTokens songs official video',
      quotas['trending'] ?? 2,
    );
    add(
      'new_release',
      filterTokens.isEmpty
          ? 'new music releases official audio 2026'
          : 'new $filterTokens music releases official audio',
      quotas['new_release'] ?? 2,
    );
    for (final region in context.regions.take(2)) {
      add(
        'regional',
        '$region songs official audio',
        (quotas['regional']! / 2).ceil(),
      );
    }
    // Exploration: a genre OUTSIDE the user's established taste — but when
    // filters are active it stays INSIDE the picked theme (chill + Hindi
    // stays chill-Hindi adjacent, never random filler).
    if (filterTokens.isNotEmpty && (quotas['exploration'] ?? 0) > 0) {
      add('exploration', '$filterTokens playlist official audio', 1);
    } else {
      final explored = profile.topGenres.take(3).toSet();
      final unknown = _genreQueries.keys
          .where((g) => !explored.contains(g))
          .toList()
        ..shuffle();
      for (final genre in unknown.take(quotas['exploration'] ?? 0)) {
        add('exploration', _genreQueries[genre]!, 1, seedGenre: genre);
      }
    }
    return out;
  }
}

class _PoolQuery {
  const _PoolQuery({
    required this.source,
    required this.query,
    required this.limit,
    this.seedArtist,
    this.seedGenre,
  });

  final String source;
  final String query;
  final int limit;
  final String? seedArtist;
  final String? seedGenre;
}
