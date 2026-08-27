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
  })  : _apiClient = apiClient ?? YouTubeDataApiClient(),
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
        ProviderCapability.getChannel,
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
  Future<ProviderResult<ProviderSearchPage>> searchPage(
    String query, {
    String order = 'relevance',
    int limit = 20,
    Set<String> excludeIds = const {},
    String? pageToken,
  }) async {
    try {
      final page = await _apiClient.searchMusicVideosPaginated(
        query,
        order: order,
        maxResults: limit,
        excludeIds: excludeIds,
        pageToken: pageToken,
      );
      final tracks = _mapper.mapSearchResults(
        page.items,
        limit: limit,
        excludeIds: excludeIds,
      );
      return ProviderResult.success(
        ProviderSearchPage(tracks: tracks, nextPageToken: page.nextPageToken),
      );
    } catch (e) {
      return ProviderResult.failure('YouTube searchPage failed: $e');
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
    String region = '',
  }) async {
    // Falls back to a viewCount search when the API key is absent/blocked.
    final popular = await _apiClient.getMostPopular(
      region: region,
      maxResults: limit * 2,
    );
    if (popular.isNotEmpty) {
      final tracks = popular
          .take(limit)
          .map(_mapper.toProviderTrack)
          .where((ProviderTrack t) => t.id.isNotEmpty)
          .toList();
      if (tracks.isNotEmpty) return ProviderResult.success(tracks);
    }
    return search(
      'trending music hits official audio',
      order: 'viewCount',
      limit: limit,
    );
  }

  /// Channel uploads via the official Data API: resolves '@handle' with
  /// channels.list?forHandle, then searches channelId uploads (date order).
  @override
  Future<ProviderResult<List<ProviderTrack>>> getChannelTracks(
    String channelId, {
    int limit = 30,
  }) async {
    var id = channelId.trim();
    if (id.isEmpty) return ProviderResult.failure('empty channel reference');
    if (id.startsWith('@')) {
      final resolved = await _apiClient.resolveHandleToChannelId(id);
      if (resolved == null || resolved.isEmpty) {
        return ProviderResult.failure('could not resolve channel handle');
      }
      id = resolved;
    }
    if (!RegExp(r'^UC[A-Za-z0-9_-]{22}$').hasMatch(id)) {
      return ProviderResult.failure('not a channel id');
    }
    final videos = await _apiClient.searchChannelVideos(
      id,
      maxResults: limit * 2,
    );
    if (videos.isEmpty) {
      return ProviderResult.failure('channel returned no videos');
    }
    final tracks = videos
        .take(limit)
        .map(_mapper.toProviderTrack)
        .where((ProviderTrack t) => t.id.isNotEmpty)
        .toList();
    if (tracks.isEmpty) {
      return ProviderResult.failure('channel had no playable videos');
    }
    return ProviderResult.success(tracks);
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
