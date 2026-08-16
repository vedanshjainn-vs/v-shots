// ═════════════════════════════════════════════════════════════════════════════
// V Shots — RecommendationEngine "More Like This" candidate-source tests
//
// Proves that FeedIntent.moreLikeThis with a seed track resolves candidates
// from the provider's related-content endpoint (InnerTube /next) — a
// genuinely different source than query-string search — and re-ranks them
// through the normal scoring/diversity pipeline, with graceful fallback to
// query-based generation when related returns nothing.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/providers/music_provider.dart';
import 'package:v_shots/core/providers/music_repository.dart';
import 'package:v_shots/core/providers/provider_config.dart';
import 'package:v_shots/core/providers/provider_manager.dart';
import 'package:v_shots/core/providers/provider_models.dart';
import 'package:v_shots/core/providers/provider_registry.dart';
import 'package:v_shots/core/providers/provider_result.dart';
import 'package:v_shots/core/recommendation/feed_intent.dart';
import 'package:v_shots/core/recommendation/recommendation_cache.dart';
import 'package:v_shots/core/recommendation/recommendation_engine.dart';
import 'package:v_shots/core/recommendation/signal_store.dart';
import 'package:v_shots/core/storage/local_library.dart';

/// A fully-controllable fake that distinguishes RELATED results (artist
/// "Related Artist", from getRelated) from SEARCH results (artist
/// "Search Artist", from search) so tests can assert WHICH source produced
/// the feed.
class RelatedFakeProvider implements MusicProvider {
  RelatedFakeProvider({this.emptyRelated = false});

  bool emptyRelated;
  int relatedCallCount = 0;
  int searchCallCount = 0;

  @override
  String get id => 'innertube';

  @override
  String get displayName => 'Related Fake';

  @override
  Set<ProviderCapability> get capabilities => const {
        ProviderCapability.search,
        ProviderCapability.getRelated,
        ProviderCapability.getTrending,
        ProviderCapability.getRecommendations,
      };

  @override
  bool supports(ProviderCapability capability) =>
      capabilities.contains(capability);

  @override
  Future<void> initialize() async {}

  @override
  Future<ProviderHealth> healthCheck() async =>
      const ProviderHealth(healthy: true);

  ProviderTrack _track(String id, String artist) => ProviderTrack(
        id: id,
        title: '$artist — $id',
        artist: artist,
        artworkUrl: '',
        durationSeconds: 200,
      );

  @override
  Future<ProviderResult<List<ProviderTrack>>> search(
    String query, {
    String order = 'relevance',
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) async {
    searchCallCount++;
    return ProviderResult.success(
      List.generate(limit, (i) => _track('search-$query-$i', 'Search Artist')),
    );
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
  Future<ProviderResult<List<ProviderTrack>>> getRelated(
    String trackId, {
    int limit = 10,
  }) async {
    relatedCallCount++;
    if (emptyRelated) return ProviderResult.success(const []);
    return ProviderResult.success(
      List.generate(
        limit,
        (i) => _track('related-$trackId-$i', 'Related Artist'),
      ),
    );
  }

  @override
  Future<ProviderResult<ProviderTrack>> getTrack(String id) async =>
      ProviderResult.failure('unused');

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

MusicRepository _repository(RelatedFakeProvider provider) {
  final registry = ProviderRegistry()..register(provider);
  final manager = ProviderManager(
    registry: registry,
    config: ProviderConfig.defaultConfig,
  );
  return MusicRepository(manager);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    RecommendationCache.instance.invalidateAll();
    await SignalStore.instance.clear();
    await LocalLibrary.instance.clearRecentlyPlayed();
  });

  group('More Like This candidate source', () {
    test('resolves related videos (not search) for a seed track', () async {
      final provider = RelatedFakeProvider();
      final engine = RecommendationEngine(_repository(provider));

      final feed = await engine.generateFeed(
        intent: FeedIntent.moreLikeThis,
        excludeIds: const {},
        seedTrackId: 'seed1',
        count: 10,
        forceRefresh: true,
      );

      expect(provider.relatedCallCount, 1,
          reason: 'a seeded moreLikeThis must hit the related endpoint');
      expect(provider.searchCallCount, 0,
          reason: 'related candidates must come from getRelated, not search');
      expect(feed, isNotEmpty);
      expect(feed.every((s) => s.track.artist == 'Related Artist'), isTrue,
          reason: 'the feed must be built from related candidates');
      expect(
          feed.every((s) => s.track.id.startsWith('related-seed1-')), isTrue);
    });

    test('never includes the seed track itself', () async {
      final provider = RelatedFakeProvider();
      final engine = RecommendationEngine(_repository(provider));

      final feed = await engine.generateFeed(
        intent: FeedIntent.moreLikeThis,
        excludeIds: const {},
        seedTrackId: 'seed1',
        count: 10,
        forceRefresh: true,
      );

      expect(
        feed.any((s) => s.track.id == 'seed1'),
        isFalse,
        reason: 'the seed video must be excluded from its own related list',
      );
    });

    test('falls back to query-based generation when related is empty',
        () async {
      final provider = RelatedFakeProvider(emptyRelated: true);
      final engine = RecommendationEngine(_repository(provider));

      final feed = await engine.generateFeed(
        intent: FeedIntent.moreLikeThis,
        excludeIds: const {},
        seedTrackId: 'seed1',
        count: 10,
        forceRefresh: true,
      );

      expect(provider.relatedCallCount, 1);
      expect(provider.searchCallCount, greaterThan(0),
          reason: 'empty related must fall through to query-based search');
      expect(feed, isNotEmpty,
          reason: 'a seeded moreLikeThis must never return a blank feed');
    });

    test('a non-seeded moreLikeThis uses query-based generation', () async {
      final provider = RelatedFakeProvider();
      final engine = RecommendationEngine(_repository(provider));

      final feed = await engine.generateFeed(
        intent: FeedIntent.moreLikeThis,
        excludeIds: const {},
        count: 10,
        forceRefresh: true,
      );

      expect(provider.relatedCallCount, 0,
          reason: 'without a seed there is nothing to call related() on');
      expect(feed, isNotEmpty);
    });

    test('honors excludeIds', () async {
      final provider = RelatedFakeProvider();
      final engine = RecommendationEngine(_repository(provider));

      final feed = await engine.generateFeed(
        intent: FeedIntent.moreLikeThis,
        excludeIds: {'related-seed1-0', 'related-seed1-1'},
        seedTrackId: 'seed1',
        count: 10,
        forceRefresh: true,
      );

      expect(
        feed.any((s) =>
            s.track.id == 'related-seed1-0' || s.track.id == 'related-seed1-1'),
        isFalse,
      );
    });
  });
}
