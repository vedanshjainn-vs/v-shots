// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — InnerTubeMusicService (shared discovery layer)
//
// ONE reusable discovery service used by Home, Discovery and Search.
//
// DATA: YouTube Music's public InnerTube browse/search endpoints. This is a
// METADATA-ONLY discovery client (videoId / title / artist / album / artwork /
// duration / browse sections). It does NOT download or extract audio, does not
// touch playback, and never bypasses YouTube's player.
//
// PLAYBACK: This service never plays audio. The UI hands the videoId to the
// EXISTING V Shots official YouTube player via the existing playTrack()
// pipeline (wired in main.dart). No second player, no audio extraction.
//
// The parser is deliberately defensive because InnerTube response shapes can
// change. If one shelf fails it is skipped; a failure never breaks the page.
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

  /// Converts to the app's canonical track-map used by playTrack / the global
  /// official player. videoId is included so the existing pipeline works.
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

/// A titled horizontal shelf of music on Home / Discovery.
class MusicShelf {
  const MusicShelf({
    required this.title,
    required this.tracks,
    this.subtitle,
    this.browseId,
  });

  final String title;
  final List<DiscoveryTrack> tracks;
  final String? subtitle;
  final String? browseId;
}

/// Shared InnerTube discovery client (browse + search).
///
/// Only used for metadata discovery; never for playback.
class InnerTubeMusicService {
  InnerTubeMusicService();

  static const _host = 'https://music.youtube.com/youtubei/v1';
  static const _homeBrowseId = 'FEmusic_home';
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

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$_host/$endpoint?prettyPrint=false'),
          headers: const {
            'Content-Type': 'application/json',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130 Safari/537.36',
          },
          body: jsonEncode({
            'context': _context,
            ...body,
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('InnerTube ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid InnerTube response');
    }
    return decoded;
  }

  /// Browses the YouTube Music home feed and returns real shelves
  /// (e.g. Quick Picks, Trending, New Music). Skips empty/duplicate shelves.
  Future<List<MusicShelf>> homeFeed() async {
    final data = await _post('browse', {'browseId': _homeBrowseId});
    final sections = <MusicShelf>[];

    void walk(dynamic node, {String? inheritedTitle}) {
      if (node is Map<String, dynamic>) {
        final shelfTitle = _text(node['title']) ?? inheritedTitle;
        final tracks = _extractTracks(node);
        if (tracks.isNotEmpty && shelfTitle != null) {
          sections.add(MusicShelf(
            title: shelfTitle.trim(),
            tracks: tracks.take(20).toList(),
          ));
        }
        for (final value in node.values) {
          if (value is Map || value is List) {
            walk(value, inheritedTitle: shelfTitle);
          }
        }
      } else if (node is List) {
        for (final item in node) {
          walk(item, inheritedTitle: inheritedTitle);
        }
      }
    }

    walk(data);

    final unique = <String, MusicShelf>{};
    for (final shelf in sections) {
      final key = shelf.title.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (!unique.containsKey(key)) unique[key] = shelf;
    }

    return unique.values.take(12).toList();
  }

  /// Searches YouTube Music and returns up to [count] real tracks.
  Future<List<DiscoveryTrack>> search(String query, {int count = 30}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final data = await _post('search', {
      'query': q,
      'params': _searchParams,
    });
    final result = <DiscoveryTrack>[];

    void walk(dynamic node) {
      if (node is Map<String, dynamic>) {
        final id = node['videoId'] as String?;
        final title = _text(node['title']);
        if (id != null && title != null) {
          final thumbs = _thumbnails(node['thumbnail']);
          result.add(DiscoveryTrack(
            id: id,
            title: title,
            artist: _runsText(node['flexColumns']),
            artwork: thumbs.isEmpty ? '' : thumbs.last,
          ));
        }
        for (final value in node.values) {
          if (value is Map || value is List) walk(value);
        }
      } else if (node is List) {
        for (final value in node) {
          walk(value);
        }
      }
    }

    walk(data);

    final seen = <String>{};
    return result
        .where((e) => seen.add(e.id))
        .where((e) => e.artwork.isNotEmpty)
        .take(count)
        .toList();
  }

  /// Category discovery: builds one shelf per query via search. Used by the
  /// Discovery chips (Trending, Hindi, Punjabi, Romantic, ...).
  Future<List<MusicShelf>> categoryShelves(
    List<String> categories,
  ) async {
    final shelves = <MusicShelf>[];
    for (final cat in categories) {
      try {
        final tracks = await search(cat, count: 20);
        if (tracks.isEmpty) continue;
        shelves.add(MusicShelf(title: cat, tracks: tracks.take(12).toList()));
      } catch (e) {
        debugPrint('[InnerTube] category "$cat" skipped: $e');
      }
    }
    return shelves;
  }

  /// Recursively extracts playable tracks (videoId + title + artwork) from a
  /// node tree. Defensive: ignores nodes without a usable videoId/title.
  List<DiscoveryTrack> _extractTracks(Map<String, dynamic> node) {
    final output = <DiscoveryTrack>[];

    void walk(dynamic value) {
      if (value is Map<String, dynamic>) {
        final id = value['videoId'] as String?;
        final title = _text(value['title']);
        if (id != null && title != null) {
          final thumbs = _thumbnails(value['thumbnail']);
          output.add(DiscoveryTrack(
            id: id,
            title: title,
            artist: _runsText(value['flexColumns']),
            artwork: thumbs.isEmpty ? '' : thumbs.last,
          ));
        }
        for (final child in value.values) {
          if (child is Map || child is List) walk(child);
        }
      } else if (value is List) {
        for (final child in value) {
          walk(child);
        }
      }
    }

    walk(node);

    final seen = <String>{};
    return output.where((e) => seen.add(e.id)).toList();
  }

  String? _text(dynamic value) {
    if (value is Map<String, dynamic>) {
      final simple = value['simpleText'];
      if (simple is String) return simple;
      final runs = value['runs'];
      if (runs is List) {
        final joined = runs
            .whereType<Map<String, dynamic>>()
            .map((e) => e['text'])
            .whereType<String>()
            .join();
        if (joined.isNotEmpty) return joined;
      }
    } else if (value is String) {
      return value;
    }
    return null;
  }

  String _runsText(dynamic value) {
    final texts = <String>[];

    void walk(dynamic node) {
      if (node is Map<String, dynamic>) {
        final t = _text(node['text']);
        if (t != null) texts.add(t);
        for (final child in node.values) {
          if (child is Map || child is List) walk(child);
        }
      } else if (node is List) {
        for (final child in node) {
          walk(child);
        }
      }
    }

    walk(value);
    return texts.take(3).join(' • ');
  }

  List<String> _thumbnails(dynamic value) {
    final result = <String>[];

    void walk(dynamic node) {
      if (node is Map<String, dynamic>) {
        final url = node['url'];
        if (url is String && url.isNotEmpty) result.add(url);
        for (final child in node.values) {
          if (child is Map || child is List) walk(child);
        }
      } else if (node is List) {
        for (final child in node) {
          walk(child);
        }
      }
    }

    walk(value);
    return result;
  }

  void dispose() => _client.close();
}
