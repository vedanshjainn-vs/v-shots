// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Home CMS source-type routing tests (PHASE 17)
// Proves that youtube_playlist / youtube_channel / youtube_trending shelves
// route to REAL provider calls (not literal searches), that the JioSaavn
// playlist source opens the page, and that max_items is respected.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/providers/music_provider.dart';
import 'package:v_shots/core/providers/music_repository.dart';
import 'package:v_shots/core/providers/provider_manager.dart';
import 'package:v_shots/core/providers/provider_models.dart';
import 'package:v_shots/core/providers/provider_registry.dart';
import 'package:v_shots/core/providers/provider_result.dart';
import 'package:v_shots/features/home/home_feed_service.dart';

/// Provider whose playlist/channel/trending calls return distinct tracks so
/// tests can assert WHICH source actually produced the shelf content.
class SourceTrackingProvider implements MusicProvider {
  final List<String> playlistCalls = [];
  final List<String> channelCalls = [];
  final List<String> trendingRegions = [];

  @override
  String get id => 'innertube';

  @override
  String get displayName => 'Source Tracking Fake';

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

  static const _artists = [
    'Arijit Singh',
    'Shreya Ghoshal',
    'A.R. Rahman',
    'Badshah',
    'Neha Kakkar',
    'Armaan Malik',
  ];

  ProviderTrack _track(String id, String artist) => ProviderTrack(
        id: id,
        title: '$artist — song ${id.hashCode % 100}',
        artist: artist,
        artworkUrl: '',
        durationSeconds: 200,
        isOfficial: true,
      );

  @override
  Future<ProviderResult<List<ProviderTrack>>> getPlaylistTracks(
    String playlistId, {
    int limit = 30,
  }) async {
    playlistCalls.add('$playlistId@$limit');
    return ProviderResult.success(
      List.generate(limit,
          (i) => _track('pl_${playlistId}_$i', _artists[i % _artists.length])),
    );
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> getChannelTracks(
    String channelId, {
    int limit = 30,
  }) async {
    channelCalls.add('$channelId@$limit');
    return ProviderResult.success(
      List.generate(limit,
          (i) => _track('ch_${channelId}_$i', _artists[i % _artists.length])),
    );
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> getTrending({
    int limit = 15,
    String region = '',
  }) async {
    trendingRegions.add(region);
    return ProviderResult.success(
      List.generate(limit,
          (i) => _track('tr_${region}_$i', _artists[i % _artists.length])),
    );
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> search(
    String query, {
    String order = 'relevance',
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) async =>
      ProviderResult.success([_track('search_$query', 'Arijit Singh')]);

  @override
  Future<ProviderResult<ProviderSearchPage>> searchPage(
    String query, {
    String order = 'relevance',
    int limit = 20,
    Set<String> excludeIds = const {},
    String? pageToken,
  }) async =>
      ProviderResult.success(
        ProviderSearchPage(tracks: [_track('search_$query', 'Arijit Singh')]),
      );

  @override
  Future<ProviderResult<ProviderTrack>> getTrack(String id) async =>
      ProviderResult.success(_track(id, 'X'));

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SourceTrackingProvider provider;
  late HomeFeedService service;

  setUp(() {
    provider = SourceTrackingProvider();
    final registry = ProviderRegistry()..register(provider);
    final manager = ProviderManager(registry: registry);
    service = HomeFeedService(repository: MusicRepository(manager));
  });

  Map<String, dynamic> section(String id, String type, String value,
      {int maxItems = 10, String? region}) {
    return {
      'id': id,
      'section_key': id,
      'title': id,
      'source_type': type,
      'source_value': value,
      'query': null,
      'sort_order': 1,
      'visible': true,
      'published': true,
      'max_items': maxItems,
      if (region != null) 'region_code': region,
    };
  }

  group('Home CMS source routing', () {
    test('youtube_playlist routes to getPlaylistTracks (real id, order, limit)',
        () async {
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: [
          section(
            'mylist',
            'youtube_playlist',
            'https://www.youtube.com/playlist?list=PLabc123xyz',
            maxItems: 7,
          ),
        ],
      );
      final shelf = shelves.singleWhere((s) => s.id == 'mylist');
      expect(shelf.query, isNull);
      await service.loadShelves([shelf]);
      final tracks = shelf.tracks;
      expect(provider.playlistCalls, ['PLabc123xyz@7']);
      expect(tracks.length, 7);
      expect(tracks.first['id'], 'pl_PLabc123xyz_0');
    });

    test('youtube_channel routes to getChannelTracks', () async {
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: [
          section(
              'mychan', 'youtube_channel', 'https://www.youtube.com/@artist',
              maxItems: 5),
        ],
      );
      final shelf = shelves.singleWhere((s) => s.id == 'mychan');
      await service.loadShelves([shelf]);
      final tracks = shelf.tracks;
      expect(provider.channelCalls, ['@artist@5']);
      expect(tracks.length, 5);
      expect(tracks.first['id'], 'ch_@artist_0');
    });

    test('youtube_trending routes to getTrending with region', () async {
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: [
          section('trend', 'youtube_trending', '', maxItems: 6, region: 'US'),
        ],
      );
      final shelf = shelves.singleWhere((s) => s.id == 'trend');
      await service.loadShelves([shelf]);
      final tracks = shelf.tracks;
      expect(provider.trendingRegions, ['US']);
      expect(tracks.length, 6);
      expect(tracks.first['id'], 'tr_US_0');
    });

    test('invalid playlist URL does NOT fall through to a literal search',
        () async {
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: [
          section('bad', 'youtube_playlist', 'not-a-playlist', maxItems: 5),
        ],
      );
      final shelf = shelves.singleWhere((s) => s.id == 'bad');
      await service.loadShelves([shelf]);
      final tracks = shelf.tracks;
      expect(tracks, isEmpty);
      expect(provider.playlistCalls, isEmpty);
    });

    test('jiosaavn_playlist becomes a single page-open card (compliant)', () {
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        jiosaavnEnabled: true,
        cmsSections: [
          section(
            'jpl',
            'jiosaavn_playlist',
            'https://www.jiosaavn.com/featured/weekly-top-songs/xYz',
          ),
        ],
      );
      final shelf = shelves.singleWhere((s) => s.id == 'jpl');
      expect(shelf.kind, HomeShelfKind.manual);
      expect(shelf.manualItems.length, 1);
      expect(shelf.manualItems.first['jiosaavnUrl'],
          'https://www.jiosaavn.com/featured/weekly-top-songs/xYz');
      expect(shelf.manualItems.first['playbackSource'], 'jiosaavn');
    });

    test('jiosaavn_playlist hidden when the JioSaavn flag is OFF', () {
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        jiosaavnEnabled: false,
        cmsSections: [
          section(
            'jpl',
            'jiosaavn_playlist',
            'https://www.jiosaavn.com/featured/weekly-top-songs/xYz',
          ),
        ],
      );
      expect(shelves.where((s) => s.id == 'jpl'), isEmpty);
    });

    test('personalized keys stay personalized (parity guard)', () {
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: [
          {
            'id': 'made_for_you',
            'section_key': 'made_for_you',
            'title': 'Made For You',
            'source_type': 'personalized',
            'source_value': 'made_for_you',
            'visible': true,
            'published': true,
            'max_items': 12,
          },
        ],
      );
      final shelf = shelves.singleWhere((s) => s.id == 'made_for_you');
      expect(shelf.kind, HomeShelfKind.madeForYou);
    });
  });
}
