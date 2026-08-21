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

import '../providers/provider_models.dart';
import '../recommendation/music_recommendation_config.dart';
import '../recommendation/music_recommendation_context.dart';
import '../recommendation/music_user_profile.dart';
import 'music_candidate.dart';
import 'music_entity_resolver.dart';
import 'music_validator.dart';

typedef MusicSearch =
    Future<List<Map<String, dynamic>>> Function(
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
  }) : _search = search,
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
    final queries = _buildQueries(profile, context, quotas);
    final candidates = <MusicCandidate>[];
    final seenVideo = <String>{...context.excludeIds};
    final seenSong = <String>{};

    for (final entry in queries) {
      final tracks = await _search(
        entry.query,
        limit: entry.limit.clamp(1, 10),
        excludeIds: seenVideo,
      );
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
    for (final mood in context.moods.take(1)) {
      add('mood', '$mood songs official audio', quotas['mood']!);
    }
    add('trending', 'trending songs official video 2026', quotas['trending']!);
    add(
      'new_release',
      'new music releases official audio 2026',
      quotas['new_release']!,
    );
    for (final region in context.regions.take(2)) {
      add(
        'regional',
        '$region songs official audio',
        (quotas['regional']! / 2).ceil(),
      );
    }
    // Exploration: a genre OUTSIDE the user's established taste.
    final explored = profile.topGenres.take(3).toSet();
    final unknown =
        _genreQueries.keys.where((g) => !explored.contains(g)).toList()
          ..shuffle();
    for (final genre in unknown.take(quotas['exploration']!)) {
      add('exploration', _genreQueries[genre]!, 1, seedGenre: genre);
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
