// ═════════════════════════════════════════════════════════════════════════════
// V Shots — YouTube Data API v3 Client (120+ Curated Categorized Catalog)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Data model representing a YouTube video metadata item from Data API v3.
class YouTubeVideoItem {
  const YouTubeVideoItem({
    required this.id,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.durationSeconds,
    this.publishedAt,
    this.viewCount,
    this.category = 'music',
  });

  final String id;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final int durationSeconds;
  final DateTime? publishedAt;
  final int? viewCount;
  final String category;

  factory YouTubeVideoItem.fromJson(
    Map<String, dynamic> json, {
    int duration = 0,
    String category = 'music',
  }) {
    final idVal = json['id'];
    String videoId = '';
    if (idVal is Map) {
      videoId = (idVal['videoId'] as String?) ?? '';
    } else if (idVal is String) {
      videoId = idVal;
    }

    final snippet = (json['snippet'] as Map<String, dynamic>?) ?? {};
    final title = (snippet['title'] as String?) ?? 'Unknown Track';
    final channelTitle =
        (snippet['channelTitle'] as String?) ?? 'Unknown Artist';

    final thumbnails = (snippet['thumbnails'] as Map<String, dynamic>?) ?? {};
    final maxres = thumbnails['maxres']?['url'] as String?;
    final high = thumbnails['high']?['url'] as String?;
    final medium = thumbnails['medium']?['url'] as String?;
    final def = thumbnails['default']?['url'] as String?;
    final thumb = maxres ??
        high ??
        medium ??
        def ??
        (videoId.isNotEmpty
            ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
            : '');

    int parsedDuration = duration;
    final contentDetails = json['contentDetails'] as Map<String, dynamic>?;
    if (contentDetails != null && contentDetails['duration'] is String) {
      parsedDuration = parseIso8601Duration(
        contentDetails['duration'] as String,
      );
    }

    DateTime? published;
    if (snippet['publishedAt'] is String) {
      published = DateTime.tryParse(snippet['publishedAt'] as String);
    }

    int? views;
    final statistics = json['statistics'] as Map<String, dynamic>?;
    if (statistics != null && statistics['viewCount'] is String) {
      views = int.tryParse(statistics['viewCount'] as String);
    }

    return YouTubeVideoItem(
      id: videoId,
      title: title,
      channelTitle: channelTitle,
      thumbnailUrl: thumb,
      durationSeconds: parsedDuration,
      publishedAt: published,
      viewCount: views,
      category: category,
    );
  }

  static int parseIso8601Duration(String iso) {
    if (iso.isEmpty) return 0;
    try {
      final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
      final match = regex.firstMatch(iso);
      if (match == null) return 0;
      final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
      return (hours * 3600) + (minutes * 60) + seconds;
    } catch (_) {
      return 0;
    }
  }
}

/// A page of search results plus the token to fetch the next page.
class PaginatedSearchResult {
  const PaginatedSearchResult({required this.items, this.nextPageToken});
  final List<YouTubeVideoItem> items;
  final String? nextPageToken;
}

/// Official YouTube Data API v3 HTTP Client with built-in resilience,
/// rate-limiting protection, and rich categorized music fallback catalog.
class YouTubeDataApiClient {
  YouTubeDataApiClient({http.Client? httpClient, String? apiKey})
      : _http = httpClient ?? http.Client(),
        _customApiKey = apiKey;

  final http.Client _http;
  final String? _customApiKey;

  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';

  String get apiKey {
    final custom = _customApiKey;
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    if (dotenv.isInitialized) {
      final fromEnv = dotenv.maybeGet('YOUTUBE_DATA_API_KEY');
      if (fromEnv != null && fromEnv.isNotEmpty) {
        return fromEnv;
      }
    }
    const compileTimeKey = String.fromEnvironment('YOUTUBE_DATA_API_KEY');
    if (compileTimeKey.isNotEmpty) {
      return compileTimeKey;
    }
    return '';
  }

  /// Searches for music videos using YouTube Data API v3.
  Future<List<YouTubeVideoItem>> searchMusicVideos(
    String query, {
    String order = 'relevance',
    int maxResults = 20,
    Set<String> excludeIds = const {},
  }) async {
    final key = apiKey;
    if (key.isEmpty) {
      return _fallbackSearch(
        query,
        order: order,
        maxResults: maxResults,
        excludeIds: excludeIds,
      );
    }

    try {
      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {
          'part': 'snippet',
          'type': 'video',
          'videoCategoryId': '10', // Music category
          'q': query,
          'order': order,
          'maxResults': maxResults.clamp(1, 50).toString(),
          'key': key,
        },
      );

      final response = await _http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['items'] as List?) ?? [];

        final videoIds = <String>[];
        final rawItems = <Map<String, dynamic>>[];

        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final id = item['id']?['videoId'] as String?;
            if (id != null && id.isNotEmpty && !excludeIds.contains(id)) {
              videoIds.add(id);
              rawItems.add(item);
            }
          }
        }

        if (videoIds.isEmpty) return [];

        final durationMap = await _fetchVideoDurations(videoIds, key: key);

        return rawItems.map((item) {
          final vid = item['id']?['videoId'] as String? ?? '';
          final dur = durationMap[vid] ?? 210;
          return YouTubeVideoItem.fromJson(item, duration: dur);
        }).toList();
      } else {
        debugPrint(
          '[YouTubeDataApiClient] Search HTTP ${response.statusCode}: ${response.body}',
        );
        return _fallbackSearch(
          query,
          order: order,
          maxResults: maxResults,
          excludeIds: excludeIds,
        );
      }
    } catch (e) {
      debugPrint('[YouTubeDataApiClient] Search network error: $e');
      return _fallbackSearch(
        query,
        order: order,
        maxResults: maxResults,
        excludeIds: excludeIds,
      );
    }
  }

  /// Fetches metadata for a single YouTube video by its video ID.
  /// Resolves the official YouTube channel avatar image URL for [artistName].
  ///
  /// Uses the YouTube Data API Channels/Search metadata flow ONLY. Returns
  /// null when no API key is configured or the channel cannot be found, so
  /// callers must keep a graceful fallback. This is what powers real Top
  /// Artist images without ever fabricating a URL when the key is missing.
  Future<String?> resolveChannelAvatar(String artistName) async {
    final key = apiKey;
    if (key.isEmpty) return null;
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {
          'part': 'snippet',
          'type': 'channel',
          'q': artistName,
          'maxResults': '1',
          'key': key,
        },
      );
      final response = await _http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];
      if (items.isEmpty) return null;
      final snippet = (items.first as Map<String, dynamic>)['snippet']
          as Map<String, dynamic>?;
      if (snippet == null) return null;
      final thumbs = (snippet['thumbnails'] as Map<String, dynamic>?) ?? {};
      final url = (thumbs['high']?['url'] ??
          thumbs['medium']?['url'] ??
          thumbs['default']?['url']) as String?;
      return (url == null || url.isEmpty) ? null : url;
    } catch (e) {
      debugPrint('[YouTubeDataApiClient] resolveChannelAvatar error: $e');
      return null;
    }
  }

  /// Real Data-API pagination: returns one page of results plus the
  /// [nextPageToken] to request the following page. Falls back to the verified
  /// category-specific catalog when no API key is configured (with
  /// [nextPageToken] null so the caller knows there are no more pages).
  Future<PaginatedSearchResult> searchMusicVideosPaginated(
    String query, {
    String order = 'relevance',
    int maxResults = 20,
    Set<String> excludeIds = const {},
    String? pageToken,
  }) async {
    final key = apiKey;
    if (key.isEmpty) {
      return PaginatedSearchResult(
        items: _fallbackSearch(
          query,
          order: order,
          maxResults: maxResults,
          excludeIds: excludeIds,
        ),
        nextPageToken: null,
      );
    }
    try {
      final params = <String, String>{
        'part': 'snippet',
        'type': 'video',
        'videoCategoryId': '10',
        'q': query,
        'order': order,
        'maxResults': maxResults.clamp(1, 50).toString(),
        'key': key,
      };
      if (pageToken != null && pageToken.isNotEmpty) {
        params['pageToken'] = pageToken;
      }
      final uri =
          Uri.parse('$_baseUrl/search').replace(queryParameters: params);
      final response = await _http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint(
          '[YouTubeDataApiClient] Paginated search HTTP ${response.statusCode}',
        );
        return PaginatedSearchResult(
          items: _fallbackSearch(
            query,
            order: order,
            maxResults: maxResults,
            excludeIds: excludeIds,
          ),
          nextPageToken: null,
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];
      final videoIds = <String>[];
      final rawItems = <Map<String, dynamic>>[];
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          final id = item['id']?['videoId'] as String?;
          if (id != null && id.isNotEmpty && !excludeIds.contains(id)) {
            videoIds.add(id);
            rawItems.add(item);
          }
        }
      }
      final durationMap = videoIds.isEmpty
          ? <String, int>{}
          : await _fetchVideoDurations(videoIds, key: key);
      final mapped = rawItems.map((item) {
        final vid = item['id']?['videoId'] as String? ?? '';
        return YouTubeVideoItem.fromJson(
          item,
          duration: durationMap[vid] ?? 210,
        );
      }).toList();
      return PaginatedSearchResult(
        items: mapped,
        nextPageToken: data['nextPageToken'] as String?,
      );
    } catch (e) {
      debugPrint('[YouTubeDataApiClient] Paginated search error: $e');
      return PaginatedSearchResult(
        items: _fallbackSearch(
          query,
          order: order,
          maxResults: maxResults,
          excludeIds: excludeIds,
        ),
        nextPageToken: null,
      );
    }
  }

  Future<YouTubeVideoItem?> getVideoDetails(String videoId) async {
    final key = apiKey;
    if (key.isEmpty) {
      return _fallbackGetVideo(videoId);
    }

    try {
      final uri = Uri.parse('$_baseUrl/videos').replace(
        queryParameters: {
          'part': 'snippet,contentDetails,statistics',
          'id': videoId,
          'key': key,
        },
      );

      final response = await _http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['items'] as List?) ?? [];
        if (items.isNotEmpty && items.first is Map<String, dynamic>) {
          return YouTubeVideoItem.fromJson(items.first as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[YouTubeDataApiClient] GetVideo error for $videoId: $e');
    }

    return _fallbackGetVideo(videoId);
  }

  /// Fetches duration in seconds for a list of video IDs.
  Future<Map<String, int>> _fetchVideoDurations(
    List<String> videoIds, {
    required String key,
  }) async {
    if (videoIds.isEmpty || key.isEmpty) return {};
    final result = <String, int>{};

    try {
      final uri = Uri.parse('$_baseUrl/videos').replace(
        queryParameters: {
          'part': 'contentDetails',
          'id': videoIds.take(50).join(','),
          'key': key,
        },
      );

      final response = await _http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['items'] as List?) ?? [];
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String?;
            final durationStr = item['contentDetails']?['duration'] as String?;
            if (id != null && durationStr != null) {
              result[id] = YouTubeVideoItem.parseIso8601Duration(durationStr);
            }
          }
        }
      }
    } catch (_) {
      // Non-fatal
    }

    return result;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 120+ Song Rich Categorized Fallback Catalog
  // ═════════════════════════════════════════════════════════════════════════

  static const List<YouTubeVideoItem> _curatedCatalog = [
    YouTubeVideoItem(
      id: 'g6fnFALEseI',
      title: 'Kesariya (Brahmastra)',
      channelTitle: 'Arijit Singh & Pritam',
      thumbnailUrl: 'https://img.youtube.com/vi/g6fnFALEseI/hqdefault.jpg',
      durationSeconds: 268,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'UEvOsQBu1jY',
      title: 'Apna Bana Le (Bhediya)',
      channelTitle: 'Arijit Singh & Sachin-Jigar',
      thumbnailUrl: 'https://img.youtube.com/vi/UEvOsQBu1jY/hqdefault.jpg',
      durationSeconds: 261,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'Umqb9KENgmk',
      title: 'Tum Hi Ho (Aashiqui 2)',
      channelTitle: 'Arijit Singh & Mithoon',
      thumbnailUrl: 'https://img.youtube.com/vi/Umqb9KENgmk/hqdefault.jpg',
      durationSeconds: 262,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'Etkd-07gnxM',
      title: 'O Maahi (Dunki)',
      channelTitle: 'Arijit Singh & Pritam',
      thumbnailUrl: 'https://img.youtube.com/vi/Etkd-07gnxM/hqdefault.jpg',
      durationSeconds: 260,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'iAIBF2ngbWY',
      title: 'Pehle Bhi Main (Animal)',
      channelTitle: 'Vishal Mishra & Harshavardhan',
      thumbnailUrl: 'https://img.youtube.com/vi/iAIBF2ngbWY/hqdefault.jpg',
      durationSeconds: 250,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'MJyKN-8UncM',
      title: 'Shayad (Love Aaj Kal)',
      channelTitle: 'Arijit Singh & Pritam',
      thumbnailUrl: 'https://img.youtube.com/vi/MJyKN-8UncM/hqdefault.jpg',
      durationSeconds: 247,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'gvyUuxdRdR4',
      title: 'Raataan Lambiyan (Shershaah)',
      channelTitle: 'Jubin Nautiyal & Asees Kaur',
      thumbnailUrl: 'https://img.youtube.com/vi/gvyUuxdRdR4/hqdefault.jpg',
      durationSeconds: 230,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'SAcpESN_Fk4',
      title: 'Dil Diyan Gallan (Tiger Zinda Hai)',
      channelTitle: 'Atif Aslam & Vishal-Shekhar',
      thumbnailUrl: 'https://img.youtube.com/vi/SAcpESN_Fk4/hqdefault.jpg',
      durationSeconds: 260,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'qFkNATtc3mc',
      title: 'Ghungroo (War)',
      channelTitle: 'Arijit Singh & Shilpa Rao',
      thumbnailUrl: 'https://img.youtube.com/vi/qFkNATtc3mc/hqdefault.jpg',
      durationSeconds: 302,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'g5WZLO8BAC8',
      title: 'Tere Vaaste (Zara Hatke)',
      channelTitle: 'Varun Jain & Sachin-Jigar',
      thumbnailUrl: 'https://img.youtube.com/vi/g5WZLO8BAC8/hqdefault.jpg',
      durationSeconds: 189,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'jHNNMj5bNQw',
      title: 'Kabira (YJHD)',
      channelTitle: 'Pritam, Tochi & Rekha',
      thumbnailUrl: 'https://img.youtube.com/vi/jHNNMj5bNQw/hqdefault.jpg',
      durationSeconds: 263,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'RemShT6JAHw',
      title: 'Tum Hi Aana (Marjaavaan)',
      channelTitle: 'Jubin Nautiyal & Payal Dev',
      thumbnailUrl: 'https://img.youtube.com/vi/RemShT6JAHw/hqdefault.jpg',
      durationSeconds: 224,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'DteVJ4Eq7bM',
      title: 'Pachtaoge',
      channelTitle: 'Arijit Singh & Tanishk Bagchi',
      thumbnailUrl: 'https://img.youtube.com/vi/DteVJ4Eq7bM/hqdefault.jpg',
      durationSeconds: 233,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'DUwlGduupRI',
      title: 'Filhaal2 Mohabbat',
      channelTitle: 'BPraak & Ammy Virk',
      thumbnailUrl: 'https://img.youtube.com/vi/DUwlGduupRI/hqdefault.jpg',
      durationSeconds: 268,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'TRa9IMvccjg',
      title: 'Dilbar (Satyameva Jayate)',
      channelTitle: 'Neha Kakkar & Tanishk Bagchi',
      thumbnailUrl: 'https://img.youtube.com/vi/TRa9IMvccjg/hqdefault.jpg',
      durationSeconds: 211,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: '57GvNFJTFlI',
      title: 'Lut Gaye',
      channelTitle: 'Jubin Nautiyal & Tanishk Bagchi',
      thumbnailUrl: 'https://img.youtube.com/vi/57GvNFJTFlI/hqdefault.jpg',
      durationSeconds: 236,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'zZasH6qkn8M',
      title: 'Teri Deewani',
      channelTitle: 'Kailash Kher',
      thumbnailUrl: 'https://img.youtube.com/vi/zZasH6qkn8M/hqdefault.jpg',
      durationSeconds: 326,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'iv7lcUkFVSc',
      title: 'O Re Piya (Aaja Nachle)',
      channelTitle: 'Rahat Fateh Ali Khan',
      thumbnailUrl: 'https://img.youtube.com/vi/iv7lcUkFVSc/hqdefault.jpg',
      durationSeconds: 289,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'cl0a3i2wFcc',
      title: 'G.O.A.T.',
      channelTitle: 'Diljit Dosanjh',
      thumbnailUrl: 'https://img.youtube.com/vi/cl0a3i2wFcc/hqdefault.jpg',
      durationSeconds: 223,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: 'mH_LFkWxpI0',
      title: 'Lover',
      channelTitle: 'Diljit Dosanjh',
      thumbnailUrl: 'https://img.youtube.com/vi/mH_LFkWxpI0/hqdefault.jpg',
      durationSeconds: 204,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: 'vX2cDW8LUWk',
      title: 'Excuses',
      channelTitle: 'AP Dhillon & Gurinder Gill',
      thumbnailUrl: 'https://img.youtube.com/vi/vX2cDW8LUWk/hqdefault.jpg',
      durationSeconds: 176,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: 'mZQH8CPQ-wo',
      title: 'With You',
      channelTitle: 'AP Dhillon',
      thumbnailUrl: 'https://img.youtube.com/vi/mZQH8CPQ-wo/hqdefault.jpg',
      durationSeconds: 154,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: 'cWMxCE2HTag',
      title: 'Softly',
      channelTitle: 'Karan Aujla & Ikky',
      thumbnailUrl: 'https://img.youtube.com/vi/cWMxCE2HTag/hqdefault.jpg',
      durationSeconds: 155,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: 'LK7-_dgAVQE',
      title: 'Tauba Tauba',
      channelTitle: 'Karan Aujla',
      thumbnailUrl: 'https://img.youtube.com/vi/LK7-_dgAVQE/hqdefault.jpg',
      durationSeconds: 208,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: 'VNs_cCtdbPc',
      title: 'Brown Munde',
      channelTitle: 'AP Dhillon & Gurinder Gill',
      thumbnailUrl: 'https://img.youtube.com/vi/VNs_cCtdbPc/hqdefault.jpg',
      durationSeconds: 268,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: '4tywp83zkmk',
      title: 'Cheques',
      channelTitle: 'Shubh',
      thumbnailUrl: 'https://img.youtube.com/vi/4tywp83zkmk/hqdefault.jpg',
      durationSeconds: 183,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: 'IvJKmLWeHlg',
      title: 'No Love',
      channelTitle: 'Shubh',
      thumbnailUrl: 'https://img.youtube.com/vi/IvJKmLWeHlg/hqdefault.jpg',
      durationSeconds: 170,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: 'I1nX5EuvwzE',
      title: 'Elevated',
      channelTitle: 'Shubh',
      thumbnailUrl: 'https://img.youtube.com/vi/I1nX5EuvwzE/hqdefault.jpg',
      durationSeconds: 201,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: 'AETFvQonfV8',
      title: 'Shri Hanuman Chalisa',
      channelTitle: 'Hariharan & Gulshan Kumar',
      thumbnailUrl: 'https://img.youtube.com/vi/AETFvQonfV8/hqdefault.jpg',
      durationSeconds: 600,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: 'pzzPowh241o',
      title: 'Achyutam Keshavam',
      channelTitle: 'Vikram Hazra',
      thumbnailUrl: 'https://img.youtube.com/vi/pzzPowh241o/hqdefault.jpg',
      durationSeconds: 270,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: 'hMBKmQEPNzI',
      title: 'Shiv Tandav Stotram',
      channelTitle: 'Shankar Mahadevan',
      thumbnailUrl: 'https://img.youtube.com/vi/hMBKmQEPNzI/hqdefault.jpg',
      durationSeconds: 300,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: '61EGpAy4Ids',
      title: 'Radhe Radhe Barsane Wali Radhe',
      channelTitle: 'Vipul Music',
      thumbnailUrl: 'https://img.youtube.com/vi/61EGpAy4Ids/hqdefault.jpg',
      durationSeconds: 300,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: 'yALvgZi-84o',
      title: 'Namo Namo (Kedarnath)',
      channelTitle: 'Amit Trivedi',
      thumbnailUrl: 'https://img.youtube.com/vi/yALvgZi-84o/hqdefault.jpg',
      durationSeconds: 287,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: 'XXRcHfrL7SQ',
      title: 'Mahamrityunjaya Mantra',
      channelTitle: 'Suresh Wadkar',
      thumbnailUrl: 'https://img.youtube.com/vi/XXRcHfrL7SQ/hqdefault.jpg',
      durationSeconds: 660,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: 'FJtrC8vkFoE',
      title: 'Har Har Shambhu',
      channelTitle: 'Abhilipsa Panda & Jeetu Sharma',
      thumbnailUrl: 'https://img.youtube.com/vi/FJtrC8vkFoE/hqdefault.jpg',
      durationSeconds: 260,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: 'Tl4bQBfOtbg',
      title: 'Ram Siya Ram (Adipurush)',
      channelTitle: 'Sachet-Parampara',
      thumbnailUrl: 'https://img.youtube.com/vi/Tl4bQBfOtbg/hqdefault.jpg',
      durationSeconds: 220,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: 'T94PHkuydcw',
      title: 'Kun Faya Kun (Rockstar)',
      channelTitle: 'A.R. Rahman, Javed Ali, Mohit Chauhan',
      thumbnailUrl: 'https://img.youtube.com/vi/T94PHkuydcw/hqdefault.jpg',
      durationSeconds: 352,
      category: 'sufi',
    ),
    YouTubeVideoItem(
      id: 'kw4tT7SCmaY',
      title: 'Afreen Afreen',
      channelTitle: 'Rahat Fateh Ali Khan & Momina Mustehsan',
      thumbnailUrl: 'https://img.youtube.com/vi/kw4tT7SCmaY/hqdefault.jpg',
      durationSeconds: 360,
      category: 'sufi',
    ),
    YouTubeVideoItem(
      id: 'dXdD1_AGBZg',
      title: 'Arziyan (Delhi-6)',
      channelTitle: 'Javed Ali & Kailash Kher',
      thumbnailUrl: 'https://img.youtube.com/vi/dXdD1_AGBZg/hqdefault.jpg',
      durationSeconds: 328,
      category: 'sufi',
    ),
    YouTubeVideoItem(
      id: '7SDrjwtfKMk',
      title: 'Chaap Tilak',
      channelTitle: 'Abida Parveen & Rahat Fateh Ali Khan',
      thumbnailUrl: 'https://img.youtube.com/vi/7SDrjwtfKMk/hqdefault.jpg',
      durationSeconds: 300,
      category: 'sufi',
    ),
    YouTubeVideoItem(
      id: 'TF_cOANSeJ8',
      title: 'Yeh Jo Halka Halka Suroor',
      channelTitle: 'Nusrat Fateh Ali Khan',
      thumbnailUrl: 'https://img.youtube.com/vi/TF_cOANSeJ8/hqdefault.jpg',
      durationSeconds: 360,
      category: 'sufi',
    ),
    YouTubeVideoItem(
      id: '5mxqQvVlsZg',
      title: 'Wo Kagaz Ki Kashti',
      channelTitle: 'Jagjit Singh',
      thumbnailUrl: 'https://img.youtube.com/vi/5mxqQvVlsZg/hqdefault.jpg',
      durationSeconds: 250,
      category: 'sufi',
    ),
    YouTubeVideoItem(
      id: 'uW6BXxnG5U4',
      title: 'Hothon Se Chhoo Lo Tum',
      channelTitle: 'Jagjit Singh',
      thumbnailUrl: 'https://img.youtube.com/vi/uW6BXxnG5U4/hqdefault.jpg',
      durationSeconds: 280,
      category: 'sufi',
    ),
    YouTubeVideoItem(
      id: 'ZhHGeH7hm2c',
      title: 'Tujhe Dekha To Yeh Jaana (DDLJ)',
      channelTitle: 'Kumar Sanu & Lata Mangeshkar',
      thumbnailUrl: 'https://img.youtube.com/vi/ZhHGeH7hm2c/hqdefault.jpg',
      durationSeconds: 310,
      category: 'nostalgia',
    ),
    YouTubeVideoItem(
      id: 'SBfPs-PMGTA',
      title: 'Pehla Nasha',
      channelTitle: 'Udit Narayan & Sadhana Sargam',
      thumbnailUrl: 'https://img.youtube.com/vi/SBfPs-PMGTA/hqdefault.jpg',
      durationSeconds: 330,
      category: 'nostalgia',
    ),
    YouTubeVideoItem(
      id: 'K-pX4qwtAxA',
      title: 'Chaiyya Chaiyya (Dil Se)',
      channelTitle: 'Sukhwinder Singh & Sapna Awasthi',
      thumbnailUrl: 'https://img.youtube.com/vi/K-pX4qwtAxA/hqdefault.jpg',
      durationSeconds: 380,
      category: 'nostalgia',
    ),
    YouTubeVideoItem(
      id: 'KeyfUuXPOcY',
      title: 'Dheere Dheere Se (Aashiqui)',
      channelTitle: 'Kumar Sanu & Anuradha Paudwal',
      thumbnailUrl: 'https://img.youtube.com/vi/KeyfUuXPOcY/hqdefault.jpg',
      durationSeconds: 320,
      category: 'nostalgia',
    ),
    YouTubeVideoItem(
      id: 'Yqj1_V90KJo',
      title: 'Chura Ke Dil Mera',
      channelTitle: 'Kumar Sanu & Alka Yagnik',
      thumbnailUrl: 'https://img.youtube.com/vi/Yqj1_V90KJo/hqdefault.jpg',
      durationSeconds: 300,
      category: 'nostalgia',
    ),
    YouTubeVideoItem(
      id: 'fJ9rUzIMcZQ',
      title: 'Bohemian Rhapsody',
      channelTitle: 'Queen',
      thumbnailUrl: 'https://img.youtube.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
      durationSeconds: 356,
      category: 'nostalgia',
    ),
    YouTubeVideoItem(
      id: '7wtfhZwyrcc',
      title: 'Believer',
      channelTitle: 'Imagine Dragons',
      thumbnailUrl: 'https://img.youtube.com/vi/7wtfhZwyrcc/hqdefault.jpg',
      durationSeconds: 204,
      category: 'workout',
    ),
    YouTubeVideoItem(
      id: 'kXYiU_JCYtU',
      title: 'Numb',
      channelTitle: 'Linkin Park',
      thumbnailUrl: 'https://img.youtube.com/vi/kXYiU_JCYtU/hqdefault.jpg',
      durationSeconds: 187,
      category: 'workout',
    ),
    YouTubeVideoItem(
      id: 'hT_nvWreIhg',
      title: 'Counting Stars',
      channelTitle: 'OneRepublic',
      thumbnailUrl: 'https://img.youtube.com/vi/hT_nvWreIhg/hqdefault.jpg',
      durationSeconds: 258,
      category: 'workout',
    ),
    YouTubeVideoItem(
      id: 'CaI0xNLpurM',
      title: 'Aashayein (Iqbal)',
      channelTitle: 'KK & Salim-Sulaiman',
      thumbnailUrl: 'https://img.youtube.com/vi/CaI0xNLpurM/hqdefault.jpg',
      durationSeconds: 310,
      category: 'workout',
    ),
    YouTubeVideoItem(
      id: 'btPJPFnesV4',
      title: 'Eye of the Tiger',
      channelTitle: 'Survivor',
      thumbnailUrl: 'https://img.youtube.com/vi/btPJPFnesV4/hqdefault.jpg',
      durationSeconds: 250,
      category: 'workout',
    ),
    YouTubeVideoItem(
      id: 'j5-yKhDd64s',
      title: 'Not Afraid',
      channelTitle: 'Eminem',
      thumbnailUrl: 'https://img.youtube.com/vi/j5-yKhDd64s/hqdefault.jpg',
      durationSeconds: 263,
      category: 'workout',
    ),
    YouTubeVideoItem(
      id: 'nCg3ufihKyU',
      title: 'The Business',
      channelTitle: 'Tiesto',
      thumbnailUrl: 'https://img.youtube.com/vi/nCg3ufihKyU/hqdefault.jpg',
      durationSeconds: 165,
      category: 'workout',
    ),
    YouTubeVideoItem(
      id: 'TUVcZfQe-Kw',
      title: 'Levitating',
      channelTitle: 'Dua Lipa',
      thumbnailUrl: 'https://img.youtube.com/vi/TUVcZfQe-Kw/hqdefault.jpg',
      durationSeconds: 203,
      category: 'workout',
    ),
    YouTubeVideoItem(
      id: 'gJLVTKhTnog',
      title: 'Husn',
      channelTitle: 'Anuv Jain',
      thumbnailUrl: 'https://img.youtube.com/vi/gJLVTKhTnog/hqdefault.jpg',
      durationSeconds: 250,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: 'PJWemSzExXs',
      title: 'Baarishein',
      channelTitle: 'Anuv Jain',
      thumbnailUrl: 'https://img.youtube.com/vi/PJWemSzExXs/hqdefault.jpg',
      durationSeconds: 230,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: 'aBM77fRdQAM',
      title: 'cold/mess',
      channelTitle: 'Prateek Kuhad',
      thumbnailUrl: 'https://img.youtube.com/vi/aBM77fRdQAM/hqdefault.jpg',
      durationSeconds: 270,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: 'BmUe3-sfr7E',
      title: 'Kasoor',
      channelTitle: 'Prateek Kuhad',
      thumbnailUrl: 'https://img.youtube.com/vi/BmUe3-sfr7E/hqdefault.jpg',
      durationSeconds: 220,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: 'sFMRqxCexDk',
      title: 'Choo Lo',
      channelTitle: 'The Local Train',
      thumbnailUrl: 'https://img.youtube.com/vi/sFMRqxCexDk/hqdefault.jpg',
      durationSeconds: 270,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: 'U77d9912lrw',
      title: 'Aaftaab',
      channelTitle: 'The Local Train',
      thumbnailUrl: 'https://img.youtube.com/vi/U77d9912lrw/hqdefault.jpg',
      durationSeconds: 300,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: 'kJQP7kiw5Fk',
      title: 'Despacito',
      channelTitle: 'Luis Fonsi ft. Daddy Yankee',
      thumbnailUrl: 'https://img.youtube.com/vi/kJQP7kiw5Fk/hqdefault.jpg',
      durationSeconds: 282,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: 'JGwWNGJdvx8',
      title: 'Shape of You',
      channelTitle: 'Ed Sheeran',
      thumbnailUrl: 'https://img.youtube.com/vi/JGwWNGJdvx8/hqdefault.jpg',
      durationSeconds: 233,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: '4NRXx6U8ABQ',
      title: 'Blinding Lights',
      channelTitle: 'The Weeknd',
      thumbnailUrl: 'https://img.youtube.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
      durationSeconds: 200,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: '34Na4j8AVgA',
      title: 'Starboy',
      channelTitle: 'The Weeknd ft. Daft Punk',
      thumbnailUrl: 'https://img.youtube.com/vi/34Na4j8AVgA/hqdefault.jpg',
      durationSeconds: 230,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: 'YQHsXMglC9A',
      title: 'Hello',
      channelTitle: 'Adele',
      thumbnailUrl: 'https://img.youtube.com/vi/YQHsXMglC9A/hqdefault.jpg',
      durationSeconds: 355,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: 'OPf0YbXqDm0',
      title: 'Uptown Funk',
      channelTitle: 'Mark Ronson ft. Bruno Mars',
      thumbnailUrl: 'https://img.youtube.com/vi/OPf0YbXqDm0/hqdefault.jpg',
      durationSeconds: 270,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: '2Vv-BfVoq4g',
      title: 'Perfect',
      channelTitle: 'Ed Sheeran',
      thumbnailUrl: 'https://img.youtube.com/vi/2Vv-BfVoq4g/hqdefault.jpg',
      durationSeconds: 263,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: 'kTJczUoc26U',
      title: 'STAY',
      channelTitle: 'The Kid LAROI & Justin Bieber',
      thumbnailUrl: 'https://img.youtube.com/vi/kTJczUoc26U/hqdefault.jpg',
      durationSeconds: 141,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: 'tQ0yjYUFKAE',
      title: 'Peaches',
      channelTitle: 'Justin Bieber ft. Daniel Caesar',
      thumbnailUrl: 'https://img.youtube.com/vi/tQ0yjYUFKAE/hqdefault.jpg',
      durationSeconds: 198,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: 'Uq9gPaIzbe8',
      title: 'Unholy',
      channelTitle: 'Sam Smith & Kim Petras',
      thumbnailUrl: 'https://img.youtube.com/vi/Uq9gPaIzbe8/hqdefault.jpg',
      durationSeconds: 156,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: 'H5v3kku4y6Q',
      title: 'As It Was',
      channelTitle: 'Harry Styles',
      thumbnailUrl: 'https://img.youtube.com/vi/H5v3kku4y6Q/hqdefault.jpg',
      durationSeconds: 167,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: 'KRaWnd3LJfs',
      title: 'Payphone',
      channelTitle: 'Maroon 5 ft. Wiz Khalifa',
      thumbnailUrl: 'https://img.youtube.com/vi/KRaWnd3LJfs/hqdefault.jpg',
      durationSeconds: 231,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: '31crA53Dgu0',
      title: 'Cheap Thrills',
      channelTitle: 'Sia',
      thumbnailUrl: 'https://img.youtube.com/vi/31crA53Dgu0/hqdefault.jpg',
      durationSeconds: 224,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: 'luhVm60Wiro',
      title: 'Zingaat (Sairat)',
      channelTitle: 'Ajay-Atul',
      thumbnailUrl: 'https://img.youtube.com/vi/luhVm60Wiro/hqdefault.jpg',
      durationSeconds: 270,
      category: 'marathi',
    ),
    YouTubeVideoItem(
      id: 'KUN5Uf9mObQ',
      title: 'Arabic Kuthu (Beast)',
      channelTitle: 'Anirudh Ravichander',
      thumbnailUrl: 'https://img.youtube.com/vi/KUN5Uf9mObQ/hqdefault.jpg',
      durationSeconds: 240,
      category: 'tamil',
    ),
    YouTubeVideoItem(
      id: '4_eEgJhsBMo',
      title: 'Naatu Naatu (RRR)',
      channelTitle: 'M.M. Keeravaani',
      thumbnailUrl: 'https://img.youtube.com/vi/4_eEgJhsBMo/hqdefault.jpg',
      durationSeconds: 250,
      category: 'telugu',
    ),
    YouTubeVideoItem(
      id: 't7wSjy9Lv-o',
      title: 'Khalasi (Coke Studio Bharat)',
      channelTitle: 'Aditya Gadhvi & Achint',
      thumbnailUrl: 'https://img.youtube.com/vi/t7wSjy9Lv-o/hqdefault.jpg',
      durationSeconds: 260,
      category: 'gujarati',
    ),
    YouTubeVideoItem(
      id: 'f6-FZFqmZgI',
      title: 'Bhalobashar Morshum (X=Prem)',
      channelTitle: 'Arijit Singh & Shreya Ghoshal',
      thumbnailUrl: 'https://img.youtube.com/vi/f6-FZFqmZgI/hqdefault.jpg',
      durationSeconds: 260,
      category: 'bengali',
    ),
    YouTubeVideoItem(
      id: 'tOM-nWPcR4U',
      title: 'Illuminati (Aavesham)',
      channelTitle: 'Sushin Shyam & Dabzee',
      thumbnailUrl: 'https://img.youtube.com/vi/tOM-nWPcR4U/hqdefault.jpg',
      durationSeconds: 230,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: 'K4DyBUG242c',
      title: 'On & On (NCS)',
      channelTitle: 'Cartoon & Jeja',
      thumbnailUrl: 'https://img.youtube.com/vi/K4DyBUG242c/hqdefault.jpg',
      durationSeconds: 230,
      category: 'ambient',
    ),
    YouTubeVideoItem(
      id: '1P5BSm_oFJg',
      title: 'Snowman (Lofi Girl)',
      channelTitle: 'Lofi Girl',
      thumbnailUrl: 'https://img.youtube.com/vi/1P5BSm_oFJg/hqdefault.jpg',
      durationSeconds: 210,
      category: 'ambient',
    ),
    YouTubeVideoItem(
      id: 'XfJMVvZh838',
      title: 'Love in Lo-Fi',
      channelTitle: 'Chayla Hope',
      thumbnailUrl: 'https://img.youtube.com/vi/XfJMVvZh838/hqdefault.jpg',
      durationSeconds: 200,
      category: 'ambient',
    ),
    YouTubeVideoItem(
      id: 'MDzJ6ynL-5g',
      title: 'Skylines (Chill Morning Lofi)',
      channelTitle: 'Kainbeats',
      thumbnailUrl: 'https://img.youtube.com/vi/MDzJ6ynL-5g/hqdefault.jpg',
      durationSeconds: 220,
      category: 'ambient',
    ),
    YouTubeVideoItem(
      id: 'LlwHphMhUOo',
      title: 'Aarzu',
      channelTitle: 'Noor, Khan & Madhurxo',
      thumbnailUrl: 'https://img.youtube.com/vi/LlwHphMhUOo/hqdefault.jpg',
      durationSeconds: 220,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: 'l6E16JAk_Fs',
      title: 'Khat',
      channelTitle: 'Navjot Ahuja',
      thumbnailUrl: 'https://img.youtube.com/vi/l6E16JAk_Fs/hqdefault.jpg',
      durationSeconds: 200,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: 'vnDaD43wt2w',
      title: 'Sirf Tujhse',
      channelTitle: 'Indie Artist',
      thumbnailUrl: 'https://img.youtube.com/vi/vnDaD43wt2w/hqdefault.jpg',
      durationSeconds: 210,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: 'eTucXMU8ctw',
      title: 'Mann',
      channelTitle: 'The Yellow Diary',
      thumbnailUrl: 'https://img.youtube.com/vi/eTucXMU8ctw/hqdefault.jpg',
      durationSeconds: 260,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: '_kUrW9SEaJc',
      title: 'Sage',
      channelTitle: 'Ritviz',
      thumbnailUrl: 'https://img.youtube.com/vi/_kUrW9SEaJc/hqdefault.jpg',
      durationSeconds: 230,
      category: 'indie',
    ),
  ];

  List<YouTubeVideoItem> _fallbackSearch(
    String query, {
    String order = 'relevance',
    required int maxResults,
    Set<String> excludeIds = const {},
  }) {
    final cleanQuery = query.toLowerCase().trim();

    // Map common query words directly to categories — comprehensive mapping for all filters
    String? matchedCategory;
    List<String>? multiCategories;
    if (cleanQuery.contains('devotional') ||
        cleanQuery.contains('bhajan') ||
        cleanQuery.contains('hanuman') ||
        cleanQuery.contains('aarti') ||
        cleanQuery.contains('bhakti')) {
      matchedCategory = 'devotional';
    } else if (cleanQuery.contains('sufi') ||
        cleanQuery.contains('ghazal') ||
        cleanQuery.contains('nusrat') ||
        cleanQuery.contains('qawwali')) {
      matchedCategory = 'sufi';
    } else if (cleanQuery.contains('90s') ||
        cleanQuery.contains('nostalgia') ||
        cleanQuery.contains('evergreen') ||
        cleanQuery.contains('classic') ||
        cleanQuery.contains('retro')) {
      matchedCategory = 'nostalgia';
    } else if (cleanQuery.contains('workout') ||
        cleanQuery.contains('gym') ||
        cleanQuery.contains('cardio') ||
        cleanQuery.contains('hype') ||
        cleanQuery.contains('fitness') ||
        cleanQuery.contains('running')) {
      matchedCategory = 'workout';
    } else if (cleanQuery.contains('road trip') ||
        cleanQuery.contains('travel') ||
        cleanQuery.contains('drive') ||
        cleanQuery.contains('highway') ||
        cleanQuery.contains('journey')) {
      // Road Trip / Drive → energetic, feel-good driving music across
      // workout, global and punjabi (upbeat/highway vibes).
      multiCategories = ['workout', 'global', 'punjabi'];
    } else if (cleanQuery.contains('punjabi') ||
        cleanQuery.contains('diljit') ||
        cleanQuery.contains('aujla') ||
        cleanQuery.contains('dhillon') ||
        cleanQuery.contains('shubh')) {
      matchedCategory = 'punjabi';
    } else if (cleanQuery.contains('english') ||
        cleanQuery.contains('international') ||
        cleanQuery.contains('billboard') ||
        cleanQuery.contains('global') ||
        cleanQuery.contains('ed sheeran') ||
        cleanQuery.contains('weeknd') ||
        cleanQuery.contains('adele')) {
      matchedCategory = 'global';
    } else if (cleanQuery.contains('hip hop') ||
        cleanQuery.contains('hip-hop') ||
        cleanQuery.contains('hiphop') ||
        cleanQuery.contains('rap') ||
        cleanQuery.contains('eminem') ||
        cleanQuery.contains('drake')) {
      matchedCategory = 'workout';
      multiCategories = ['workout', 'global'];
    } else if (cleanQuery.contains('edm') ||
        cleanQuery.contains('electro') ||
        cleanQuery.contains('house music') ||
        cleanQuery.contains('dance')) {
      multiCategories = ['global', 'workout', 'ambient'];
    } else if (cleanQuery.contains('romantic') ||
        cleanQuery.contains('love song') ||
        cleanQuery.contains('romance')) {
      multiCategories = ['bollywood', 'indie', 'global'];
    } else if (cleanQuery.contains('sad') ||
        cleanQuery.contains('heartbroken') ||
        cleanQuery.contains('emotional') ||
        cleanQuery.contains('breakup') ||
        cleanQuery.contains('heart break')) {
      multiCategories = ['nostalgia', 'indie', 'bollywood'];
    } else if (cleanQuery.contains('party') ||
        cleanQuery.contains('celebration') ||
        cleanQuery.contains('festival')) {
      multiCategories = ['punjabi', 'workout', 'bollywood'];
    } else if (cleanQuery.contains('bollywood') ||
        (cleanQuery.contains('hindi') && !cleanQuery.contains('indie')) ||
        cleanQuery.contains('arijit') ||
        cleanQuery.contains('bolly')) {
      matchedCategory = 'bollywood';
    } else if (cleanQuery.contains('indie') ||
        cleanQuery.contains('acoustic') ||
        cleanQuery.contains('anuv') ||
        cleanQuery.contains('kuhad') ||
        cleanQuery.contains('prateek')) {
      matchedCategory = 'indie';
    } else if (cleanQuery.contains('marathi')) {
      matchedCategory = 'marathi';
    } else if (cleanQuery.contains('gujarati') ||
        cleanQuery.contains('garba')) {
      matchedCategory = 'gujarati';
    } else if (cleanQuery.contains('tamil')) {
      matchedCategory = 'tamil';
    } else if (cleanQuery.contains('telugu')) {
      matchedCategory = 'telugu';
    } else if (cleanQuery.contains('bengali')) {
      matchedCategory = 'bengali';
    } else if (cleanQuery.contains('wedding') ||
        cleanQuery.contains('sangeet')) {
      // Wedding & Sangeet → Bollywood celebration tracks.
      matchedCategory = 'bollywood';
    } else if (cleanQuery.contains('monsoon') || cleanQuery.contains('rain')) {
      // Monsoon Vibes → Hindi romantic Bollywood.
      multiCategories = ['bollywood', 'indie'];
    } else if (cleanQuery.contains('motivational') ||
        cleanQuery.contains('inspirational')) {
      // Motivational → upbeat global / workout.
      multiCategories = ['global', 'workout'];
    } else if (cleanQuery.contains('trending') ||
        cleanQuery.contains('viral') ||
        cleanQuery.contains('top hits')) {
      // Trending → popular content across the most-streamed categories.
      multiCategories = ['global', 'punjabi', 'bollywood'];
    } else if (cleanQuery.contains('chill') ||
        cleanQuery.contains('sleep') ||
        cleanQuery.contains('lofi') ||
        cleanQuery.contains('ambient') ||
        cleanQuery.contains('study') ||
        cleanQuery.contains('focus')) {
      matchedCategory = 'ambient';
    }

    // 1. Direct category match (single or multi-category).
    // STRICT ISOLATION: a matched category returns ONLY that category's
    // candidates. It NEVER appends unrelated "others" just to fill the list —
    // that was the bug where Chill & Lofi showed Kesariya and sections leaked
    // each other's content. If a category is short, the section shows fewer
    // (but correct) items rather than wrong ones.
    if (multiCategories != null && multiCategories.isNotEmpty) {
      final multiMatches = <YouTubeVideoItem>[];
      for (final cat in multiCategories) {
        multiMatches.addAll(
          _curatedCatalog.where((item) {
            return !excludeIds.contains(item.id) &&
                item.category == cat &&
                !multiMatches.any((m) => m.id == item.id);
          }),
        );
      }
      if (multiMatches.isNotEmpty) {
        if (order == 'viewCount') {
          multiMatches
              .sort((a, b) => (b.viewCount ?? 0).compareTo(a.viewCount ?? 0));
        } else if (order == 'date') {
          multiMatches.sort((a, b) => (b.publishedAt ?? DateTime(2020))
              .compareTo(a.publishedAt ?? DateTime(2020)));
        }
        // NO cross-category fallback.
        return multiMatches.take(maxResults).toList();
      }
    }
    if (matchedCategory != null) {
      final catMatches = _curatedCatalog.where((item) {
        return !excludeIds.contains(item.id) &&
            item.category == matchedCategory;
      }).toList();

      if (catMatches.isNotEmpty) {
        // Apply order sorting simulation for fallback determinism
        if (order == 'viewCount') {
          catMatches
              .sort((a, b) => (b.viewCount ?? 0).compareTo(a.viewCount ?? 0));
        } else if (order == 'date') {
          catMatches.sort((a, b) => (b.publishedAt ?? DateTime(2020))
              .compareTo(a.publishedAt ?? DateTime(2020)));
        } else {
          catMatches.shuffle();
        }
        // STRICT ISOLATION: no cross-category fallback.
        return catMatches.take(maxResults).toList();
      }
    }

    // 2. Token keyword match
    final qTokens = cleanQuery.split(' ').where((t) => t.length > 2).toList();
    final tokenMatches = _curatedCatalog.where((item) {
      if (excludeIds.contains(item.id)) return false;
      if (qTokens.isEmpty) return true;
      final title = item.title.toLowerCase();
      final artist = item.channelTitle.toLowerCase();
      final cat = item.category.toLowerCase();
      return qTokens.any(
        (t) => title.contains(t) || artist.contains(t) || cat.contains(t),
      );
    }).toList();

    if (tokenMatches.length >= 4) {
      return tokenMatches.take(maxResults).toList();
    }

    // 3. Fallback to broad catalog (only used when NO category matched, e.g.
    // free-form search — never used to pollute a matched category section).
    final combined = List<YouTubeVideoItem>.from(tokenMatches);
    for (final item in _curatedCatalog) {
      if (!excludeIds.contains(item.id) &&
          !combined.any((m) => m.id == item.id)) {
        combined.add(item);
      }
      if (combined.length >= maxResults) break;
    }

    return combined.take(maxResults).toList();
  }

  YouTubeVideoItem? _fallbackGetVideo(String videoId) {
    for (final item in _curatedCatalog) {
      if (item.id == videoId) return item;
    }
    return YouTubeVideoItem(
      id: videoId,
      title: 'YouTube Track',
      channelTitle: 'YouTube Artist',
      thumbnailUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      durationSeconds: 210,
    );
  }

  void dispose() {
    _http.close();
  }
}
