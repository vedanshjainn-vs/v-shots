// ════════════════════════════════════════════════
// V Shots — Lyrics Service (LRCLIB)
// ════════════════════════════════════════════════
//
// Real, free, legal lyrics source. LRCLIB (lrclib.net) is a genuinely
// open lyrics database/API — no API key required, no rate-limit tier
// gate for basic GET requests, and it explicitly returns both
// synchronized (time-tagged, karaoke-style) and plain lyrics.
//
// This is the same source Metrolist (a real, 11k+-star YouTube Music
// client referenced during this project's earlier research) uses as
// its primary lyrics provider — chosen deliberately over scraping
// Musixmatch's private endpoints, which would be exactly the kind of
// "unofficial/reverse-engineered API" this project has consistently
// avoided elsewhere.
//
// API: GET https://lrclib.net/api/get?track_name=X&artist_name=Y
//   Response: { syncedLyrics, plainLyrics, instrumental, ... }
//   404 if not found — a real, common, non-error outcome (not every
//   YouTube video is an official studio track with lyrics indexed).
// ════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One parsed line of synced lyrics: [timestamp] this line starts at,
/// and the [text] to show.
@immutable
class LyricLine {
  const LyricLine(this.timestamp, this.text);
  final Duration timestamp;
  final String text;
}

@immutable
class LyricsResult {
  const LyricsResult({
    this.plainText,
    this.syncedLines,
    this.instrumental = false,
  });

  final String? plainText;
  final List<LyricLine>? syncedLines;
  final bool instrumental;

  bool get hasSynced => syncedLines != null && syncedLines!.isNotEmpty;
  bool get hasAny => plainText != null || hasSynced || instrumental;

  static const notFound = LyricsResult();
}

class LyricsService {
  LyricsService._();
  static final LyricsService instance = LyricsService._();

  static const _baseUrl = 'https://lrclib.net/api/get';

  final _cache = <String, LyricsResult>{};

  Future<LyricsResult> fetch({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  }) async {
    final cacheKey = '$trackName|$artistName';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'track_name': trackName,
        'artist_name': artistName,
        if (durationSeconds != null) 'duration': '$durationSeconds',
      });

      final response = await http.get(uri, headers: {
        // LRCLIB asks integrators to identify themselves via
        // User-Agent — good API citizenship, not required for
        // basic functionality but costs nothing to include.
        'User-Agent': 'VShots/1.0 (github.com/vedanshjainn-vs/v-shots)',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        _cache[cacheKey] = LyricsResult.notFound;
        return LyricsResult.notFound;
      }
      if (response.statusCode != 200) {
        debugPrint('[LyricsService] Unexpected status ${response.statusCode}');
        return LyricsResult.notFound;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final instrumental = data['instrumental'] as bool? ?? false;
      final plain = data['plainLyrics'] as String?;
      final syncedRaw = data['syncedLyrics'] as String?;

      final result = LyricsResult(
        plainText: (plain != null && plain.isNotEmpty) ? plain : null,
        syncedLines: syncedRaw != null ? _parseLrc(syncedRaw) : null,
        instrumental: instrumental,
      );
      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      debugPrint('[LyricsService] fetch failed: $e');
      return LyricsResult.notFound;
    }
  }

  /// Parses standard LRC-format synced lyrics: lines like
  /// `[01:23.45]Some lyric text`.
  List<LyricLine> _parseLrc(String raw) {
    final lineRegex = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$');
    final lines = <LyricLine>[];
    for (final rawLine in raw.split('\n')) {
      final match = lineRegex.firstMatch(rawLine.trim());
      if (match == null) continue;
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = match.group(3)!;
      final millis =
          fraction.length == 2 ? int.parse(fraction) * 10 : int.parse(fraction);
      final text = match.group(4)!.trim();
      lines.add(LyricLine(
        Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
        text,
      ));
    }
    return lines;
  }
}
