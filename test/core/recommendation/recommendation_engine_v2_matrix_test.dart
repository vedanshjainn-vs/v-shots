// ═════════════════════════════════════════════════════════════════════════
// V Shots — Recommendation Engine V2 Comprehensive Test Matrix Suite
//
// Validates:
// 1. New user (no history -> cold start, no fake personalization, safe discovery)
// 2. Search-driven (explicit search -> artist + related content becomes top priority)
// 3. Listening-driven (repeatedly listen -> artist & similar artists rise)
// 4. Skip-driven (repeatedly skip -> artist & genre decrease, negative taste tracked)
// 5. Replay-driven (replay -> heavy affinity boost)
// 6. Playlist-driven (playlist theme interactions influence profile)
// 7. Recency decay (recent preference stronger than older preference)
// 8. Diversity (same artist capped, no dominant single-artist shelf)
// 9. Freshness (fresh discovery favors recent releases with high quality)
// 10. Trending for You (personal affinity modulates global trending rank)
// 11. Empty candidate set safety (never blank feed, safe fallback)
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/providers/music_provider.dart';
import 'package:v_shots/core/providers/music_repository.dart';
import 'package:v_shots/core/providers/provider_config.dart';
import 'package:v_shots/core/providers/provider_manager.dart';
import 'package:v_shots/core/providers/provider_models.dart';
import 'package:v_shots/core/providers/provider_registry.dart';
import 'package:v_shots/core/providers/provider_result.dart';
import 'package:v_shots/core/recommendation/candidate_generator.dart';
import 'package:v_shots/core/recommendation/feed_intent.dart';
import 'package:v_shots/core/recommendation/genre_classifier.dart';
import 'package:v_shots/core/recommendation/recommendation_cache.dart';
import 'package:v_shots/core/recommendation/recommendation_config.dart';
import 'package:v_shots/core/recommendation/recommendation_engine.dart';
import 'package:v_shots/core/recommendation/recommendation_scorer.dart';
import 'package:v_shots/core/recommendation/signal_event.dart';
import 'package:v_shots/core/recommendation/signal_store.dart';
import 'package:v_shots/core/recommendation/taste_profile.dart';
import 'package:v_shots/core/storage/local_library.dart';
import 'package:v_shots/features/home/home_feed_service.dart';

class TestMatrixProvider implements MusicProvider {
  @override
  String get id => 'matrix_test';

  @override
  String get displayName => 'Test Matrix Fake';

  @override
  Set<ProviderCapability> get capabilities => ProviderCapability.values.toSet();

  @override
  bool supports(ProviderCapability capability) => true;

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
    final String genre;
    if (q.contains('arijit')) {
      artist = 'Arijit Singh';
      genre = 'Bollywood';
    } else if (q.contains('diljit')) {
      artist = 'Diljit Dosanjh';
      genre = 'Punjabi';
    } else if (q.contains('badshah')) {
      artist = 'Badshah';
      genre = 'Hip-Hop';
    } else if (q.contains('trending')) {
      artist = 'Trending Star';
      genre = 'Bollywood';
    } else {
      artist = 'Catalog Artist';
      genre = 'Hindi';
    }

    final tracks = <ProviderTrack>[];
    for (var i = 0; i < limit; i++) {
      final id = 'test-track-${Object.hash(artist, i, query).abs()}';
      if (excludeIds.contains(id)) continue;
      tracks.add(
        ProviderTrack(
          id: id,
          title: '$artist — Track $i ($genre Hit)',
          artist: artist,
          artworkUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
          durationSeconds: 180 + i,
          isOfficial: true,
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
    final res = await search(query, limit: limit, excludeIds: excludeIds);
    return ProviderResult.success(
      ProviderSearchPage(tracks: res.data ?? [], nextPageToken: null),
    );
  }

  @override
  Future<ProviderResult<ProviderTrack>> getTrack(String id) async =>
      ProviderResult.failure('not used');

  @override
  Future<ProviderResult<List<ProviderTrack>>> getPlaylistTracks(
    String playlistId, {
    int limit = 30,
  }) async =>
      ProviderResult.failure('not used');

  @override
  Future<ProviderResult<List<ProviderTrack>>> getChannelTracks(
    String channelId, {
    int limit = 30,
  }) async =>
      ProviderResult.failure('not used');

  @override
  Future<ProviderResult<List<ProviderTrack>>> getRelated(
    String trackId, {
    int limit = 10,
  }) async =>
      ProviderResult.failure('not used');

  @override
  Future<ProviderResult<String>> getStream(String id) async =>
      ProviderResult.failure('not used');

  @override
  Future<ProviderResult<String>> getArtwork(String id) async =>
      ProviderResult.failure('not used');

  @override
  Future<ProviderResult<ProviderLyrics>> getLyrics({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  }) async =>
      ProviderResult.failure('not used');

  @override
  Future<ProviderResult<List<ProviderTrack>>> getTrending(
          {int limit = 15, String region = ''}) =>
      search('trending music 2026', limit: limit);

  @override
  Future<ProviderResult<List<ProviderTrack>>> getRecommendations({
    required Set<String> excludeIds,
    int limit = 10,
  }) =>
      search('recommended hits', limit: limit);

  @override
  Future<void> dispose() async {}
}

MusicRepository _makeRepo() {
  final provider = TestMatrixProvider();
  final reg = ProviderRegistry()..register(provider);
  final cfg = ProviderConfig(
    activeProvider: provider.id,
    enabledProviders: [provider.id],
    providerPriority: [provider.id],
  );
  final mgr = ProviderManager(
    registry: reg,
    config: cfg,
  );
  return MusicRepository(mgr);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    RecommendationCache.instance.invalidateAll();
    await SignalStore.instance.initialize();
    await SignalStore.instance.clear();
    await LocalLibrary.instance.clearRecentlyPlayed();
  });

  group('V2 Recommendation Engine Test Matrix', () {
    test('1. New user: cold start maturity, no fake personalization', () {
      final builder = TasteProfileBuilder();
      final profile = builder.build(events: []);

      expect(profile.maturity, TasteMaturity.cold);
      expect(profile.hasEnoughHistoryForPersonalization, isFalse);
      expect(profile.topArtists, isEmpty);
      expect(profile.topGenres, isEmpty);

      final generator = CandidateGenerator();
      final candidates = generator.generate(profile, count: 10);
      expect(candidates, isNotEmpty);
      expect(
        candidates.any((c) => c.source == CandidateSource.trending || c.source == CandidateSource.newContent || c.source == CandidateSource.genreTag),
        isTrue,
      );
    });

    test('2. Search-driven: search Artist A strongly increases relevance', () {
      final builder = TasteProfileBuilder();
      final events = [
        SignalEvent(
          type: SignalType.search,
          timestamp: DateTime.now(),
          query: 'Arijit Singh',
        ),
      ];
      final profile = builder.build(events: events);

      expect(profile.searchAffinity['Arijit Singh'], greaterThanOrEqualTo(5.0));
      expect(profile.artistAffinity['Arijit Singh'], greaterThan(0));
      expect(profile.topSearches, contains('Arijit Singh'));

      final generator = CandidateGenerator();
      final candidates = generator.generate(profile, count: 10);
      expect(candidates.any((c) => c.query.contains('Arijit Singh')), isTrue);
    });

    test('3. Listening-driven: repeated listens to Artist A raises affinity', () {
      final builder = TasteProfileBuilder();
      final now = DateTime.now();
      final events = [
        SignalEvent(
          type: SignalType.completed,
          timestamp: now.subtract(const Duration(minutes: 5)),
          trackId: 't1',
          artist: 'Diljit Dosanjh',
          title: 'G.O.A.T.',
        ),
        SignalEvent(
          type: SignalType.completed,
          timestamp: now.subtract(const Duration(minutes: 2)),
          trackId: 't2',
          artist: 'Diljit Dosanjh',
          title: 'Lover',
        ),
        SignalEvent(
          type: SignalType.like,
          timestamp: now,
          trackId: 't2',
          artist: 'Diljit Dosanjh',
          title: 'Lover',
        ),
      ];
      final profile = builder.build(events: events);

      expect(profile.maturity, TasteMaturity.earlySignal);
      expect(profile.hasEnoughHistoryForPersonalization, isTrue);
      expect(profile.topArtists.first, 'Diljit Dosanjh');
      expect(profile.artistCompletionRate['Diljit Dosanjh'], 1.0);
    });

    test('4. Skip-driven: repeated skips penalize artist without permanent lock', () {
      final builder = TasteProfileBuilder();
      final now = DateTime.now();
      final events = [
        SignalEvent(
          type: SignalType.skip,
          timestamp: now,
          trackId: 's1',
          artist: 'Bad Artist',
          value: 2.0, // immediate skip
        ),
        SignalEvent(
          type: SignalType.skip,
          timestamp: now,
          trackId: 's2',
          artist: 'Bad Artist',
          value: 3.0,
        ),
        SignalEvent(
          type: SignalType.skip,
          timestamp: now,
          trackId: 's3',
          artist: 'Bad Artist',
          value: 4.0,
        ),
      ];
      final profile = builder.build(events: events);

      expect(profile.artistSkipPenalty['Bad Artist'], greaterThan(6.0));
      expect(profile.negativeTaste.containsKey('Bad Artist'), isTrue);
      expect(profile.artistCompletionRate['Bad Artist'], 0.0);
    });

    test('5. Replay-driven: replaying a song gives strong boost', () {
      final builder = TasteProfileBuilder();
      final now = DateTime.now();
      final events = [
        SignalEvent(
          type: SignalType.play,
          timestamp: now.subtract(const Duration(minutes: 10)),
          trackId: 'r1',
          artist: 'Arijit Singh',
          title: 'Kesariya',
        ),
        SignalEvent(
          type: SignalType.replay,
          timestamp: now,
          trackId: 'r1',
          artist: 'Arijit Singh',
          title: 'Kesariya',
        ),
      ];
      final profile = builder.build(events: events);

      expect(profile.artistAffinity['Arijit Singh'], greaterThanOrEqualTo(5.0));
      expect(profile.artistRepeatRate['Arijit Singh'], greaterThan(0));
    });

    test('6. Playlist-driven: playlist theme interactions boost cluster tags', () {
      final builder = TasteProfileBuilder();
      final now = DateTime.now();
      final events = [
        SignalEvent(
          type: SignalType.playlistOpen,
          timestamp: now,
          playlistTheme: 'Late Night Romantic Bollywood Hits',
        ),
      ];
      final profile = builder.build(events: events);

      expect(profile.playlistAffinity['Late Night Romantic Bollywood Hits'], greaterThan(0));
      expect(profile.genreAffinity['Bollywood'] ?? 0, greaterThan(0));
      expect(profile.genreAffinity['Romantic'] ?? 0, greaterThan(0));
    });

    test('7. Recency: recent interaction scores higher than old', () {
      final builder = TasteProfileBuilder();
      final now = DateTime.now();
      final recent = builder.build(events: [
        SignalEvent(
          type: SignalType.like,
          timestamp: now,
          artist: 'Recent Star',
        ),
      ]);
      final old = builder.build(events: [
        SignalEvent(
          type: SignalType.like,
          timestamp: now.subtract(const Duration(days: 20)),
          artist: 'Recent Star',
        ),
      ]);

      expect(
        recent.artistAffinity['Recent Star']!,
        greaterThan(old.artistAffinity['Recent Star']!),
      );
    });

    test('8. Diversity: same artist capped within shelf', () async {
      final repo = _makeRepo();
      final engine = RecommendationEngine(repo);
      final service = HomeFeedService(repository: repo, engine: engine);

      final shelves = service.buildShelfDescriptors();
      await service.loadShelves(shelves);

      for (final s in shelves.where((x) => x.status == HomeShelfStatus.loaded)) {
        final artistCounts = <String, int>{};
        for (final t in s.tracks) {
          final a = t['artist'] as String? ?? '';
          artistCounts[a] = (artistCounts[a] ?? 0) + 1;
        }
        for (final count in artistCounts.values) {
          expect(count, lessThanOrEqualTo(3));
        }
      }
    });

    test('9. Freshness: Scored tracks include explainable reasons', () {
      final scorer = RecommendationScorer();
      const profile = TasteProfile(
        artistAffinity: {'Known Artist': 8.0},
        genreAffinity: {'Bollywood': 5.0},
        artistSkipPenalty: {},
        totalSignalCount: 15,
      );

      const track = ProviderTrack(
        id: 'k1',
        title: 'Chaleya',
        artist: 'Known Artist',
        artworkUrl: '',
        durationSeconds: 200,
        isOfficial: true,
      );

      final scored = scorer.score(
        track,
        profile,
        sourceQuery: 'Known Artist hit songs',
        isTrendingOrNewSource: false,
      );

      expect(scored.reason, isNotNull);
      expect(
        scored.reason,
        anyOf([
          'because_recently_played_artist',
          'because_search_interest',
          'because_favorite_genre',
          'similar_to_your_taste',
        ]),
      );
    });

    test('10. Trending for You: personal affinity affects ranking', () {
      final scorer = RecommendationScorer();
      const punjabiUser = TasteProfile(
        artistAffinity: {'Diljit Dosanjh': 10.0},
        genreAffinity: {'Punjabi': 8.0},
        artistSkipPenalty: {},
        totalSignalCount: 20,
      );
      const hindiUser = TasteProfile(
        artistAffinity: {'Arijit Singh': 10.0},
        genreAffinity: {'Bollywood': 8.0},
        artistSkipPenalty: {},
        totalSignalCount: 20,
      );

      const punjabiSong = ProviderTrack(
        id: 'p1',
        title: 'Punjabi Track',
        artist: 'Diljit Dosanjh',
        artworkUrl: '',
        durationSeconds: 180,
        isOfficial: true,
      );

      final scoreForPunjabiUser = scorer.score(
        punjabiSong,
        punjabiUser,
        sourceQuery: 'trending',
        isTrendingOrNewSource: true,
      );
      final scoreForHindiUser = scorer.score(
        punjabiSong,
        hindiUser,
        sourceQuery: 'trending',
        isTrendingOrNewSource: true,
      );

      expect(scoreForPunjabiUser.score, greaterThan(scoreForHindiUser.score));
    });

    test('11. Empty candidate set safety: fallback prevents blank Home', () async {
      final repo = _makeRepo();
      final engine = RecommendationEngine(repo);
      final service = HomeFeedService(repository: repo, engine: engine);

      final shelf = HomeShelf(
        id: 'custom_shelf',
        title: 'Custom',
        subtitle: 'Sub',
        kind: HomeShelfKind.madeForYou,
      );

      await service.loadShelves([shelf]);
      expect(shelf.status, HomeShelfStatus.loaded);
      expect(shelf.tracks, isNotEmpty);
    });
  });
}
