// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Home Feed Service & recommendation->Home pipeline tests
//
// Proves the end-to-end chain the product depends on:
//     listen/like -> SignalStore -> TasteProfile -> candidate queries ->
//     RecommendationEngine -> HomeFeedService -> Home shelves
//
// Uses a keyword-aware fake provider (no network) so these tests are fast and
// deterministic, exactly like provider_manager_test.dart's FakeProvider.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/providers/music_provider.dart';
import 'package:v_shots/core/providers/music_repository.dart';
import 'package:v_shots/core/providers/provider_config.dart';
import 'package:v_shots/core/providers/provider_manager.dart';
import 'package:v_shots/core/providers/provider_models.dart';
import 'package:v_shots/core/providers/provider_registry.dart';
import 'package:v_shots/core/providers/provider_result.dart';
import 'package:v_shots/core/recommendation/candidate_generator.dart';
import 'package:v_shots/core/recommendation/feed_intent.dart';
import 'package:v_shots/core/recommendation/recommendation_cache.dart';
import 'package:v_shots/core/recommendation/recommendation_engine.dart';
import 'package:v_shots/core/recommendation/signal_event.dart';
import 'package:v_shots/core/recommendation/signal_store.dart';
import 'package:v_shots/core/recommendation/taste_profile.dart';
import 'package:v_shots/core/storage/local_library.dart';
import 'package:v_shots/features/home/home_feed_service.dart';

/// Keyword-aware fake: query text decides the returned artist, so tests can
/// assert that seeded taste actually changes what Home surfaces.
class KeywordProvider implements MusicProvider {
  @override
  String get id => 'youtube';

  @override
  String get displayName => 'Keyword Fake';

  @override
  Set<ProviderCapability> get capabilities => ProviderCapability.values.toSet();

  @override
  bool supports(ProviderCapability capability) =>
      capabilities.contains(capability);

  @override
  Future<void> initialize() async {}

  @override
  Future<ProviderHealth> healthCheck() async =>
      const ProviderHealth(healthy: true);

  @override
  Future<ProviderResult<List<ProviderTrack>>> search(
    String query, {
    String order = 'relevance',
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) async {
    final q = query.toLowerCase();
    final String artist;
    if (q.contains('arijit')) {
      artist = 'Arijit Singh';
    } else if (q.contains('diljit')) {
      artist = 'Diljit Dosanjh';
    } else if (q.contains('trending')) {
      artist = 'Trending Artist';
    } else if (q.contains('new music') ||
        q.contains('new release') ||
        q.contains('new official')) {
      artist = 'New Release Artist';
    } else {
      artist = 'Catalog Artist';
    }

    final tracks = <ProviderTrack>[];
    for (var i = 0; i < limit; i++) {
      final id = 'vid-${Object.hash(artist, i, query)}';
      if (excludeIds.contains(id)) continue;
      tracks.add(
        ProviderTrack(
          id: id,
          title: '$artist — song $i',
          artist: artist,
          artworkUrl: '',
          durationSeconds: 180 + i,
        ),
      );
    }
    return ProviderResult.success(tracks);
  }

  @override
  Future<ProviderResult<ProviderSearchPage>> searchPage(
    String query, {
    String order = 'relevance',
    int limit = 20,
    Set<String> excludeIds = const {},
    String? pageToken,
  }) async {
    final tracks = await search(query, limit: limit, excludeIds: excludeIds);
    if (tracks.isFailure) return ProviderResult.failure(tracks.error!);
    return ProviderResult.success(
      ProviderSearchPage(tracks: tracks.data!, nextPageToken: null),
    );
  }

  @override
  Future<ProviderResult<ProviderTrack>> getTrack(String id) async =>
      ProviderResult.failure('unused');

  @override
  Future<ProviderResult<List<ProviderTrack>>> getRelated(
    String trackId, {
    int limit = 10,
  }) async =>
      ProviderResult.failure('not supported');

  @override
  Future<ProviderResult<String>> getStream(String id) async =>
      ProviderResult.failure('unused');

  @override
  Future<ProviderResult<String>> getArtwork(String id) async =>
      ProviderResult.failure('unused');

  @override
  Future<ProviderResult<ProviderLyrics>> getLyrics({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  }) async =>
      ProviderResult.failure('unused');

  @override
  Future<ProviderResult<List<ProviderTrack>>> getTrending({int limit = 15}) =>
      search('trending', limit: limit);

  @override
  Future<ProviderResult<List<ProviderTrack>>> getRecommendations({
    required Set<String> excludeIds,
    int limit = 10,
  }) =>
      search('recommendations', limit: limit);

  @override
  Future<void> dispose() async {}
}

MusicRepository buildFakeRepository() {
  final registry = ProviderRegistry()..register(KeywordProvider());
  final manager = ProviderManager(
    registry: registry,
    config: ProviderConfig.defaultConfig,
  );
  return MusicRepository(manager);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Reset singleton state so tests are deterministic.
    RecommendationCache.instance.invalidateAll();
    await SignalStore.instance.clear();
    await LocalLibrary.instance.clearRecentlyPlayed();
  });

  group('Recommendation -> Home pipeline', () {
    test(
        'cold start: personalized shelves fall back, '
        '"Because You Listened To" hidden', () async {
      final repo = buildFakeRepository();
      final engine = RecommendationEngine(repo);
      final service = HomeFeedService(repository: repo, engine: engine);

      final shelves = service.buildShelfDescriptors();
      await service.loadShelves(shelves);

      final mfy = shelves.firstWhere((s) => s.id == 'mfy');
      expect(mfy.status, HomeShelfStatus.loaded);
      expect(mfy.tracks, isNotEmpty,
          reason: 'Made For You must never be empty on cold start');

      final byld = shelves.firstWhere((s) => s.id == 'byld');
      expect(byld.status, HomeShelfStatus.hidden,
          reason: 'no history yet -> no "Because You Listened To" row');
    });

    test('listen -> signal -> profile -> candidate -> Home result', () async {
      // Seed real listening/like signals for one artist.
      final now = DateTime.now();
      for (var i = 0; i < 3; i++) {
        await SignalStore.instance.record(
          SignalEvent(
            type: SignalType.completed,
            timestamp: now.subtract(Duration(minutes: i)),
            trackId: 'arijit-$i',
            artist: 'Arijit Singh',
            title: 'Tum Hi Ho',
          ),
        );
      }
      await SignalStore.instance.record(
        SignalEvent(
          type: SignalType.like,
          timestamp: now,
          trackId: 'arijit-0',
          artist: 'Arijit Singh',
          title: 'Tum Hi Ho',
        ),
      );
      await LocalLibrary.instance.recordRecentlyPlayed({
        'id': 'arijit-0',
        'title': 'Tum Hi Ho',
        'artist': 'Arijit Singh',
        'artwork': '',
        'duration': 200,
      });

      // 1. signals -> taste profile
      final profile = TasteProfileBuilder().build();
      expect(profile.topArtists, contains('Arijit Singh'));

      // 2. profile -> candidate queries
      final candidates = CandidateGenerator().generate(profile, count: 20);
      expect(
        candidates.any((c) => c.query.toLowerCase().contains('arijit')),
        isTrue,
        reason: 'candidate queries must be seeded from the top artist',
      );

      // 3. candidates -> ranked engine feed
      final repo = buildFakeRepository();
      final engine = RecommendationEngine(repo);
      final feed = await engine.generateFeed(
        intent: FeedIntent.madeForYou,
        excludeIds: const {},
        count: 10,
      );
      expect(feed, isNotEmpty);
      expect(
        feed.any((s) => s.track.artist == 'Arijit Singh'),
        isTrue,
        reason: 'Made For You must surface the seeded artist',
      );

      // 4. engine feed -> Home shelves
      final service = HomeFeedService(repository: repo, engine: engine);
      final shelves = service.buildShelfDescriptors();
      await service.loadShelves(shelves);

      final mfy = shelves.firstWhere((s) => s.id == 'mfy');
      expect(mfy.status, HomeShelfStatus.loaded);
      expect(
        mfy.tracks.any((t) => t['artist'] == 'Arijit Singh'),
        isTrue,
        reason: 'the Home "Made For You" shelf must reflect the seeded taste',
      );

      final byld = shelves.firstWhere((s) => s.id == 'byld');
      expect(byld.status, HomeShelfStatus.loaded,
          reason: 'with history, "Because You Listened To" becomes visible');
      expect(byld.subtitle.toLowerCase(), contains('arijit'));
    });

    test('new listening activity reshapes Home on force refresh', () async {
      final repo = buildFakeRepository();
      final engine = RecommendationEngine(repo);
      final service = HomeFeedService(repository: repo, engine: engine);

      // Load once on a cold start.
      final shelves1 = service.buildShelfDescriptors();
      await service.loadShelves(shelves1);
      final mfy1 = shelves1.firstWhere((s) => s.id == 'mfy');
      final before = mfy1.tracks.any((t) => t['artist'] == 'Arijit Singh');
      expect(before, isFalse,
          reason: 'before any Arijit signals, Home should not feature Arijit');

      // The user then listens to a lot of Arijit Singh (>=3 signals so the
      // engine crosses its personalization threshold).
      final now = DateTime.now();
      for (var i = 0; i < 3; i++) {
        await SignalStore.instance.record(
          SignalEvent(
            type: SignalType.completed,
            timestamp: now.subtract(Duration(minutes: i)),
            trackId: 'a$i',
            artist: 'Arijit Singh',
            title: 'Tum Hi Ho',
          ),
        );
      }
      await SignalStore.instance.record(
        SignalEvent(
          type: SignalType.like,
          timestamp: now,
          trackId: 'a0',
          artist: 'Arijit Singh',
          title: 'Tum Hi Ho',
        ),
      );
      await LocalLibrary.instance.recordRecentlyPlayed({
        'id': 'a0',
        'title': 'Tum Hi Ho',
        'artist': 'Arijit Singh',
        'artwork': '',
        'duration': 200,
      });

      // Force refresh (bypasses the recommendation feed cache).
      final shelves2 = service.buildShelfDescriptors();
      await service.loadShelves(shelves2, forceRefresh: true);
      final mfy2 = shelves2.firstWhere((s) => s.id == 'mfy');
      final after = mfy2.tracks.any((t) => t['artist'] == 'Arijit Singh');
      expect(after, isTrue,
          reason: 'Home must actually change after meaningful listening');
    });

    test('no duplicate track ids across the loaded Home feed', () async {
      final repo = buildFakeRepository();
      final engine = RecommendationEngine(repo);
      final service = HomeFeedService(repository: repo, engine: engine);

      final shelves = service.buildShelfDescriptors();
      await service.loadShelves(shelves);

      final ids = <String>[];
      for (final s in shelves) {
        for (final t in s.tracks) {
          final id = t['id'] as String? ?? '';
          if (id.isNotEmpty) ids.add(id);
        }
      }
      expect(ids.toSet().length, ids.length,
          reason: 'the same video must not appear on two shelves');
    });

    test('artist repetition within a shelf is capped', () async {
      final repo = buildFakeRepository();
      final engine = RecommendationEngine(repo);
      final service = HomeFeedService(repository: repo, engine: engine);

      final shelves = service.buildShelfDescriptors();
      await service.loadShelves(shelves);

      for (final s
          in shelves.where((x) => x.status == HomeShelfStatus.loaded)) {
        final counts = <String, int>{};
        for (final t in s.tracks) {
          counts[t['artist'] as String? ?? ''] =
              (counts[t['artist'] as String? ?? ''] ?? 0) + 1;
        }
        for (final entry in counts.entries) {
          expect(
            entry.value,
            lessThanOrEqualTo(3),
            reason: 'shelf ${s.id} has too many tracks from ${entry.key}',
          );
        }
      }
    });
  });
}
