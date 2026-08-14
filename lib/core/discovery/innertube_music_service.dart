// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — InnerTubeMusicService (shared discovery layer)
//
// ONE reusable discovery service used by Home, Discovery and Search.
//
// DATA: YouTube Music's public InnerTube browse/search endpoints. This is a
// METADATA-ONLY discovery client (videoId / title / artist / artwork /
// duration / browse sections). It does NOT download or extract audio, does not
// touch playback, and never bypasses YouTube's player.
//
// IMPORTANT (real-device fix): the InnerTube search endpoint returns real
// playable tracks with `videoId` nested inside `navigationEndpoint.watchEndpoint`
// and title/artist inside `flexColumns`. The parser below handles that exact
// structure. `FEmusic_home` browse only returns playlist refs (RDCLAK/OLAK),
// so Home shelves are built from real search results instead.
//
// PLAYBACK: This service never plays audio. The UI hands the videoId to the
// EXISTING V Shots official YouTube player via the existing playTrack()
// pipeline. No second player, no audio extraction.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A normalized music item (metadata only — no audio access).
class DiscoveryTrack {
  const DiscoveryTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.artwork,
    this.album,
    this.durationSeconds,
  });

  final String id;
  final String title;
  final String artist;
  final String artwork;
  final String? album;
  final int? durationSeconds;

  Map<String, dynamic> toTrackMap() => {
        'id': id,
        'videoId': id,
        'title': title,
        'artist': artist,
        'artwork': artwork,
        'album': album,
        'duration': durationSeconds ?? 0,
        'source': 'youtube_music_innertube',
      };
}

/// A titled shelf of music on Home / Discovery.
class MusicShelf {
  const MusicShelf({
    required this.title,
    required this.tracks,
    this.subtitle,
  });

  final String title;
  final List<DiscoveryTrack> tracks;
  final String? subtitle;
}

/// Default Home shelf queries (each becomes a real shelf via InnerTube search).
const List<Map<String, String>> kHomeShelfQueries = [
  {'title': 'Quick Picks', 'query': 'trending songs 2026'},
  {'title': 'Trending Music', 'query': 'viral trending songs'},
  {'title': 'New Music', 'query': 'new music 2026 releases'},
  {'title': 'Bollywood Hits', 'query': 'bollywood hindi hits'},
  {'title': 'Hindi Hits', 'query': 'hindi songs hits'},
  {'title': 'Punjabi Hits', 'query': 'punjabi hits songs'},
  {'title': 'English Pop', 'query': 'english pop hits'},
  {'title': 'Romantic', 'query': 'romantic love songs'},
  {'title': 'Chill', 'query': 'chill lofi music'},
  {'title': 'Workout', 'query': 'workout gym music'},
];

/// Mood/context -> search queries used to build a Discovery reel feed.
const Map<String, List<String>> kMoodQueries = {
  'Trending': ['trending songs', 'viral hits', 'top 50 songs'],
  'Workout': ['workout gym music', 'high energy workout', 'cardio music'],
  'Energize': ['energetic dance music', 'upbeat party hits'],
  'Romance': ['romantic love songs', 'romantic hindi songs'],
  'Sad': ['sad heartbreak songs', 'emotional songs'],
  'Party': ['party dance songs', 'party remix hits'],
  'Focus': ['lofi focus music', 'study beats instrumental'],
  'Chill': ['chill lofi music', 'relaxing calm songs'],
  'Sleep': ['sleep ambient music', 'calm relaxation music'],
  'Devotional': ['devotional bhajan', 'spiritual bhajan aarti'],
  'Relax': ['relax acoustic music', 'soft chill songs'],
  'Bollywood': ['bollywood hindi hits', 'bollywood songs'],
  'Hindi': ['hindi songs hits', 'hindi romantic songs'],
  'Punjabi': ['punjabi hits songs', 'punjabi party songs'],
  'English': ['english pop hits', 'english songs'],
  'EDM': ['edm electronic dance', 'house dance music'],
  'Hip-Hop': ['hip hop rap songs', 'rap hits'],
  'Lo-fi': ['lofi beats', 'lofi hip hop'],
  'Global': ['global pop hits', 'international hits'],
};

/// Shared InnerTube discovery client (browse + search). Metadata only.
class InnerTubeMusicService {
  InnerTubeMusicService();

  static const _host = 'https://music.youtube.com/youtubei/v1';
  static const _searchParams = 'EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D';

  final http.Client _client = http.Client();

  Map<String, dynamic> get _context => {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20260101.01.00',
          'hl': 'en',
          'gl': 'IN',
        },
      };

  /// POSTs to an InnerTube endpoint with the shared context + logging.
  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_host/$endpoint?prettyPrint=false');
    final payload = jsonEncode({'context': _context, ...body});
    debugPrint('[MusicDiscovery] request $endpoint');
    debugPrint('[MusicDiscovery] request body: $payload');
    final response = await _client
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130 Safari/537.36',
          },
          body: payload,
        )
        .timeout(const Duration(seconds: 12));
    debugPrint('[MusicDiscovery] status ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('[MusicDiscovery] error http ${response.statusCode}');
      throw Exception('InnerTube ${response.statusCode}');
    }
    debugPrint('[MusicDiscovery] response ${response.body.length} chars');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      debugPrint('[MusicDiscovery] error invalid json');
      throw Exception('Invalid InnerTube response');
    }
    return decoded;
  }

  /// Builds Home shelves from real InnerTube search queries. If [recentlyPlayed]
  /// tracks are provided, prepends a personalized "More like X / Because you
  /// listened to X" shelf derived from the most recent track's artist.
  Future<List<MusicShelf>> homeFeed({
    List<Map<String, dynamic>> recentlyPlayed = const [],
  }) async {
    final shelves = <MusicShelf>[];

    // Personalized: derive a query from the most recent played artist.
    for (final recent in recentlyPlayed.take(2)) {
      final artist = (recent['artist'] as String?)?.trim() ?? '';
      final title = (recent['title'] as String?)?.trim() ?? '';
      if (artist.isEmpty && title.isEmpty) continue;
      final artistQuery = artist.isNotEmpty ? artist : title.split(' ').first;
      try {
        final tracks = await search('$artistQuery songs', count: 12);
        if (tracks.isNotEmpty) {
          shelves.add(MusicShelf(
            title:
                artist.isNotEmpty ? 'More like $artist' : 'Because you played',
            tracks: tracks.take(10).toList(),
          ));
        }
      } catch (e) {
        debugPrint('[MusicDiscovery] error personal shelf: $e');
      }
    }

    for (final cfg in kHomeShelfQueries) {
      try {
        final tracks = await search(cfg['query']!, count: 14);
        if (tracks.isEmpty) continue;
        shelves.add(MusicShelf(
          title: cfg['title']!,
          tracks: tracks.take(12).toList(),
        ));
        debugPrint(
            '[MusicDiscovery] parsed shelves ${cfg['title']}: ${tracks.length} tracks');
      } catch (e) {
        debugPrint('[MusicDiscovery] error shelf ${cfg['title']}: $e');
      }
    }
    return shelves;
  }

  /// Searches YouTube Music and returns real tracks with playable videoIds.
  Future<List<DiscoveryTrack>> search(String query, {int count = 30}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final data = await _post('search', {
      'query': q,
      'params': _searchParams,
    });
    final result = _extractResponsiveTracks(data);
    final seen = <String>{};
    final tracks = result
        .where((e) => e.id.isNotEmpty && e.artwork.isNotEmpty)
        .where((e) => seen.add(e.id))
        .take(count)
        .toList();
    debugPrint(
        '[MusicDiscovery] parsed tracks "$q": ${tracks.length} of ${result.length}');
    return tracks;
  }

  /// Builds a Discovery reel feed by running several real searches and
  /// de-duplicating by videoId. Returns as many unique tracks as possible.
  ///
  /// If [mood] is provided, its query strategies drive the feed. Otherwise a
  /// trending-first mix is used. [excludeIds] avoids returning already-shown
  /// tracks (session-level seen set).
  Future<List<DiscoveryTrack>> discoveryFeed({
    String? mood,
    int target = 30,
    Set<String> excludeIds = const {},
  }) async {
    final queries = mood != null && kMoodQueries.containsKey(mood)
        ? kMoodQueries[mood]!
        : const <String>[
            'trending songs',
            'bollywood hits',
            'punjabi hits',
            'hindi songs',
            'english pop',
            'romantic songs',
            'chill lofi',
            'workout music',
            'new music',
            'sad songs',
            'devotional songs',
            'party songs',
          ];
    final seen = <String>{};
    final tracks = <DiscoveryTrack>[];
    for (final q in queries) {
      if (tracks.length >= target) break;
      try {
        final batch = await search(q, count: 20);
        for (final t in batch) {
          if (tracks.length >= target) break;
          if (excludeIds.contains(t.id)) continue;
          if (seen.add(t.id)) tracks.add(t);
        }
      } catch (e) {
        debugPrint('[MusicDiscovery] error feed query "$q": $e');
      }
    }
    debugPrint('[MusicDiscovery] discovery feed: ${tracks.length} tracks');
    return tracks;
  }

  /// Extracts playable tracks from a search/browse JSON tree.
  ///
  /// Handles the REAL InnerTube structure:
  ///   - videoId is nested in `navigationEndpoint.watchEndpoint.videoId`
  ///     (or a top-level `videoId`).
  ///   - title/artist come from `flexColumns[].musicResponsiveListItemFlexColumnRenderer.text.runs[]`.
  ///   - thumbnail lives in `thumbnail.musicThumbnailRenderer.thumbnail.thumbnails[]`.
  List<DiscoveryTrack> _extractResponsiveTracks(Map<String, dynamic> root) {
    final output = <DiscoveryTrack>[];

    void walk(dynamic node) {
      if (node is Map<String, dynamic>) {
        final rlr = node['musicResponsiveListItemRenderer'];
        if (rlr is Map<String, dynamic>) {
          final track = _fromResponsiveItem(rlr);
          if (track != null) output.add(track);
        } else {
          for (final child in node.values) {
            if (child is Map || child is List) walk(child);
          }
        }
      } else if (node is List) {
        for (final child in node) {
          if (child is Map || child is List) walk(child);
        }
      }
    }

    walk(root);
    return output;
  }

  DiscoveryTrack? _fromResponsiveItem(Map<String, dynamic> rlr) {
    // videoId: nested under navigationEndpoint.watchEndpoint or direct.
    String? id;
    final nav = rlr['navigationEndpoint'];
    if (nav is Map<String, dynamic>) {
      final we = nav['watchEndpoint'];
      if (we is Map<String, dynamic> && we['videoId'] is String) {
        id = we['videoId'] as String;
      }
    }
    id ??= _findVideoId(rlr);
    if (id == null || id.isEmpty) return null;

    // Title + artist from flexColumns.
    final cols = rlr['flexColumns'];
    String title = '';
    String artist = '';
    if (cols is List && cols.isNotEmpty) {
      final titleCol = _flexText(cols[0]);
      title = titleCol.title;
      artist = titleCol.artist;
    }
    if (title.isEmpty) {
      final titleText = _text(rlr['title']);
      if (titleText != null) title = titleText;
    }

    final artwork = _responsiveThumbnail(rlr['thumbnail']);
    if (title.isEmpty) return null;

    return DiscoveryTrack(
      id: id,
      title: title,
      artist: artist,
      artwork: artwork,
      durationSeconds: _responsiveDuration(rlr),
    );
  }

  ({String title, String artist}) _flexText(dynamic flexCol) {
    final renderer = flexCol is Map<String, dynamic>
        ? flexCol['musicResponsiveListItemFlexColumnRenderer']
        : null;
    final text = renderer is Map<String, dynamic> ? renderer['text'] : null;
    final runs = _collectRuns(text);
    String title = '';
    String artist = '';
    for (final r in runs) {
      if (r.isEmpty) continue;
      if (title.isEmpty) {
        title = r;
      } else if (artist.isEmpty) {
        artist = r;
      } else {
        break;
      }
    }
    return (title: title, artist: artist);
  }

  List<String> _collectRuns(dynamic node) {
    final result = <String>[];
    void walk(dynamic n) {
      if (n is Map<String, dynamic>) {
        final text = n['text'];
        if (text is String && text.isNotEmpty) result.add(text);
        for (final v in n.values) {
          if (v is Map || v is List) walk(v);
        }
      } else if (n is List) {
        for (final v in n) {
          if (v is Map || v is List) walk(v);
        }
      }
    }

    walk(node);
    return result;
  }

  String _responsiveThumbnail(dynamic thumb) {
    if (thumb is! Map<String, dynamic>) return '';
    final musicThumb = thumb['musicThumbnailRenderer'];
    if (musicThumb is Map<String, dynamic>) {
      final t = musicThumb['thumbnail'];
      if (t is Map<String, dynamic>) {
        final thumbs = t['thumbnails'];
        if (thumbs is List && thumbs.isNotEmpty) {
          final last = thumbs.last;
          if (last is Map<String, dynamic> && last['url'] is String) {
            return last['url'] as String;
          }
        }
      }
    }
    final thumbs = thumb['thumbnails'];
    if (thumbs is List && thumbs.isNotEmpty) {
      final last = thumbs.last;
      if (last is Map<String, dynamic> && last['url'] is String) {
        return last['url'] as String;
      }
    }
    return '';
  }

  int? _responsiveDuration(Map<String, dynamic> rlr) {
    final cols = rlr['flexColumns'];
    if (cols is List) {
      for (final c in cols) {
        final renderer = c is Map<String, dynamic>
            ? c['musicResponsiveListItemFlexColumnRenderer']
            : null;
        final text = renderer is Map<String, dynamic> ? renderer['text'] : null;
        final runs = _collectRuns(text);
        for (final r in runs) {
          final secs = _parseDuration(r);
          if (secs != null) return secs;
        }
      }
    }
    return null;
  }

  int? _parseDuration(String text) {
    final parts = text.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]);
      final s = int.tryParse(parts[1]);
      if (m != null && s != null) return (m * 60) + s;
    }
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final s = int.tryParse(parts[2]);
      if (h != null && m != null && s != null) return (h * 3600) + (m * 60) + s;
    }
    return null;
  }

  String? _findVideoId(dynamic node) {
    if (node is Map<String, dynamic>) {
      if (node['videoId'] is String) return node['videoId'] as String;
      for (final v in node.values) {
        final r = _findVideoId(v);
        if (r != null) return r;
      }
    } else if (node is List) {
      for (final v in node) {
        final r = _findVideoId(v);
        if (r != null) return r;
      }
    }
    return null;
  }

  String? _text(dynamic value) {
    if (value is Map<String, dynamic>) {
      final simple = value['simpleText'];
      if (simple is String && simple.isNotEmpty) return simple;
      final runs = value['runs'];
      if (runs is List) {
        final joined = runs
            .whereType<Map<String, dynamic>>()
            .map((e) => e['text'])
            .whereType<String>()
            .join();
        if (joined.isNotEmpty) return joined;
      }
    } else if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  void dispose() => _client.close();
}
