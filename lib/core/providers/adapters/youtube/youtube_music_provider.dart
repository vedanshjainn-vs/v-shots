// ═════════════════════════════════════════════════════════════════════════════
// V Shots — YouTubeMusicProvider (Official YouTube Data API Provider)
// ═════════════════════════════════════════════════════════════════════════════

import '../../../lyrics/lyrics_service.dart';
import '../../music_provider.dart';
import '../../provider_models.dart';
import '../../provider_result.dart';
import 'youtube_data_api_client.dart';
import 'youtube_music_mapper.dart';

class YouTubeMusicProvider extends MusicProvider {
  YouTubeMusicProvider({
    YouTubeDataApiClient? apiClient,
    YoutubeMusicMapper mapper = const YoutubeMusicMapper(),
    LyricsService? lyricsService,
  }) : _apiClient = apiClient ?? YouTubeDataApiClient(),
       _mapper = mapper,
       _lyrics = lyricsService ?? LyricsService.instance;

  final YouTubeDataApiClient _apiClient;
  final YoutubeMusicMapper _mapper;
  final LyricsService _lyrics;

  @override
  String get id => 'youtube';

  @override
  String get displayName => 'YouTube';

  @override
  Set<ProviderCapability> get capabilities => const {
    ProviderCapability.search,
    ProviderCapability.getTrack,
    ProviderCapability.getArtwork,
    ProviderCapability.getLyrics,
    ProviderCapability.getTrending,
    ProviderCapability.getRecommendations,
  };

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<ProviderHealth> healthCheck() async {
    if (!_initialized) {
      return const ProviderHealth(healthy: false, message: 'not initialized');
    }
    try {
      final results = await _apiClient.searchMusicVideos('a', maxResults: 1);
      return ProviderHealth(healthy: results.isNotEmpty);
    } catch (e) {
      return ProviderHealth(healthy: false, message: '$e');
    }
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> search(
    String query, {
    String order = 'relevance',
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) async {
    try {
      final results = await _apiClient.searchMusicVideos(
        query,
        order: order,
        maxResults: limit,
        excludeIds: excludeIds,
      );
      final tracks = _mapper.mapSearchResults(
        results,
        limit: limit,
        maxMinutes: maxDurationMinutes,
        minMinutes: minDurationMinutes,
        excludeIds: excludeIds,
      );
      return ProviderResult.success(tracks);
    } catch (e) {
      return ProviderResult.failure('YouTube search failed: $e');
    }
  }

  @override
  Future<ProviderResult<ProviderTrack>> getTrack(String id) async {
    try {
      final video = await _apiClient.getVideoDetails(id);
      if (video == null) {
        return ProviderResult.failure('Track $id not found');
      }
      return ProviderResult.success(_mapper.toProviderTrack(video));
    } catch (e) {
      return ProviderResult.failure('YouTube getTrack failed: $e');
    }
  }

  @override
  Future<ProviderResult<String>> getStream(String id) async {
    return ProviderResult.failure(
      'YouTube audio extraction is prohibited. Use official YouTube Player for playback.',
    );
  }

  @override
  Future<ProviderResult<String>> getArtwork(String id) async {
    final trackResult = await getTrack(id);
    if (trackResult.isFailure) {
      return ProviderResult.failure(trackResult.error!);
    }
    return ProviderResult.success(trackResult.data!.artworkUrl);
  }

  @override
  Future<ProviderResult<ProviderLyrics>> getLyrics({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  }) async {
    final result = await _lyrics.fetch(
      trackName: trackName,
      artistName: artistName,
      durationSeconds: durationSeconds,
    );
    if (!result.hasAny) {
      return ProviderResult.failure('No lyrics found');
    }
    return ProviderResult.success(
      ProviderLyrics(
        plainText: result.plainText,
        hasSynced: result.hasSynced,
        instrumental: result.instrumental,
      ),
    );
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> getTrending({
    int limit = 15,
  }) async {
    return search(
      'trending music hits official audio',
      order: 'viewCount',
      limit: limit,
    );
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> getRecommendations({
    required Set<String> excludeIds,
    int limit = 10,
  }) async {
    return search(
      'popular hits music playlist',
      limit: limit,
      excludeIds: excludeIds,
    );
  }

  @override
  Future<void> dispose() async {
    _apiClient.dispose();
  }
}
