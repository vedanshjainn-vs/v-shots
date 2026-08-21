// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Discover Feed Engine tests (V Shots Discover Algorithm)
// Deterministic: fake repository + injectable taste overrides. No network.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/discover/discover_feed_engine.dart';
import 'package:v_shots/core/providers/music_provider.dart';
import 'package:v_shots/core/providers/music_repository.dart';
import 'package:v_shots/core/providers/provider_manager.dart';
import 'package:v_shots/core/providers/provider_models.dart';
import 'package:v_shots/core/providers/provider_registry.dart';
import 'package:v_shots/core/providers/provider_result.dart';

class DiscoverFakeProvider implements MusicProvider {
  DiscoverFakeProvider({
    this.trendingTracks = const [],
    this.searchTracks = const [],
  });

  /// Tracks returned by getTrending (bucket: trending).
  final List<ProviderTrack> trendingTracks;

  /// Tracks returned by every search() call (fresh/exploration/personal
  /// seed queries).
  final List<ProviderTrack> searchTracks;

  @override
  String get id => 'innertube';

  @override
  String get displayName => 'Discover Fake';

  @override
  Set<ProviderCapability> get capabilities => ProviderCapability.values.toSet();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  bool supports(ProviderCapability capability) =>
      capabilities.contains(capability);

  @override
  Future<ProviderHealth> healthCheck() async =>
      const ProviderHealth(healthy: true);

  @override
  Future<ProviderResult<List<ProviderTrack>>> getTrending({
    int limit = 15,
    String region = '',
  }) async =>
      ProviderResult.success(trendingTracks.take(limit).toList());

  @override
  Future<ProviderResult<List<ProviderTrack>>> search(
    String query, {
    String order = 'relevance',
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) async =>
      ProviderResult.success(
        searchTracks
            .where((t) => !excludeIds.contains(t.id))
            .take(limit)
            .toList(),
      );

  @override
  Future<ProviderResult<ProviderSearchPage>> searchPage(
    String query, {
    String order = 'relevance',
    int limit = 20,
    Set<String> excludeIds = const {},
    String? pageToken,
  }) async =>
      ProviderResult.success(
        ProviderSearchPage(tracks: searchTracks.take(limit).toList()),
      );

  @override
  Future<ProviderResult<List<ProviderTrack>>> getPlaylistTracks(
    String playlistId, {
    int limit = 30,
  }) async =>
      ProviderResult.success(searchTracks.take(limit).toList());

  @override
  Future<ProviderResult<List<ProviderTrack>>> getChannelTracks(
    String channelId, {
    int limit = 30,
  }) async =>
      ProviderResult.success(searchTracks.take(limit).toList());

  @override
  Future<ProviderResult<ProviderTrack>> getTrack(String id) async =>
      ProviderResult.failure('nope');

  @override
  Future<ProviderResult<String>> getStream(String id) async =>
      ProviderResult.failure('nope');

  @override
  Future<ProviderResult<String>> getArtwork(String id) async =>
      ProviderResult.failure('nope');

  @override
  Future<ProviderResult<ProviderLyrics>> getLyrics({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  }) async =>
      ProviderResult.failure('nope');

  @override
  Future<ProviderResult<List<ProviderTrack>>> getRecommendations({
    required Set<String> excludeIds,
    int limit = 10,
  }) async =>
      ProviderResult.failure('nope');

  @override
  Future<ProviderResult<List<ProviderTrack>>> getRelated(
    String trackId, {
    int limit = 10,
  }) async =>
      ProviderResult.failure('nope');
}

ProviderTrack _t(String id, String artist, {int views = 1000, int age = 3}) =>
    ProviderTrack(
      id: id,
      title: '$artist — song $id',
      artist: artist,
      artworkUrl: '',
      durationSeconds: 200,
      viewCount: views,
      publishedDaysAgo: age,
    );

DiscoverFeedEngine _engine({
  required DiscoverFakeProvider provider,
  Map<String, double>? artistScores,
}) {
  final registry = ProviderRegistry()..register(provider);
  final manager = ProviderManager(registry: registry);
  return DiscoverFeedEngine(
    repository: MusicRepository(manager),
    artistScoresOverride: artistScores,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('adaptive weights', () {
    test('cold start (<10 signals) → 40/25/20/15', () {
      final e = _engine(
        provider: DiscoverFakeProvider(),
        artistScores: {'Arijit Singh': 1.0}, // 1 signal
      );
      expect(e.adaptiveWeights().personal, closeTo(0.40, 0.001));
      expect(e.adaptiveWeights().trending, closeTo(0.25, 0.001));
      expect(e.adaptiveWeights().exploration, closeTo(0.15, 0.001));
    });

    test('warm (10-99 signals) → 50/25/15/10', () {
      final scores = {
        for (var i = 0; i < 12; i++) 'Artist $i': (12 - i) / 12.0,
      };
      final e = _engine(
        provider: DiscoverFakeProvider(),
        artistScores: scores,
      );
      expect(e.adaptiveWeights().personal, closeTo(0.50, 0.001));
    });

    test('strong (>=100 signals) → 65/15/10/10', () {
      final e = _engine(
        provider: DiscoverFakeProvider(),
        artistScores: const {},
      );
      for (var i = 0; i < 100; i++) {
        e.recordSwipe(
          {'id': 'x$i', 'artist': 'Arijit Singh', 'title': 'Song'},
          outcome: DiscoverSwipeOutcome.listenedShort,
        );
      }
      expect(e.adaptiveWeights().personal, closeTo(0.65, 0.001));
    });
  });

  group('scoring', () {
    test('taste-matching artist outscores a stranger', () {
      final e = _engine(
        provider: DiscoverFakeProvider(),
        artistScores: const {'Arijit Singh': 10.0, 'Shreya Ghoshal': 5.0},
      );
      final favorite = {
        'id': 'a1',
        'title': 'Kesariya',
        'artist': 'Arijit Singh',
        'views': 1000,
        'ageDays': 3,
        'discoverSourceQuery': 'arijit songs',
      };
      final stranger = {
        'id': 'b1',
        'title': 'Unknown Track',
        'artist': 'Nobody',
        'views': 1000,
        'ageDays': 3,
        'discoverSourceQuery': 'random',
      };
      final s1 = e.scoreTrack(
        favorite,
        bucket: DiscoverBucket.personal,
        artistScores: const {'Arijit Singh': 10.0, 'Shreya Ghoshal': 5.0},
        activeArtists: const {'arijit singh'},
        activeGenres: const {'Romantic'},
        recentArtists: const {},
      );
      final s2 = e.scoreTrack(
        stranger,
        bucket: DiscoverBucket.personal,
        artistScores: const {'Arijit Singh': 10.0, 'Shreya Ghoshal': 5.0},
        activeArtists: const {'arijit singh'},
        activeGenres: const {'Romantic'},
        recentArtists: const {},
      );
      expect(s1, greaterThan(s2));
    });
  });

  group('nextBatch', () {
    test('dedupes excludeIds', () async {
      final provider = DiscoverFakeProvider(
        trendingTracks: [_t('t1', 'Arijit Singh'), _t('t2', 'Shreya Ghoshal')],
        searchTracks: [_t('s1', 'Arijit Singh'), _t('s2', 'Badshah')],
      );
      final e = _engine(provider: provider);
      final batch = await e.nextBatch(excludeIds: {'t1'}, count: 6);
      expect(batch.any((t) => t['id'] == 't1'), isFalse);
      expect(batch, isNotEmpty);
    });

    test('artist fatigue: a single dominating artist is capped', () async {
      final same = List.generate(12, (i) => _t('same$i', 'Repeat Artist'));
      final provider = DiscoverFakeProvider(
        trendingTracks: same,
        searchTracks: same,
      );
      final e = _engine(provider: provider);
      final batch = await e.nextBatch(excludeIds: const {}, count: 10);
      final repeatCount =
          batch.where((t) => t['artist'] == 'Repeat Artist').length;
      expect(repeatCount, lessThanOrEqualTo(2),
          reason: 'fatigue must prevent one artist filling the feed');
    });

    test('every card carries a reason, bucket and score', () async {
      final provider = DiscoverFakeProvider(
        trendingTracks: [
          _t('t1', 'Arijit Singh'),
          _t('t2', 'Shreya Ghoshal'),
          _t('t3', 'Badshah'),
        ],
        searchTracks: [
          _t('s1', 'Neha Kakkar'),
          _t('s2', 'Armaan Malik'),
          _t('s3', 'Jubin Nautiyal'),
          _t('s4', 'Asees Kaur'),
        ],
      );
      final e = _engine(provider: provider);
      final batch = await e.nextBatch(excludeIds: const {}, count: 8);
      expect(batch, isNotEmpty);
      for (final t in batch) {
        expect(t['discoverReason'], isA<String>());
        expect((t['discoverReason'] as String), isNotEmpty);
        expect(t['discoverBucket'], isA<String>());
        expect(double.tryParse('${t['discoverScore']}'), isNotNull);
      }
    });

    test('cold start includes trending bucket (no taste yet)', () async {
      final provider = DiscoverFakeProvider(
        trendingTracks: [_t('t1', 'Arijit Singh'), _t('t2', 'Badshah')],
        searchTracks: [_t('s1', 'Neha Kakkar')],
      );
      final e = _engine(provider: provider, artistScores: const {});
      final batch = await e.nextBatch(excludeIds: const {}, count: 6);
      expect(
        batch.any((t) => t['discoverBucket'] == 'trending'),
        isTrue,
        reason: 'cold start must surface trending content',
      );
    });

    test('exploration bucket appears when enabled', () async {
      final provider = DiscoverFakeProvider(
        trendingTracks: [_t('t1', 'Arijit Singh')],
        searchTracks: List.generate(10, (i) => _t('e$i', 'Explore Artist $i')),
      );
      final e = _engine(
        provider: provider,
        artistScores: const {'Arijit Singh': 1.0},
      );
      final batch = await e.nextBatch(excludeIds: const {}, count: 10);
      expect(
        batch.any((t) => t['discoverBucket'] == 'exploration'),
        isTrue,
      );
    });

    test('recordSwipe: skip is negative, long listen enters the window',
        () async {
      final provider = DiscoverFakeProvider(
        trendingTracks: [_t('t1', 'Arijit Singh')],
        searchTracks: [_t('s1', 'Neha Kakkar')],
      );
      final e = _engine(provider: provider);
      e.recordSwipe(
        {'id': 'skip1', 'artist': 'Skip Artist', 'title': 'S'},
        outcome: DiscoverSwipeOutcome.skippedImmediately,
      );
      expect(e.recentArtistsWindow, isEmpty,
          reason: 'immediate skips must not enter the positive window');
      e.recordSwipe(
        {'id': 'keep1', 'artist': 'Keep Artist', 'title': 'K'},
        outcome: DiscoverSwipeOutcome.listenedLong,
      );
      expect(e.recentArtistsWindow, contains('keep artist'));
      expect(e.sessionSignalCount, 2);
    });
  });
}
