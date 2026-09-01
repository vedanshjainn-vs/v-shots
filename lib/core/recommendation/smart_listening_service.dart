import 'dart:math';

import '../music/music_validator.dart';
import '../providers/music_repository.dart';
import '../storage/local_library.dart';
import 'music_recommendation_engine.dart';
import 'music_region_profile.dart';

/// V Shots listening-loop coordinator.
///
/// Keeps the existing recommendation engine as the source of taste signals,
/// then adds explicit listening modes: Smart Next (70/20/10), Song Radio,
/// Daily Mix, mood mixes and a real recent-song cooldown. Playback remains
/// owned by VShotsPlaybackManager through [playQueue].
class SmartListeningService {
  SmartListeningService._();
  static final SmartListeningService instance = SmartListeningService._();

  MusicRecommendationEngine? _engine;
  MusicRepository? _repository;
  void Function(List<Map<String, dynamic>> tracks, int index)? _playQueue;

  void configure({
    required MusicRecommendationEngine engine,
    required MusicRepository repository,
    required void Function(List<Map<String, dynamic>> tracks, int index)
        playQueue,
  }) {
    _engine = engine;
    _repository = repository;
    _playQueue = playQueue;
  }

  bool get isConfigured => _engine != null && _repository != null;

  /// Builds the next listening queue using the requested 70/20/10 mix:
  /// 70% proven taste, 20% adjacent/similar, 10% controlled exploration.
  Future<List<Map<String, dynamic>>> nextSongQueue({
    Map<String, dynamic>? seed,
    int count = 10,
  }) async {
    final engine = _engine;
    final repo = _repository;
    if (engine == null || repo == null || count < 1) return const [];

    final currentId = seed?['id'] as String? ?? '';
    final cooldown = _cooldownIds(seedId: currentId);
    final exclude = <String>{...cooldown, if (currentId.isNotEmpty) currentId};
    final primaryCount = max(1, (count * .70).round());
    final similarCount = max(1, (count * .20).round());
    final exploreCount = max(1, count - primaryCount - similarCount);

    final results = await Future.wait<List<Map<String, dynamic>>>([
      engine.generateForYou(excludeIds: exclude, count: primaryCount + 5),
      if (seed != null)
        repo.search(
          '${seed['artist'] ?? ''} ${seed['title'] ?? ''} similar songs official audio',
          limit: similarCount + 5,
          excludeIds: exclude,
        )
      else
        repo.search(
          '${MusicRegionProfile.current().primaryQueries.first} new discoveries',
          limit: similarCount + 5,
          excludeIds: exclude,
        ),
      engine.generateForYou(
        excludeIds: <String>{...exclude},
        count: exploreCount + 5,
        languages: const [],
        moods: const [],
        regions: const [],
      ),
    ]);

    final primary = _clean(results[0]);
    final similar = _clean(results[1]);
    final exploration = _clean(results[2]);

    final queue = <Map<String, dynamic>>[];
    final used = <String>{currentId};
    void takeFrom(List<Map<String, dynamic>> source, int amount) {
      for (final track in source) {
        final id = track['id'] as String? ?? '';
        if (id.isEmpty || !used.add(id)) continue;
        queue.add(track);
        if (queue.where((_) => true).length >= count) return;
        if (amount <= 1) break;
        amount--;
      }
    }
    takeFrom(primary, primaryCount);
    takeFrom(similar, similarCount);
    takeFrom(exploration, exploreCount);

    // Backfill without breaking the 70/20/10 intent when a provider pool is
    // thin. Diversity is enforced after the mix so one artist cannot dominate.
    for (final pool in [primary, similar, exploration]) {
      for (final track in pool) {
        if (queue.length >= count) break;
        final id = track['id'] as String? ?? '';
        if (id.isNotEmpty && used.add(id)) queue.add(track);
      }
    }
    return _diversify(queue.take(count).toList());
  }

  /// Starts a Song Radio queue from the current song: similar artist/track,
  /// user taste and a small amount of exploration. No extraction is used;
  /// every item is an existing provider track passed to the normal player.
  Future<void> startSongRadio(Map<String, dynamic> seed) async {
    final repo = _repository;
    if (repo == null) return;
    final exclude = _cooldownIds(seedId: seed['id'] as String? ?? '');
    final related = await repo.getRelated(seed['id'] as String? ?? '', limit: 18);
    final searched = await repo.search(
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

  /// One or two fresh personalized mixes. [mix] is intentionally small so
  /// users get a coherent listening session rather than four weak playlists.
  Future<List<Map<String, dynamic>>> dailyMix({int mix = 1}) async {
    final recent = LocalLibrary.instance.recentlyPlayed.value;
    final seed = recent.isEmpty ? null : recent.first;
    final queue = await nextSongQueue(seed: seed, count: 20);
    final label = mix == 2 ? 'Daily Mix 2' : 'Daily Mix 1';
    return queue.map((t) => {...t, 'smartMix': label}).toList();
  }

  Future<List<Map<String, dynamic>>> moodMix(String mood, {int count = 15}) {
    final engine = _engine;
    if (engine == null) return Future.value(const []);
    final region = MusicRegionProfile.current();
    return engine.generateForYou(
      excludeIds: _cooldownIds(),
      count: count,
      moods: [mood],
      regions: [region.countryName],
    );
  }

  /// Plays the next smart queue immediately through the existing player.
  Future<void> playSmartNext({Map<String, dynamic>? seed}) async {
    final queue = await nextSongQueue(seed: seed, count: 10);
    if (queue.isNotEmpty) _playQueue?.call(queue, 0);
  }

  /// Explicit action for a user like/unlike: invalidate the old engine cache
  /// so the next generated batch sees the signal immediately.
  Future<void> onPreferenceChanged() async {
    // The existing RecommendationEngine invalidates its cache when signals
    // are recorded. This method deliberately remains a cheap synchronization
    // point for UI actions and avoids maintaining a second taste cache.
    await Future<void>.value();
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
      // Favorites are exceptions; other recently played tracks get the
      // explicit 24h hard cooldown, then the engine's decaying seen penalty
      // controls the 1–7 day return probability.
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
      // Never let a single artist fill a smart queue. Exceptions are created
      // by separate explicit Artist/Album queues, not recommendation queues.
      if (count >= 2 && result.length < 8) continue;
      artistCounts[artist] = count + 1;
      result.add(track);
    }
    return result;
  }
}
