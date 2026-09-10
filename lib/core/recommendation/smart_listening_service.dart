import '../music/music_validator.dart';
import '../providers/music_repository.dart';
import '../music/music_candidate_generator.dart' show MusicSearch;
import '../storage/local_library.dart';
import '../storage/personalization_store.dart';
import 'music_recommendation_engine.dart';
import 'preference_scoring.dart';
import 'music_region_profile.dart';

/// V Shots listening-loop coordinator.
///
/// Keeps the existing recommendation engine as the source of taste signals,
/// then adds explicit listening modes: Smart Next (70/20/10), Song Radio,
/// Daily Mix, mood mixes and recent-song cooldown. Playback remains owned by
/// VShotsPlaybackManager through [playQueue].
class SmartListeningService {
  SmartListeningService._();
  static final SmartListeningService instance = SmartListeningService._();

  MusicRecommendationEngine? _engine;
  MusicRepository? _repository;
  void Function(List<Map<String, dynamic>> tracks, int index)? _playQueue;

  /// Test seam: when set, pool searches go through this instead of the
  /// repository (the engine keeps its own injected search).
  MusicSearch? _searchOverride;

  void configure({
    required MusicRecommendationEngine engine,
    MusicRepository? repository,
    required void Function(List<Map<String, dynamic>> tracks, int index)
        playQueue,
    MusicSearch? searchOverride,
  }) {
    _engine = engine;
    _repository = repository;
    _playQueue = playQueue;
    _searchOverride = searchOverride;
  }

  bool get isConfigured =>
      _engine != null && (_repository != null || _searchOverride != null);

  Future<List<Map<String, dynamic>>> _poolSearch(
    String query, {
    required int limit,
    Set<String> excludeIds = const {},
  }) {
    final override = _searchOverride;
    if (override != null) {
      return override(query, limit: limit, excludeIds: excludeIds);
    }
    final repo = _repository;
    if (repo == null) {
      return Future.value(const <Map<String, dynamic>>[]);
    }
    return repo.search(query, limit: limit, excludeIds: excludeIds);
  }

  /// Builds Smart Next as exactly 70% proven taste, 20% adjacent/similar and
  /// 10% controlled exploration. If a provider pool is thin, the remainder
  /// is backfilled from the other validated pools without exceeding [count].
  Future<List<Map<String, dynamic>>> nextSongQueue({
    Map<String, dynamic>? seed,
    int count = 10,
  }) async {
    final engine = _engine;
    if (engine == null || count < 1) return const [];

    final currentId = seed?['id'] as String? ?? '';
    final cooldown = _cooldownIds(seedId: currentId);
    final exclude = <String>{...cooldown, if (currentId.isNotEmpty) currentId};
    final primaryCount = (count * .70).floor();
    final similarCount = (count * .20).floor();
    final exploreCount = count - primaryCount - similarCount;

    // Controlled exploration still explores WITHIN the user's stated
    // taste when they have one; region default only as fallback.
    final prefTokens = PreferenceSnapshot.capture().queryTokens(max: 2);
    final exploreQuery = prefTokens.isNotEmpty
        ? '${prefTokens.join(' ')} new discoveries official audio'
        : '${MusicRegionProfile.current().primaryQueries.first} new discoveries';

    final results = await Future.wait<List<Map<String, dynamic>>>([
      if (primaryCount > 0)
        engine.generateForYou(
          excludeIds: exclude,
          count: primaryCount + 5,
        )
      else
        Future.value(const <Map<String, dynamic>>[]),
      if (similarCount > 0)
        _poolSearch(
          '${seed?['artist'] ?? ''} ${seed?['title'] ?? ''} similar songs official audio',
          limit: similarCount + 5,
          excludeIds: exclude,
        )
      else
        Future.value(const <Map<String, dynamic>>[]),
      if (exploreCount > 0)
        _poolSearch(
          exploreQuery,
          limit: exploreCount + 5,
          excludeIds: exclude,
        )
      else
        Future.value(const <Map<String, dynamic>>[]),
    ]);

    final primary = _clean(results[0]);
    final similar = _clean(results[1]);
    final exploration = _clean(results[2]);

    final queue = <Map<String, dynamic>>[];
    final used = <String>{currentId};

    void takeFrom(List<Map<String, dynamic>> source, int amount) {
      if (amount <= 0) return;
      for (final track in source) {
        if (queue.length >= count || amount <= 0) return;
        final id = track['id'] as String? ?? '';
        if (id.isEmpty || !used.add(id)) continue;
        queue.add(track);
        amount--;
      }
    }

    takeFrom(primary, primaryCount);
    takeFrom(similar, similarCount);
    takeFrom(exploration, exploreCount);

    // Backfill only after the contractual buckets have had their turn.
    for (final pool in [primary, similar, exploration]) {
      for (final track in pool) {
        if (queue.length >= count) break;
        final id = track['id'] as String? ?? '';
        if (id.isNotEmpty && used.add(id)) queue.add(track);
      }
    }
    return _diversify(queue.take(count).toList());
  }

  Future<void> startSongRadio(Map<String, dynamic> seed) async {
    final repo = _repository;
    if (!isConfigured) return;
    final exclude = _cooldownIds(seedId: seed['id'] as String? ?? '');
    final related = await repo?.getRelated(
          seed['id'] as String? ?? '',
          limit: 18,
        ) ??
        const <Map<String, dynamic>>[];
    final searched = await _poolSearch(
      '${seed['artist'] ?? ''} similar songs official audio',
      limit: 18,
      excludeIds: {...exclude, seed['id'] as String? ?? ''},
    );
    final personalized = await nextSongQueue(seed: seed, count: 12);
    final combined = _diversify(
      _clean([...related, ...searched, ...personalized]),
    );
    if (combined.isNotEmpty) _playQueue?.call(combined, 0);
  }

  Future<List<Map<String, dynamic>>> dailyMix(
      {int mix = 1, DateTime? now}) async {
    final recent = LocalLibrary.instance.recentlyPlayed.value;
    final store = PersonalizationStore.instance;
    Map<String, dynamic>? seed = recent.isEmpty ? null : recent.first;

    // COLD START: no listening history yet — the user's stated taste IS
    // the mix. Mix 1 leads with a favorite song; Mix 2 rotates through
    // favorite artists day-by-day so the two mixes genuinely differ.
    if (seed == null) {
      final songs = store.favoriteSongs;
      final artists = store.favoriteArtists;
      if (mix == 1 && songs.isNotEmpty) {
        seed = {
          'id': songs.first.id,
          'title': songs.first.title,
          'artist': songs.first.artist,
        };
      } else if (artists.isNotEmpty) {
        final dayIndex =
            (now ?? DateTime.now()).difference(DateTime(2026)).inDays;
        final artist = artists[dayIndex % artists.length].trim();
        if (artist.isNotEmpty) {
          seed = <String, dynamic>{'id': '', 'title': '', 'artist': artist};
        }
      }
    }
    final queue = await nextSongQueue(seed: seed, count: 20);
    final label = mix == 2 ? 'Daily Mix 2' : 'Daily Mix 1';
    return queue.map((t) => {...t, 'smartMix': label}).toList();
  }

  Future<List<Map<String, dynamic>>> moodMix(String mood, {int count = 15}) {
    final engine = _engine;
    if (engine == null) return Future.value(const []);
    final region = MusicRegionProfile.current();
    // Stated languages give a mood mix its flavor — a Party mix for a
    // Punjabi-first user is a Punjabi party. Empty = neutral (unchanged).
    final languages =
        PersonalizationStore.instance.preferredLanguages.take(2).toList();
    return engine.generateForYou(
      excludeIds: _cooldownIds(),
      count: count,
      moods: [mood],
      languages: languages,
      regions: [region.countryName],
    );
  }

  Future<void> playSmartNext({Map<String, dynamic>? seed}) async {
    final queue = await nextSongQueue(seed: seed, count: 10);
    if (queue.isNotEmpty) _playQueue?.call(queue, 0);
  }

  Set<String> _cooldownIds({String seedId = ''}) {
    final now = DateTime.now();
    final liked = LocalLibrary.instance.likedSongs.value
        .map((t) => t['id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final result = <String>{};
    for (final track in LocalLibrary.instance.recentlyPlayed.value) {
      final id = track['id'] as String? ?? '';
      if (id.isEmpty || id == seedId || liked.contains(id)) continue;
      final raw = track['playedAt'] as String?;
      final playedAt = raw == null ? null : DateTime.tryParse(raw);
      if (playedAt == null) continue;
      final age = now.difference(playedAt);
      if (age < const Duration(hours: 24)) result.add(id);
    }
    return result;
  }

  List<Map<String, dynamic>> _clean(List<Map<String, dynamic>> tracks) {
    return validateAndFilterMusic(tracks, label: 'smart-listening');
  }

  List<Map<String, dynamic>> _diversify(List<Map<String, dynamic>> tracks) {
    final result = <Map<String, dynamic>>[];
    final artistCounts = <String, int>{};
    final seen = <String>{};
    for (final track in tracks) {
      final id = track['id'] as String? ?? '';
      if (id.isEmpty || !seen.add(id)) continue;
      final artist = (track['artist'] as String? ?? '').trim().toLowerCase();
      final count = artistCounts[artist] ?? 0;
      if (count >= 2 && result.length < 8) continue;
      artistCounts[artist] = count + 1;
      result.add(track);
    }
    return result;
  }
}
