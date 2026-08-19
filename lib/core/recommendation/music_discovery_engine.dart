// V Shots — Music Discovery Engine V4
// Metrolist-inspired multi-source discovery for V Shots.

import 'dart:async';
import 'dart:math';

import '../music/music_candidate.dart';
import '../music/music_diversity.dart';
import '../music/music_entity_resolver.dart';
import '../music/music_validator.dart';
import '../providers/music_repository.dart';
import '../providers/provider_models.dart';
import '../storage/local_library.dart';
import 'music_recommendation_config.dart';
import 'music_recommendation_context.dart';
import 'music_recommendation_engine.dart';
import 'music_seen_store.dart';
import 'music_session_state.dart';
import 'music_user_profile.dart';
import 'music_user_profile_builder.dart';

class MusicDiscoveryEngine {
  MusicDiscoveryEngine({
    required MusicRepository repository,
    MusicSeenStore? seenStore,
    MusicSessionState? session,
    this.config = MusicRecommendationConfig.defaultConfig,
  })  : _repository = repository,
        _seenStore = seenStore ?? MusicSeenStore(),
        _session = session ?? MusicSessionState();

  final MusicRepository _repository;
  final MusicSeenStore _seenStore;
  final MusicSessionState _session;
  final MusicRecommendationConfig config;
  bool _initialized = false;
  int _refreshSalt = 0;

  static const _resolver = MusicEntityResolver();
  static const _validator = MusicContentValidator();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _seenStore.initialize();
    _initialized = true;
  }

  Future<List<Map<String, dynamic>>> generate({
    required Set<String> excludeIds,
    int count = 12,
    List<String> languages = const [],
    List<String> moods = const [],
    List<String> regions = const [],
  }) async {
    await _ensureInitialized();
    _refreshSalt++;
    _session.requestToken++;

    final profile = MusicUserProfileBuilder(config: config).build();
    final context = MusicRecommendationContext(
      mode: 'discovery_v4',
      languages: languages,
      moods: moods,
      regions: regions,
      count: count,
      excludeIds: excludeIds,
      seenStore: _seenStore,
      session: _session,
    );

    final candidates = await _collectCandidates(
      profile: profile,
      excludeIds: excludeIds,
      languages: languages,
      moods: moods,
      regions: regions,
    );

    final unique = <String, MusicCandidate>{};
    for (final candidate in candidates) {
      if (candidate.track.id.isEmpty ||
          excludeIds.contains(candidate.track.id)) {
        continue;
      }
      unique.putIfAbsent(candidate.songId, () => candidate);
    }

    final artistCounts = <String, int>{};
    final scored = <ScoredMusicCandidate>[];
    for (final candidate in unique.values) {
      final score = scoreForYou(
        candidate: candidate,
        profile: profile,
        context: context,
        artistCounts: artistCounts,
        config: config,
      );
      scored.add(ScoredMusicCandidate(candidate: candidate, score: score));
      artistCounts[candidate.artist] =
          (artistCounts[candidate.artist] ?? 0) + 1;
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final diversified = const MusicDiversity().diversify(scored);

    final exploration =
        diversified.where((s) => _isExploration(s.candidate, profile)).toList();
    final familiar = diversified
        .where((s) => !_isExploration(s.candidate, profile))
        .toList();

    final mixed = <ScoredMusicCandidate>[];
    final targetExploration = max(1, (count * config.explorationRatio).round());
    var e = 0;
    var f = 0;
    while (mixed.length < count &&
        (e < exploration.length || f < familiar.length)) {
      final shouldExplore = e < exploration.length &&
          (e < targetExploration || f >= familiar.length);
      if (shouldExplore) {
        mixed.add(exploration[e++]);
      } else if (f < familiar.length) {
        mixed.add(familiar[f++]);
      } else {
        break;
      }
    }

    final result = <Map<String, dynamic>>[];
    for (final scoredCandidate in mixed) {
      final candidate = scoredCandidate.candidate;
      if (!_session.emitSong(candidate.songId, candidate.track.id)) continue;
      result.add(candidate.track.toTrackMap());
      unawaited(_seenStore.record(candidate.songId));
      if (result.length >= count) break;
    }
    return result;
  }

  Future<List<MusicCandidate>> _collectCandidates({
    required MusicUserProfile profile,
    required Set<String> excludeIds,
    required List<String> languages,
    required List<String> moods,
    required List<String> regions,
  }) async {
    final tasks = <Future<List<MusicCandidate>>>[];

    // Provider-native personalized recommendations.
    tasks.add(_fromTracks(
      () => _repository.getRecommendations(excludeIds: excludeIds, limit: 20),
      source: 'provider_recommendation',
      excludeIds: excludeIds,
    ));

    // Metrolist-style related-content seeds: use the actual provider video IDs
    // from V Shots' local listening history. Canonical song IDs are not passed
    // to the provider because they are intentionally not video IDs.
    final recentLocal = LocalLibrary.instance.recentlyPlayed.value;
    final relatedIds = <String>{};
    for (final entry in recentLocal.take(6)) {
      final id = entry['id'] as String? ?? '';
      if (id.isNotEmpty && relatedIds.add(id)) {
        tasks.add(_fromTracks(
          () => _repository.getRelated(id, limit: 10),
          source: 'related_recent',
          excludeIds: excludeIds,
        ));
      }
    }

    // Taste/search pools provide stable fallbacks and adjacent discovery.
    final artists = {
      ...profile.recentArtists.take(4),
      ...profile.topArtists.take(4),
    };
    for (final artist in artists) {
      tasks.add(_search(
        '$artist songs official audio',
        source: 'taste_artist',
        excludeIds: excludeIds,
      ));
    }

    for (final genre in profile.topGenres.take(3)) {
      tasks.add(_search(
        '$genre songs official audio',
        source: 'taste_genre',
        seedGenre: genre,
        excludeIds: excludeIds,
      ));
    }
    for (final language in {
      ...profile.topLanguages.take(2),
      ...languages.take(2),
    }) {
      tasks.add(_search(
        '$language songs official audio',
        source: 'taste_language',
        excludeIds: excludeIds,
      ));
    }
    for (final mood in {...profile.topMoods.take(2), ...moods.take(2)}) {
      tasks.add(_search(
        '$mood songs official audio',
        source: 'mood',
        excludeIds: excludeIds,
      ));
    }
    for (final region in regions.take(2)) {
      tasks.add(_search(
        '$region songs official audio',
        source: 'regional',
        excludeIds: excludeIds,
      ));
    }

    // Always retain a global trend lane.
    tasks.add(_fromTracks(
      () => _repository.getTrending(limit: 20),
      source: 'trending',
      excludeIds: excludeIds,
    ));

    // Rotate exploration queries on each refresh so pull-to-refresh is not a
    // simple shuffle of the same result set.
    const explorationQueries = [
      'new music official audio',
      'rising artists official songs',
      'indie music discovery official',
      'new pop songs official audio',
      'underrated songs official audio',
      'fresh music 2026 official audio',
      'global music discovery official audio',
      'new artists to watch official music',
    ];
    final offset = _refreshSalt % explorationQueries.length;
    for (var i = 0; i < 3; i++) {
      tasks.add(_search(
        explorationQueries[(offset + i) % explorationQueries.length],
        source: 'exploration',
        excludeIds: excludeIds,
      ));
    }

    final groups = await Future.wait(tasks, eagerError: false);
    final flattened = <MusicCandidate>[];
    for (final group in groups) {
      flattened.addAll(group);
    }
    return flattened;
  }

  Future<List<MusicCandidate>> _search(
    String query, {
    required String source,
    String? seedGenre,
    required Set<String> excludeIds,
  }) async {
    try {
      final page = await _repository.searchPaginated(
        query,
        limit: 12,
        excludeIds: excludeIds,
      );
      return _convert(
        page.tracks,
        source: source,
        seedGenre: seedGenre,
        excludeIds: excludeIds,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<List<MusicCandidate>> _fromTracks(
    Future<List<Map<String, dynamic>>> Function() loader, {
    required String source,
    required Set<String> excludeIds,
  }) async {
    try {
      return _convert(
        await loader(),
        source: source,
        excludeIds: excludeIds,
      );
    } catch (_) {
      return const [];
    }
  }

  List<MusicCandidate> _convert(
    List<Map<String, dynamic>> tracks, {
    required String source,
    required Set<String> excludeIds,
    String? seedGenre,
  }) {
    final out = <MusicCandidate>[];
    final localSeen = <String>{};
    for (final map in tracks) {
      try {
        final track = ProviderTrack.fromTrackMap(map);
        if (track.id.isEmpty || excludeIds.contains(track.id)) continue;
        if (!localSeen.add(track.id)) continue;
        if (!_validator.validate(map).isMusic) continue;
        final resolved = _resolver.resolveTrack(track);
        if (resolved.canonicalId.isEmpty) continue;
        out.add(MusicCandidate(
          track: track,
          songId: resolved.canonicalId,
          source: source,
          seedGenre: seedGenre,
          artist: track.artist,
          genre: resolved.genre ?? seedGenre ?? '',
          language: resolved.language ?? '',
          album: '',
        ));
      } catch (_) {
        // One malformed provider item must never kill Discovery.
      }
    }
    return out;
  }

  bool _isExploration(MusicCandidate candidate, MusicUserProfile profile) {
    final artist = candidate.artist.toLowerCase();
    final knownArtist =
        profile.topArtists.any((a) => a.toLowerCase() == artist);
    final genre = candidate.genre.toLowerCase();
    final knownGenre = profile.topGenres.any((g) => g.toLowerCase() == genre);
    return !knownArtist && !knownGenre;
  }
}
