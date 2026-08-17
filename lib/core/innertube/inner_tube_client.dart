// ═════════════════════════════════════════════════════════════════════════════
// V Shots — InnerTube client (YouTube's official web data API)
// ═════════════════════════════════════════════════════════════════════════════
//
// PRIMARY DISCOVERY SOURCE for Home / Discovery / Search.
//
// This talks to YouTube's own web endpoints (`/youtubei/v1/search`,
// `/youtubei/v1/next`) — the same ones the official youtube.com site uses —
// so results are the same live, real catalog a user sees on YouTube. It is
// used ONLY for metadata:
//
//   • search(query)          → ranked video results
//   • searchPage(…, token)   → paginated search (real continuation tokens)
//   • related(videoId)       → "more like this" recommendations
//
// COMPLIANCE SCOPE: this client never requests, caches, or returns any
// stream/format URL. Playback remains the existing OFFICIAL YouTube IFrame
// player (`youtube_player_iframe`). No stream extraction, no downloading, no
// second playback engine. If this client fails (blocked/network), the app
// falls back to the official YouTube Data API v3 provider and its curated
// catalog — so discovery never hard-depends on InnerTube.
//
// The INNERTUBE_API_KEY / client version are read from youtube.com's own
// page at runtime (cached) with public WEB-client constants as a bootstrap
// fallback, mirroring how the official site itself bootstraps.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'inner_tube_models.dart';

class InnerTubeClient {
  InnerTubeClient({
    http.Client? httpClient,
    String? apiKey,
    String? clientVersion,
    String? gl,
    String? hl,
  })  : _http = httpClient ?? http.Client(),
        _fixedKey = apiKey,
        _fixedVersion = clientVersion,
        _gl = gl ?? 'IN',
        _hl = hl ?? 'en';

  final http.Client _http;
  final String? _fixedKey;
  final String? _fixedVersion;
  final String _gl;
  final String _hl;

  static const String _endpointBase = 'https://www.youtube.com/youtubei/v1';
  static const String _homeUrl = 'https://www.youtube.com/';

  /// Publicly-known WEB client identifiers — bootstrap only; refreshed from
  /// youtube.com at runtime. YouTube rotates these occasionally.
  static const String _fallbackKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
  static const String _fallbackVersion = '2.20260813.05.00';

  String? _apiKey;
  String? _clientVersion;
  bool _contextLoaded = false;

  Future<void> _ensureContext() async {
    if (_contextLoaded) return;
    _contextLoaded = true;
    _apiKey =
        _fixedKey ?? await _extractField('INNERTUBE_API_KEY') ?? _fallbackKey;
    _clientVersion = _fixedVersion ??
        await _extractField('INNERTUBE_CLIENT_VERSION') ??
        _fallbackVersion;
  }

  Future<String?> _extractField(String field) async {
    try {
      final res = await _http
          .get(Uri.parse(_homeUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final match = RegExp('"$field":"([^"]+)"').firstMatch(res.body);
      return match?.group(1);
    } catch (e) {
      debugPrint('[InnerTube] context extraction failed: $e');
      return null;
    }
  }

  Map<String, dynamic> _context() => {
        'client': {
          'clientName': 'WEB',
          'clientVersion': _clientVersion ?? _fallbackVersion,
          'hl': _hl,
          'gl': _gl,
        },
      };

  Future<Map<String, dynamic>?> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    await _ensureContext();
    final uri = Uri.parse('$_endpointBase/$endpoint').replace(
      queryParameters: {'key': _apiKey ?? _fallbackKey, 'prettyPrint': 'false'},
    );
    // One retry — YouTube occasionally throttles bursts (the app fires
    // several discovery requests close together). Retrying once turns most
    // transient 4xx/5xx failures into real results. The backoff delay only
    // applies in release builds (debug/tests retry immediately so no timer
    // is left pending in the widget-test harness).
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await _http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) {
          debugPrint(
            '[InnerTube] $endpoint HTTP ${res.statusCode} '
            '(attempt ${attempt + 1})',
          );
          if (attempt == 0) {
            await _retryDelay();
            continue;
          }
          return null;
        }
        final decoded = jsonDecode(res.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      } catch (e) {
        debugPrint('[InnerTube] $endpoint failed (attempt ${attempt + 1}): $e');
        if (attempt == 0) {
          await _retryDelay();
          continue;
        }
        return null;
      }
    }
    return null;
  }

  Future<void> _retryDelay() async {
    if (kDebugMode) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  /// Searches for music videos. Returns up to [limit] unique items.
  Future<List<InnerTubeVideoItem>> search(
    String query, {
    int limit = 20,
    String order = 'relevance',
    Set<String> excludeIds = const {},
  }) async {
    final page = await searchPage(
      query,
      limit: limit,
      order: order,
      excludeIds: excludeIds,
    );
    return page.items.take(limit).toList();
  }

  /// Paginated search. Pass [continuationToken] from a previous page to
  /// request the next one.
  Future<InnerTubePage> searchPage(
    String query, {
    int limit = 20,
    String order = 'relevance',
    Set<String> excludeIds = const {},
    String? continuationToken,
  }) async {
    final body = <String, dynamic>{'context': _context()};
    if (continuationToken != null && continuationToken.isNotEmpty) {
      body['continuation'] = continuationToken;
    } else {
      body['query'] = query;
    }
    final json = await _post('search', body);
    if (json == null) return const InnerTubePage.empty();

    final items = _collectVideoRenderers(json);
    if (order == 'viewCount') {
      items.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    }
    final kept = <InnerTubeVideoItem>[];
    for (final it in items) {
      if (excludeIds.contains(it.videoId)) continue;
      kept.add(it);
    }
    return InnerTubePage(
      items: kept,
      continuationToken: _findContinuationToken(json),
    );
  }

  /// Related videos for [videoId] — the real "more like this" source.
  Future<List<InnerTubeVideoItem>> related(
    String videoId, {
    int limit = 20,
  }) async {
    final json = await _post('next', {
      'context': _context(),
      'videoId': videoId,
    });
    if (json == null) return const [];
    final seen = <String>{videoId};
    final kept = <InnerTubeVideoItem>[];
    for (final it in _collectLockupVideos(json)) {
      if (seen.add(it.videoId)) kept.add(it);
    }
    return kept.take(limit).toList();
  }

  Future<void> dispose() async {
    _http.close();
  }

  // ── Parsing helpers ─────────────────────────────────────────────────────

  void _walk(dynamic node, void Function(Map<String, dynamic>) visit) {
    if (node is Map<String, dynamic>) {
      visit(node);
      for (final value in node.values) {
        _walk(value, visit);
      }
    } else if (node is List) {
      for (final value in node) {
        _walk(value, visit);
      }
    }
  }

  List<InnerTubeVideoItem> _collectVideoRenderers(Map<String, dynamic> json) {
    final out = <InnerTubeVideoItem>[];
    _walk(json, (node) {
      final renderer = node['videoRenderer'];
      if (renderer is Map<String, dynamic>) {
        final item = _parseVideoRenderer(renderer);
        if (item != null) out.add(item);
      }
    });
    return out;
  }

  InnerTubeVideoItem? _parseVideoRenderer(Map<String, dynamic> v) {
    final videoId = v['videoId'] as String?;
    if (videoId == null || videoId.isEmpty) return null;
    final title = _runsText(v['title']) ?? '';
    if (title.isEmpty) return null;
    final channel = _firstNonEmpty([
          _runsText(v['ownerText']),
          _runsText(v['longBylineText']),
          _runsText(v['shortBylineText']),
        ]) ??
        '';
    final duration = _parseDuration(
      (v['lengthText'] as Map<String, dynamic>?)?['simpleText'],
    );
    final thumbnail = _bestThumbnail(
      (v['thumbnail'] as Map<String, dynamic>?)?['thumbnails'],
    );
    final viewCount = _parseViewCount(
      (v['viewCountText'] as Map<String, dynamic>?)?['simpleText'],
    );
    return InnerTubeVideoItem(
      videoId: videoId,
      title: title,
      channelName: channel,
      thumbnailUrl: thumbnail ?? '',
      durationSeconds: duration,
      viewCount: viewCount,
      isOfficial: _parseOfficialBadge(v['ownerBadges']),
      channelId: _parseChannelId(v['ownerText']),
      publishedDaysAgo: _parsePublishedDaysAgo(
        (v['publishedTimeText'] as Map<String, dynamic>?)?['simpleText'],
      ),
    );
  }

  /// Approximate days since upload from YouTube's relative text:
  /// "5 hours ago"→0, "3 days ago"→3, "2 weeks ago"→14, "1 month ago"→30,
  /// "3 years ago"→1095. Returns null when unparseable.
  static int? _parsePublishedDaysAgo(dynamic simpleText) {
    if (simpleText is! String || simpleText.isEmpty) return null;
    final lower = simpleText.toLowerCase();
    final num = int.tryParse(RegExp(r'\d+').firstMatch(lower)?.group(0) ?? '');
    if (num == null) return null;
    if (lower.contains('hour')) return 0;
    if (lower.contains('day')) return num;
    if (lower.contains('week')) return num * 7;
    if (lower.contains('month')) return num * 30;
    if (lower.contains('year')) return num * 365;
    return null;
  }

  /// Extracts the uploader channel id (`UC…`) from the owner runs'
  /// navigation endpoint — real metadata, never fabricated.
  static String? _parseChannelId(dynamic ownerText) {
    if (ownerText is! Map<String, dynamic>) return null;
    final runs = ownerText['runs'];
    if (runs is! List) return null;
    for (final run in runs) {
      if (run is! Map<String, dynamic>) continue;
      final nav = run['navigationEndpoint'];
      if (nav is! Map<String, dynamic>) continue;
      final browse = nav['browseEndpoint'];
      if (browse is Map<String, dynamic>) {
        final id = browse['browseId'];
        if (id is String && id.startsWith('UC')) return id;
      }
    }
    return null;
  }

  /// Detects YouTube's official/verified creator badge on a result so the
  /// app can prefer original artist uploads over fan/lyrics channels.
  static bool _parseOfficialBadge(dynamic ownerBadges) {
    if (ownerBadges is! List) return false;
    for (final badge in ownerBadges) {
      if (badge is! Map<String, dynamic>) continue;
      final renderer = badge['metadataBadgeRenderer'];
      if (renderer is! Map<String, dynamic>) continue;
      final style = (renderer['style'] as String?) ?? '';
      final upper = style.toUpperCase();
      if (upper.contains('OFFICIAL') || upper.contains('VERIFIED')) {
        return true;
      }
    }
    return false;
  }

  List<InnerTubeVideoItem> _collectLockupVideos(Map<String, dynamic> json) {
    final out = <InnerTubeVideoItem>[];
    _walk(json, (node) {
      final lockup = node['lockupViewModel'];
      if (lockup is Map<String, dynamic>) {
        final item = _parseLockup(lockup);
        if (item != null) out.add(item);
      }
    });
    return out;
  }

  InnerTubeVideoItem? _parseLockup(Map<String, dynamic> lockup) {
    final contentType = lockup['contentType'] as String?;
    if (contentType != 'LOCKUP_CONTENT_TYPE_VIDEO') return null;
    final videoId = lockup['contentId'] as String?;
    if (videoId == null || videoId.isEmpty) return null;
    final metadata = lockup['metadata'] as Map<String, dynamic>?;
    final lm = metadata?['lockupMetadataViewModel'] as Map<String, dynamic>?;
    final title =
        ((lm?['title'] as Map<String, dynamic>?)?['content'] as String?)
                ?.trim() ??
            '';
    if (title.isEmpty) return null;
    final channel = _firstMetadataPartText(lm?['metadata']);
    final image = lockup['contentImage'] as Map<String, dynamic>?;
    final sources =
        ((image?['thumbnailViewModel'] as Map<String, dynamic>?)?['image']
            as Map<String, dynamic>?)?['sources'] as List?;
    final thumbnail = _bestThumbnail(sources);
    return InnerTubeVideoItem(
      videoId: videoId,
      title: title,
      channelName: channel ?? '',
      thumbnailUrl: thumbnail ?? '',
      durationSeconds: 0,
    );
  }

  String? _firstMetadataPartText(dynamic metadata) {
    if (metadata is! Map<String, dynamic>) return null;
    final vm = metadata['contentMetadataViewModel'] as Map<String, dynamic>?;
    final rows = vm?['metadataRows'] ?? metadata['metadataRows'];
    if (rows is! List || rows.isEmpty) return null;
    final parts = (rows.first as Map<String, dynamic>?)?['metadataParts'];
    if (parts is! List || parts.isEmpty) return null;
    final first = parts.first;
    if (first is Map<String, dynamic>) {
      final text = first['text'];
      if (text is Map<String, dynamic>) {
        final content = text['content'];
        if (content is String) return content;
      }
    }
    return null;
  }

  String? _findContinuationToken(Map<String, dynamic> json) {
    String? token;
    _walk(json, (node) {
      if (token != null) return;
      final command = node['continuationCommand'];
      if (command is Map<String, dynamic>) {
        final t = command['token'];
        if (t is String && t.isNotEmpty) token = t;
      }
    });
    return token;
  }

  static String? _runsText(dynamic runsContainer) {
    if (runsContainer is! Map<String, dynamic>) return null;
    final runs = runsContainer['runs'];
    if (runs is! List || runs.isEmpty) return null;
    final buffer = StringBuffer();
    for (final run in runs) {
      if (run is Map<String, dynamic>) {
        final text = run['text'];
        if (text is String) buffer.write(text);
      }
    }
    final joined = buffer.toString();
    return joined.isEmpty ? null : joined;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static int _parseDuration(dynamic simpleText) {
    if (simpleText is! String || simpleText.isEmpty) return 0;
    final parts = simpleText.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return h * 3600 + m * 60 + s;
    }
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return m * 60 + s;
    }
    return int.tryParse(parts[0]) ?? 0;
  }

  static String? _bestThumbnail(dynamic thumbnails) {
    if (thumbnails is! List || thumbnails.isEmpty) return null;
    for (final thumb in thumbnails.reversed) {
      if (thumb is Map<String, dynamic>) {
        final url = thumb['url'];
        if (url is String && url.isNotEmpty) return url;
      }
    }
    return null;
  }

  static int _parseViewCount(dynamic simpleText) {
    if (simpleText is! String || simpleText.isEmpty) return 0;
    final cleaned = simpleText.replaceAll(',', '').trim();
    final digits = cleaned.replaceAll(RegExp(r'[^0-9.KM]'), '');
    if (digits.isEmpty) return 0;
    try {
      if (digits.contains('M')) {
        final v = double.tryParse(digits.replaceAll('M', '')) ?? 0;
        return (v * 1000000).round();
      }
      if (digits.contains('K')) {
        final v = double.tryParse(digits.replaceAll('K', '')) ?? 0;
        return (v * 1000).round();
      }
      return int.tryParse(digits) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
