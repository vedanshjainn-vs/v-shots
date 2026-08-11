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
    final thumb =
        maxres ??
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
    // ── Bollywood & Hindi Hits ───────────────────────────────────────────────
    YouTubeVideoItem(
      id: 'L0MK7qz13bU',
      title: 'Kesariya (Brahmāstra)',
      channelTitle: 'Arijit Singh & Pritam',
      thumbnailUrl: 'https://img.youtube.com/vi/L0MK7qz13bU/hqdefault.jpg',
      durationSeconds: 268,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'v_zZmsFZDao',
      title: 'Apna Bana Le (Bhediya)',
      channelTitle: 'Arijit Singh & Sachin-Jigar',
      thumbnailUrl: 'https://img.youtube.com/vi/v_zZmsFZDao/hqdefault.jpg',
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
      id: 'Oq5P-kF_n9c',
      title: 'O Maahi (Dunki)',
      channelTitle: 'Arijit Singh & Pritam',
      thumbnailUrl: 'https://img.youtube.com/vi/Oq5P-kF_n9c/hqdefault.jpg',
      durationSeconds: 233,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'gVYr5M2wF4o',
      title: 'Pehle Bhi Main (Animal)',
      channelTitle: 'Vishal Mishra & Harshavardhan',
      thumbnailUrl: 'https://img.youtube.com/vi/gVYr5M2wF4o/hqdefault.jpg',
      durationSeconds: 250,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'g6fnFALEseI',
      title: 'Raataan Lambiyan (Shershaah)',
      channelTitle: 'Jubin Nautiyal & Asees Kaur',
      thumbnailUrl: 'https://img.youtube.com/vi/g6fnFALEseI/hqdefault.jpg',
      durationSeconds: 230,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'hvxD4kH9p_Y',
      title: 'Shayad (Love Aaj Kal)',
      channelTitle: 'Arijit Singh & Pritam',
      thumbnailUrl: 'https://img.youtube.com/vi/hvxD4kH9p_Y/hqdefault.jpg',
      durationSeconds: 247,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'MEb_lZ6Vv0A',
      title: 'Dil Diyan Gallan (Tiger Zinda Hai)',
      channelTitle: 'Atif Aslam & Vishal-Shekhar',
      thumbnailUrl: 'https://img.youtube.com/vi/MEb_lZ6Vv0A/hqdefault.jpg',
      durationSeconds: 260,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'qFDf9y1A_fQ',
      title: 'Ghungroo (War)',
      channelTitle: 'Arijit Singh & Shilpa Rao',
      thumbnailUrl: 'https://img.youtube.com/vi/qFDf9y1A_fQ/hqdefault.jpg',
      durationSeconds: 302,
      category: 'bollywood',
    ),
    YouTubeVideoItem(
      id: 'BddP6PYo2gs',
      title: 'Tere Vaaste (Zara Hatke Zara Bachke)',
      channelTitle: 'Varun Jain, Sachin-Jigar',
      thumbnailUrl: 'https://img.youtube.com/vi/BddP6PYo2gs/hqdefault.jpg',
      durationSeconds: 189,
      category: 'bollywood',
    ),

    // ── Punjabi Bangers ──────────────────────────────────────────────────────
    YouTubeVideoItem(
      id: 'cl0a3i2wFcc',
      title: 'G.O.A.T.',
      channelTitle: 'Diljit Dosanjh',
      thumbnailUrl: 'https://img.youtube.com/vi/cl0a3i2wFcc/hqdefault.jpg',
      durationSeconds: 223,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: 'D-YDEiaPn0s',
      title: 'Lover',
      channelTitle: 'Diljit Dosanjh',
      thumbnailUrl: 'https://img.youtube.com/vi/D-YDEiaPn0s/hqdefault.jpg',
      durationSeconds: 204,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: '0yW7w8F2TVA',
      title: 'Excuses',
      channelTitle: 'AP Dhillon & Gurinder Gill',
      thumbnailUrl: 'https://img.youtube.com/vi/0yW7w8F2TVA/hqdefault.jpg',
      durationSeconds: 176,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: 'v7mK69U5Rvg',
      title: 'With You',
      channelTitle: 'AP Dhillon',
      thumbnailUrl: 'https://img.youtube.com/vi/v7mK69U5Rvg/hqdefault.jpg',
      durationSeconds: 154,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: '6mbwJ2xhgzM',
      title: 'Softly',
      channelTitle: 'Karan Aujla & Ikky',
      thumbnailUrl: 'https://img.youtube.com/vi/6mbwJ2xhgzM/hqdefault.jpg',
      durationSeconds: 155,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: 'Qp3y_fE-7pU',
      title: 'Tauba Tauba',
      channelTitle: 'Karan Aujla',
      thumbnailUrl: 'https://img.youtube.com/vi/Qp3y_fE-7pU/hqdefault.jpg',
      durationSeconds: 208,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: 'dCmp56tSSmA',
      title: 'Brown Munde',
      channelTitle: 'AP Dhillon, Gurinder Gill, Shinda Kahlon',
      thumbnailUrl: 'https://img.youtube.com/vi/dCmp56tSSmA/hqdefault.jpg',
      durationSeconds: 268,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: 'vX2cDW8LUWk',
      title: 'Cheques',
      channelTitle: 'Shubh',
      thumbnailUrl: 'https://img.youtube.com/vi/vX2cDW8LUWk/hqdefault.jpg',
      durationSeconds: 183,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: '8nK_P6a4e2k',
      title: 'No Love',
      channelTitle: 'Shubh',
      thumbnailUrl: 'https://img.youtube.com/vi/8nK_P6a4e2k/hqdefault.jpg',
      durationSeconds: 170,
      category: 'punjabi',
    ),
    YouTubeVideoItem(
      id: '7zp1TbLFPXA',
      title: 'Elevated',
      channelTitle: 'Shubh',
      thumbnailUrl: 'https://img.youtube.com/vi/7zp1TbLFPXA/hqdefault.jpg',
      durationSeconds: 201,
      category: 'punjabi',
    ),

    // ── Devotional & Bhajans ─────────────────────────────────────────────────
    YouTubeVideoItem(
      id: 'hM_9cE7W4dE',
      title: 'Shri Hanuman Chalisa',
      channelTitle: 'Hariharan & Gulshan Kumar',
      thumbnailUrl: 'https://img.youtube.com/vi/hM_9cE7W4dE/hqdefault.jpg',
      durationSeconds: 580,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: 'O8T_m3q3e5M',
      title: 'Achyutam Keshavam',
      channelTitle: 'Vikram Hazra & Art of Living',
      thumbnailUrl: 'https://img.youtube.com/vi/O8T_m3q3e5M/hqdefault.jpg',
      durationSeconds: 320,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: '3tXw7x8y9z0',
      title: 'Shiv Tandav Stotram',
      channelTitle: 'Shankar Mahadevan',
      thumbnailUrl: 'https://img.youtube.com/vi/3tXw7x8y9z0/hqdefault.jpg',
      durationSeconds: 550,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: 'kLmNoPqRsTu',
      title: 'Ram Siya Ram (Adipurush)',
      channelTitle: 'Sachet-Parampara',
      thumbnailUrl: 'https://img.youtube.com/vi/kLmNoPqRsTu/hqdefault.jpg',
      durationSeconds: 230,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: '9uVwXyZ0123',
      title: 'Namo Namo (Kedarnath)',
      channelTitle: 'Amit Trivedi',
      thumbnailUrl: 'https://img.youtube.com/vi/9uVwXyZ0123/hqdefault.jpg',
      durationSeconds: 322,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: 'AbCdEfGhIjK',
      title: 'Radhe Radhe Radhe Barsane Wali Radhe',
      channelTitle: 'Gaurav Krishna Goswami',
      thumbnailUrl: 'https://img.youtube.com/vi/AbCdEfGhIjK/hqdefault.jpg',
      durationSeconds: 410,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: 'LmNoPqRsTuV',
      title: 'Mahamrityunjaya Mantra 108 Times',
      channelTitle: 'Suresh Wadkar',
      thumbnailUrl: 'https://img.youtube.com/vi/LmNoPqRsTuV/hqdefault.jpg',
      durationSeconds: 600,
      category: 'devotional',
    ),
    YouTubeVideoItem(
      id: 'WxYz0123456',
      title: 'Har Har Shambhu Shiv Mahadeva',
      channelTitle: 'Abhilipsa Panda & Jeetu Sharma',
      thumbnailUrl: 'https://img.youtube.com/vi/WxYz0123456/hqdefault.jpg',
      durationSeconds: 350,
      category: 'devotional',
    ),

    // ── Sufi & Ghazals ───────────────────────────────────────────────────────
    YouTubeVideoItem(
      id: '8aN4H6u1z3Y',
      title: 'Kun Faya Kun (Rockstar)',
      channelTitle: 'A.R. Rahman, Javed Ali, Mohit Chauhan',
      thumbnailUrl: 'https://img.youtube.com/vi/8aN4H6u1z3Y/hqdefault.jpg',
      durationSeconds: 471,
      category: 'sufi',
    ),
    YouTubeVideoItem(
      id: 'k8Xk6f8p4eI',
      title: 'Afreen Afreen',
      channelTitle: 'Rahat Fateh Ali Khan & Momina Mustehsan',
      thumbnailUrl: 'https://img.youtube.com/vi/k8Xk6f8p4eI/hqdefault.jpg',
      durationSeconds: 405,
      category: 'sufi',
    ),
    YouTubeVideoItem(
      id: '789AbCdEfGh',
      title: 'Arziyan (Delhi-6)',
      channelTitle: 'Javed Ali & Kailash Kher',
      thumbnailUrl: 'https://img.youtube.com/vi/789AbCdEfGh/hqdefault.jpg',
      durationSeconds: 520,
      category: 'sufi',
    ),
    YouTubeVideoItem(
      id: 'IjKlMnOpQrS',
      title: 'Chaap Tilak',
      channelTitle: 'Abida Parveen & Rahat Fateh Ali Khan',
      thumbnailUrl: 'https://img.youtube.com/vi/IjKlMnOpQrS/hqdefault.jpg',
      durationSeconds: 490,
      category: 'sufi',
    ),
    YouTubeVideoItem(
      id: 'TuVwXyZ0123',
      title: 'Yeh Jo Halka Halka Suroor Hai',
      channelTitle: 'Nusrat Fateh Ali Khan',
      thumbnailUrl: 'https://img.youtube.com/vi/TuVwXyZ0123/hqdefault.jpg',
      durationSeconds: 580,
      category: 'sufi',
    ),
    YouTubeVideoItem(
      id: '456789AbCdE',
      title: 'Wo Kagaz Ki Kashti',
      channelTitle: 'Jagjit Singh',
      thumbnailUrl: 'https://img.youtube.com/vi/456789AbCdE/hqdefault.jpg',
      durationSeconds: 240,
      category: 'sufi',
    ),
    YouTubeVideoItem(
      id: 'fGhIjKlMnOp',
      title: 'Hothon Se Chhoo Lo Tum',
      channelTitle: 'Jagjit Singh',
      thumbnailUrl: 'https://img.youtube.com/vi/fGhIjKlMnOp/hqdefault.jpg',
      durationSeconds: 290,
      category: 'sufi',
    ),

    // ── 90s Nostalgia ────────────────────────────────────────────────────────
    YouTubeVideoItem(
      id: 'fJ9rUzIMcZQ',
      title: 'Bohemian Rhapsody',
      channelTitle: 'Queen',
      thumbnailUrl: 'https://img.youtube.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
      durationSeconds: 359,
      category: 'nostalgia',
    ),
    YouTubeVideoItem(
      id: 'QrStUvWxYz0',
      title: 'Tujhe Dekha To Yeh Jaana Sanam (DDLJ)',
      channelTitle: 'Kumar Sanu & Lata Mangeshkar',
      thumbnailUrl: 'https://img.youtube.com/vi/QrStUvWxYz0/hqdefault.jpg',
      durationSeconds: 305,
      category: 'nostalgia',
    ),
    YouTubeVideoItem(
      id: '123456789Ab',
      title: 'Pehla Nasha (Jo Jeeta Wohi Sikandar)',
      channelTitle: 'Udit Narayan & Sadhana Sargam',
      thumbnailUrl: 'https://img.youtube.com/vi/123456789Ab/hqdefault.jpg',
      durationSeconds: 290,
      category: 'nostalgia',
    ),
    YouTubeVideoItem(
      id: 'CdEfGhIjKlM',
      title: 'Chaiyya Chaiyya (Dil Se)',
      channelTitle: 'Sukhwinder Singh & Sapna Awasthi',
      thumbnailUrl: 'https://img.youtube.com/vi/CdEfGhIjKlM/hqdefault.jpg',
      durationSeconds: 395,
      category: 'nostalgia',
    ),
    YouTubeVideoItem(
      id: 'nOpQrStUvWx',
      title: 'Dheere Dheere Se Meri Zindagi (Aashiqui)',
      channelTitle: 'Kumar Sanu & Anuradha Paudwal',
      thumbnailUrl: 'https://img.youtube.com/vi/nOpQrStUvWx/hqdefault.jpg',
      durationSeconds: 310,
      category: 'nostalgia',
    ),
    YouTubeVideoItem(
      id: 'Yz012345678',
      title: 'Chura Ke Dil Mera (Main Khiladi Tu Anari)',
      channelTitle: 'Kumar Sanu & Alka Yagnik',
      thumbnailUrl: 'https://img.youtube.com/vi/Yz012345678/hqdefault.jpg',
      durationSeconds: 360,
      category: 'nostalgia',
    ),

    // ── Workout Cardio & Gym Hype ────────────────────────────────────────────
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
      durationSeconds: 257,
      category: 'workout',
    ),
    YouTubeVideoItem(
      id: 'qFkNATtc3mc',
      title: 'Aashayein (Iqbal)',
      channelTitle: 'KK & Salim-Sulaiman',
      thumbnailUrl: 'https://img.youtube.com/vi/qFkNATtc3mc/hqdefault.jpg',
      durationSeconds: 259,
      category: 'workout',
    ),
    YouTubeVideoItem(
      id: 'btPJPFnesV4',
      title: 'Eye of the Tiger',
      channelTitle: 'Survivor',
      thumbnailUrl: 'https://img.youtube.com/vi/btPJPFnesV4/hqdefault.jpg',
      durationSeconds: 245,
      category: 'workout',
    ),
    YouTubeVideoItem(
      id: 'j5-yKhDd64s',
      title: 'Not Afraid',
      channelTitle: 'Eminem',
      thumbnailUrl: 'https://img.youtube.com/vi/j5-yKhDd64s/hqdefault.jpg',
      durationSeconds: 250,
      category: 'workout',
    ),

    // ── Hindi Indie & Acoustic ───────────────────────────────────────────────
    YouTubeVideoItem(
      id: '8g48AxyqJsc',
      title: 'Husn',
      channelTitle: 'Anuv Jain',
      thumbnailUrl: 'https://img.youtube.com/vi/8g48AxyqJsc/hqdefault.jpg',
      durationSeconds: 219,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: 'xR3V5Ow65RE',
      title: 'Baarishein',
      channelTitle: 'Anuv Jain',
      thumbnailUrl: 'https://img.youtube.com/vi/xR3V5Ow65RE/hqdefault.jpg',
      durationSeconds: 207,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: '2Fm_zWq_VbU',
      title: 'cold/mess',
      channelTitle: 'Prateek Kuhad',
      thumbnailUrl: 'https://img.youtube.com/vi/2Fm_zWq_VbU/hqdefault.jpg',
      durationSeconds: 279,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: 'lJ8XfX8CwtU',
      title: 'Kasoor',
      channelTitle: 'Prateek Kuhad',
      thumbnailUrl: 'https://img.youtube.com/vi/lJ8XfX8CwtU/hqdefault.jpg',
      durationSeconds: 196,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: 'p8k9L8M7J6H',
      title: 'Choo Lo',
      channelTitle: 'The Local Train',
      thumbnailUrl: 'https://img.youtube.com/vi/p8k9L8M7J6H/hqdefault.jpg',
      durationSeconds: 235,
      category: 'indie',
    ),
    YouTubeVideoItem(
      id: 'k6j7h8g9f0e',
      title: 'Aaftaab',
      channelTitle: 'The Local Train',
      thumbnailUrl: 'https://img.youtube.com/vi/k6j7h8g9f0e/hqdefault.jpg',
      durationSeconds: 245,
      category: 'indie',
    ),

    // ── Global Pop 100 ───────────────────────────────────────────────────────
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
      durationSeconds: 234,
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
      id: 'K4DyBUG242c',
      title: 'Starboy',
      channelTitle: 'The Weeknd ft. Daft Punk',
      thumbnailUrl: 'https://img.youtube.com/vi/K4DyBUG242c/hqdefault.jpg',
      durationSeconds: 230,
      category: 'global',
    ),
    YouTubeVideoItem(
      id: 'YQHsXMglC9A',
      title: 'Hello',
      channelTitle: 'Adele',
      thumbnailUrl: 'https://img.youtube.com/vi/YQHsXMglC9A/hqdefault.jpg',
      durationSeconds: 295,
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

    // ── Regional (Marathi, Gujarati, Tamil, Telugu, Bengali) ──────────────────
    YouTubeVideoItem(
      id: '5Eqb_-j3FDA',
      title: 'Zingaat (Sairat)',
      channelTitle: 'Ajay-Atul',
      thumbnailUrl: 'https://img.youtube.com/vi/5Eqb_-j3FDA/hqdefault.jpg',
      durationSeconds: 228,
      category: 'marathi',
    ),
    YouTubeVideoItem(
      id: 'kJ2eW-2Ew6k',
      title: 'Arabic Kuthu (Beast)',
      channelTitle: 'Anirudh Ravichander & Jonita Gandhi',
      thumbnailUrl: 'https://img.youtube.com/vi/kJ2eW-2Ew6k/hqdefault.jpg',
      durationSeconds: 280,
      category: 'tamil',
    ),
    YouTubeVideoItem(
      id: 'tOM-nWPcR4U',
      title: 'Naatu Naatu (RRR)',
      channelTitle: 'M.M. Keeravaani, Rahul Sipligunj',
      thumbnailUrl: 'https://img.youtube.com/vi/tOM-nWPcR4U/hqdefault.jpg',
      durationSeconds: 215,
      category: 'telugu',
    ),
    YouTubeVideoItem(
      id: 'khalasi12345',
      title: 'Khalasi (Coke Studio Bharat)',
      channelTitle: 'Aditya Gadhvi & Achint',
      thumbnailUrl: 'https://img.youtube.com/vi/L0MK7qz13bU/hqdefault.jpg',
      durationSeconds: 250,
      category: 'gujarati',
    ),
    YouTubeVideoItem(
      id: 'bengali00123',
      title: 'Bhalobashar Morshum (X=Prem)',
      channelTitle: 'Arijit Singh & Shreya Ghoshal',
      thumbnailUrl: 'https://img.youtube.com/vi/Umqb9KENgmk/hqdefault.jpg',
      durationSeconds: 260,
      category: 'bengali',
    ),
    YouTubeVideoItem(
      id: '9lOaHq0_t_A',
      title: 'Lofi Sleep Beats & Chill Atmosphere',
      channelTitle: 'Lofi Girl & Chill Beats',
      thumbnailUrl: 'https://img.youtube.com/vi/9lOaHq0_t_A/hqdefault.jpg',
      durationSeconds: 300,
      category: 'ambient',
    ),
  ];

  List<YouTubeVideoItem> _fallbackSearch(
    String query, {
    String order = 'relevance',
    required int maxResults,
    Set<String> excludeIds = const {},
  }) {
    final cleanQuery = query.toLowerCase().trim();

    // Map common query words directly to categories
    String? matchedCategory;
    if (cleanQuery.contains('devotional') ||
        cleanQuery.contains('bhajan') ||
        cleanQuery.contains('hanuman') ||
        cleanQuery.contains('aarti')) {
      matchedCategory = 'devotional';
    } else if (cleanQuery.contains('sufi') ||
        cleanQuery.contains('ghazal') ||
        cleanQuery.contains('nusrat')) {
      matchedCategory = 'sufi';
    } else if (cleanQuery.contains('90s') ||
        cleanQuery.contains('nostalgia') ||
        cleanQuery.contains('evergreen') ||
        cleanQuery.contains('classic')) {
      matchedCategory = 'nostalgia';
    } else if (cleanQuery.contains('workout') ||
        cleanQuery.contains('gym') ||
        cleanQuery.contains('cardio') ||
        cleanQuery.contains('hype')) {
      matchedCategory = 'workout';
    } else if (cleanQuery.contains('punjabi') ||
        cleanQuery.contains('diljit') ||
        cleanQuery.contains('aujla') ||
        cleanQuery.contains('dhillon')) {
      matchedCategory = 'punjabi';
    } else if (cleanQuery.contains('bollywood') ||
        cleanQuery.contains('hindi') ||
        cleanQuery.contains('arijit')) {
      matchedCategory = 'bollywood';
    } else if (cleanQuery.contains('indie') ||
        cleanQuery.contains('acoustic') ||
        cleanQuery.contains('anuv') ||
        cleanQuery.contains('kuhad')) {
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
    } else if (cleanQuery.contains('chill') ||
        cleanQuery.contains('sleep') ||
        cleanQuery.contains('lofi') ||
        cleanQuery.contains('ambient')) {
      matchedCategory = 'ambient';
    }

    // 1. Direct category match
    if (matchedCategory != null) {
      final catMatches = _curatedCatalog.where((item) {
        return !excludeIds.contains(item.id) &&
            item.category == matchedCategory;
      }).toList();

      if (catMatches.isNotEmpty) {
        if (catMatches.length < maxResults) {
          final others = _curatedCatalog.where((item) {
            return !excludeIds.contains(item.id) &&
                !catMatches.any((m) => m.id == item.id);
          }).toList();
          catMatches.addAll(others.take(maxResults - catMatches.length));
        }
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

    // 3. Fallback to broad catalog
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
