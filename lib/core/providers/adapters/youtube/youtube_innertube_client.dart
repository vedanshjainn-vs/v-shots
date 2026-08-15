// V Shots — YouTube Music InnerTube discovery client
//
// This client is metadata/discovery only. Playback remains delegated to the
// app's existing official YouTube IFrame player.
//
// The response format is an internal YouTube format, so parsing is defensive.
// Client values are bootstrapped from music.youtube.com when possible and use
// a current WEB_REMIX fallback so a stale hard-coded version is not required.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class InnerTubeVideoItem {
  const InnerTubeVideoItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    this.durationSeconds = 0,
  });

  final String id;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final int durationSeconds;
}

class YouTubeInnerTubeClient {
  YouTubeInnerTubeClient({http.Client? client}) : _http = client ?? http.Client();

  static const String _host = 'https://music.youtube.com';
  static const String _fallbackApiKey =
      'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  static const String _fallbackVersion = '1.20260707.12.00';

  final http.Client _http;
  String? _apiKey;
  String? _clientVersion;
  DateTime? _bootstrappedAt;

  Future<List<InnerTubeVideoItem>> search(
    String query, {
    int limit = 20,
    Set<String> excludeIds = const {},
  }) async {
    if (query.trim().isEmpty) return const [];
    await _bootstrap();

    final response = await _http
        .post(
          Uri.parse('$_host/youtubei/v1/search?prettyPrint=false&key=$_apiKey'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Origin': _host,
            'Referer': '$_host/',
          },
          body: jsonEncode({
            'query': query.trim(),
            'context': _context(),
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('YouTube Music InnerTube search ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final parsed = _parseItems(decoded, limit: limit, excludeIds: excludeIds);
    if (parsed.isEmpty) {
      debugPrint('[InnerTube] Search returned no parseable music items for "$query"');
    }
    return parsed;
  }

  /// Fetches the live YouTube Music home browse response. This is intentionally
  /// exposed separately so Home can evolve toward native Music shelves without
  /// coupling the player to the discovery transport.
  Future<List<InnerTubeShelf>> home({int maxShelves = 18}) async {
    await _bootstrap();
    final response = await _post(
      'browse',
      {'browseId': 'FEmusic_home'},
    );
    return _parseShelves(response).take(maxShelves).toList();
  }

  Future<List<String>> suggestions(String query) async {
    if (query.trim().isEmpty) return const [];
    await _bootstrap();
    final uri = Uri.parse(
      '$_host/youtubei/v1/music/get_search_suggestions'
      '?prettyPrint=false&key=$_apiKey',
    );
    final response = await _http
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Origin': _host,
            'Referer': '$_host/',
          },
          body: jsonEncode({
            'input': query.trim(),
            'context': _context(),
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) return const [];

    final out = <String>[];
    void walk(dynamic node) {
      if (node is Map<String, dynamic>) {
        final text = _text(node['query']);
        if (text.isNotEmpty && text.length <= 120 && !out.contains(text)) {
          out.add(text);
        }
        for (final value in node.values) walk(value);
      } else if (node is List) {
        for (final value in node) walk(value);
      }
    }

    walk(jsonDecode(response.body));
    return out.take(8).toList();
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await _http
        .post(
          Uri.parse('$_host/youtubei/v1/$endpoint?prettyPrint=false&key=$_apiKey'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Origin': _host,
            'Referer': 'https://music.youtube.com/',
          },
          body: jsonEncode({
            'context': _context(),
            ...body,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('YouTube Music InnerTube $endpoint ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid InnerTube response');
    }
    return decoded;
  }

  Future<void> _bootstrap() async {
    final now = DateTime.now();
    if (_apiKey != null &&
        _clientVersion != null &&
        _bootstrappedAt != null &&
        now.difference(_bootstrappedAt!) < const Duration(hours: 6)) {
      return;
    }

    _apiKey = _fallbackApiKey;
    _clientVersion = _fallbackVersion;

    try {
      final response = await _http.get(
        Uri.parse('$_host/'),
        headers: const {
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'en-IN,en;q=0.9',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/136.0 Mobile Safari/537.36',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final html = response.body;
        final key = _firstMatch(
          html,
          RegExp(r'INNERTUBE_API_KEY["\']?\s*:\s*["\']([^"\']+)'),
        );
        final version = _firstMatch(
          html,
          RegExp(r'INNERTUBE_CLIENT_VERSION["\']?\s*:\s*["\']([^"\']+)'),
        );
        if (key != null && key.isNotEmpty) _apiKey = key;
        if (version != null && version.isNotEmpty) _clientVersion = version;
      }
    } catch (e) {
      debugPrint('[InnerTube] bootstrap fallback: $e');
    }

    _bootstrappedAt = now;
  }

  Map<String, dynamic> _context() => {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': _clientVersion ?? _fallbackVersion,
          'hl': 'en',
          'gl': 'IN',
          'platform': 'DESKTOP',
        },
      };

  List<InnerTubeVideoItem> _parseItems(
    dynamic root, {
    required int limit,
    required Set<String> excludeIds,
  }) {
    final result = <InnerTubeVideoItem>[];
    final seen = <String>{...excludeIds};

    void addItem(dynamic node) {
      if (node is! Map<String, dynamic>) return;

      final renderer = node['musicResponsiveListItemRenderer'];
      if (renderer is Map<String, dynamic>) {
        final id = _videoId(renderer);
        if (id != null && !seen.contains(id)) {
          final title = _responsiveTitle(renderer);
          final artist = _responsiveArtist(renderer);
          final art = _thumbnail(renderer['thumbnail']);
          if (title.isNotEmpty && art.isNotEmpty) {
            result.add(
              InnerTubeVideoItem(
                id: id,
                title: title,
                artist: artist,
                thumbnailUrl: art,
                durationSeconds: _durationFrom(renderer),
              ),
            );
            seen.add(id);
          }
        }
      }

      final twoRow = node['musicTwoRowItemRenderer'];
      if (twoRow is Map<String, dynamic>) {
        final id = _videoId(twoRow);
        if (id != null && !seen.contains(id)) {
          final title = _text(twoRow['title']);
          final artist = _text(twoRow['subtitle']);
          final art = _thumbnail(twoRow['thumbnail']);
          if (title.isNotEmpty && art.isNotEmpty) {
            result.add(
              InnerTubeVideoItem(
                id: id,
                title: title,
                artist: artist,
                thumbnailUrl: art,
                durationSeconds: _durationFrom(twoRow),
              ),
            );
            seen.add(id);
          }
        }
      }
    }

    void walk(dynamic node) {
      if (result.length >= limit) return;
      if (node is Map<String, dynamic>) {
        addItem(node);
        for (final value in node.values) {
          walk(value);
          if (result.length >= limit) break;
        }
      } else if (node is List) {
        for (final value in node) {
          walk(value);
          if (result.length >= limit) break;
        }
      }
    }

    walk(root);
    return result;
  }

  List<InnerTubeShelf> _parseShelves(Map<String, dynamic> root) {
    final shelves = <InnerTubeShelf>[];
    final seenTitles = <String>{};

    void walk(dynamic node) {
      if (node is Map<String, dynamic>) {
        final carousel = node['musicCarouselShelfRenderer'];
        if (carousel is Map<String, dynamic>) {
          final title = _text(carousel['header']);
          final items = _parseItems(
            carousel['contents'],
            limit: 20,
            excludeIds: const {},
          );
          if (title.isNotEmpty && items.isNotEmpty && seenTitles.add(title)) {
            shelves.add(InnerTubeShelf(title: title, items: items));
          }
        }

        final shelf = node['musicShelfRenderer'];
        if (shelf is Map<String, dynamic>) {
          final title = _text(shelf['title']);
          final items = _parseItems(
            shelf['contents'],
            limit: 30,
            excludeIds: const {},
          );
          if (title.isNotEmpty && items.isNotEmpty && seenTitles.add(title)) {
            shelves.add(InnerTubeShelf(title: title, items: items));
          }
        }

        for (final value in node.values) walk(value);
      } else if (node is List) {
        for (final value in node) walk(value);
      }
    }

    walk(root);
    return shelves;
  }

  String? _videoId(Map<String, dynamic> renderer) {
    final direct = renderer['videoId'];
    if (direct is String && direct.isNotEmpty) return direct;

    dynamic endpoint = renderer['navigationEndpoint'];
    if (endpoint is Map) {
      final watch = endpoint['watchEndpoint'];
      final id = watch is Map ? watch['videoId'] : null;
      if (id is String && id.isNotEmpty) return id;
    }

    final playlist = renderer['playlistItemData'];
    if (playlist is Map) {
      final id = playlist['videoId'];
      if (id is String && id.isNotEmpty) return id;
    }

    return null;
  }

  String _responsiveTitle(Map<String, dynamic> renderer) {
    final columns = renderer['flexColumns'];
    if (columns is List && columns.isNotEmpty) {
      return _text(columns.first);
    }
    return _text(renderer['title']);
  }

  String _responsiveArtist(Map<String, dynamic> renderer) {
    final columns = renderer['flexColumns'];
    if (columns is List && columns.length > 1) {
      return _text(columns[1]);
    }
    return _text(renderer['subtitle']);
  }

  int _durationFrom(Map<String, dynamic> renderer) {
    final candidates = <dynamic>[
      renderer['lengthText'],
      renderer['fixedColumns'],
      renderer['duration'],
    ];
    for (final candidate in candidates) {
      final value = _text(candidate);
      final parsed = _parseDuration(value);
      if (parsed > 0) return parsed;
    }
    return 0;
  }

  int _parseDuration(String value) {
    final parts = value.split(':');
    if (parts.length < 2 || parts.length > 3) return 0;
    try {
      var seconds = 0;
      for (final part in parts) {
        seconds = seconds * 60 + int.parse(part.trim());
      }
      return seconds;
    } catch (_) {
      return 0;
    }
  }

  String _thumbnail(dynamic node) {
    if (node is Map<String, dynamic>) {
      final thumbs = node['thumbnails'];
      if (thumbs is List && thumbs.isNotEmpty) {
        for (final item in thumbs.reversed) {
          if (item is Map && item['url'] is String) return item['url'] as String;
        }
      }
    }
    return '';
  }

  String _text(dynamic node) {
    if (node is String) return node.trim();
    if (node is Map<String, dynamic>) {
      final simple = node['simpleText'];
      if (simple is String) return simple.trim();
      final runs = node['runs'];
      if (runs is List) {
        return runs
            .whereType<Map>()
            .map((r) => (r['text'] as String?) ?? '')
            .join()
            .trim();
      }
      for (final key in const ['title', 'subtitle', 'text', 'label']) {
        final value = node[key];
        final parsed = _text(value);
        if (parsed.isNotEmpty) return parsed;
      }
    }
    return '';
  }

  String? _firstMatch(String input, RegExp pattern) =>
      pattern.firstMatch(input)?.group(1);

  void dispose() => _http.close();
}

class InnerTubeShelf {
  const InnerTubeShelf({required this.title, required this.items});

  final String title;
  final List<InnerTubeVideoItem> items;
}