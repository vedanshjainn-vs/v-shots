// ════════════════════════════════════════════════
// V Shots — "For You" Feed Service (Resso-style recommendation source)
// ════════════════════════════════════════════════
//
// Feeds the vertical swipe "For You" screen (for_you_feed_screen.dart)
// with an endless, personalized-ish stream of tracks.
//
// DESIGN (matches MASTER_BUILD_PROMPT.md's "recommendation engine"
// section, which was already planned but never implemented): rather
// than a real ML recommender (which needs a backend, training data,
// and infrastructure this app doesn't have yet), this builds a simple,
// real, working signal from data the app ALREADY has:
//   1. A frequency-weighted "taste profile" from the artists the user
//      has actually played most recently (main.dart's global
//      `currentQueue`/play history — see _recentArtists below).
//   2. Biases future search queries toward those artists/genres,
//      falling back to generic trending/mood queries when there's no
//      history yet (new user / fresh install).
// This is the same class of trick real small-scale apps (and this
// app's own HomeContentService) already use — zero backend required,
// reuses the existing youtube_explode_dart search path.
// ════════════════════════════════════════════════

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ForYouFeedService {
  ForYouFeedService(this._yt);

  final YoutubeExplode _yt;
  final _random = Random();

  /// Simple in-memory taste signal: artist name -> play count. Populated
  /// by main.dart calling [recordPlay] whenever a track actually starts
  /// playing (wired in playTrack()). Not persisted across app restarts
  /// — a real Tier-2 upgrade (per MASTER_BUILD_PROMPT.md) would move
  /// this to Hive/local storage or the already-provisioned
  /// `play_history` Supabase table (see supabase_setup.sql).
  final Map<String, int> _artistPlayCounts = {};

  void recordPlay(String artist) {
    if (artist.isEmpty) return;
    _artistPlayCounts[artist] = (_artistPlayCounts[artist] ?? 0) + 1;
  }

  /// Generic fallback queries used when there's no play history yet, or
  /// to keep the feed varied even once there is (mixed in, not the only
  /// source, so the feed doesn't become a narrow loop of one artist).
  static const _fallbackQueries = [
    'trending songs today official audio',
    'viral hindi songs 2026',
    'best english pop songs official',
    'top bollywood songs new',
    'chill lofi mix',
    'romantic songs hindi official',
    'party songs dance hits',
    'sad songs that hit different',
    'workout gym motivation songs',
    'punjabi hits new songs',
  ];

  /// Returns the next batch of tracks for the feed. [excludeIds] is the
  /// set of video IDs already shown in this session, so the same track
  /// doesn't repeat as the user keeps swiping.
  Future<List<Map<String, dynamic>>> fetchNextBatch({
    required Set<String> excludeIds,
    int count = 10,
  }) async {
    final query = _pickQuery();
    try {
      final results = await _yt.search.search(query);
      final videos = results.whereType<Video>().where((v) {
        final title = v.title.toLowerCase();
        final duration = v.duration?.inMinutes ?? 0;
        if (duration > 12 || duration < 1) return false;
        const nonMusic = ['podcast', 'interview', 'reaction', 'tutorial', 'compilation'];
        if (nonMusic.any(title.contains)) return false;
        return !excludeIds.contains(v.id.value);
      }).take(count);

      return videos
          .map((v) => {
                'id': v.id.value,
                'title': _cleanTitle(v.title, v.author),
                'artist': v.author,
                'artwork': v.thumbnails.highResUrl.toString(),
                'duration': v.duration?.inSeconds ?? 0,
              })
          .toList();
    } catch (e) {
      debugPrint('[ForYouFeedService] fetchNextBatch failed: $e');
      return [];
    }
  }

  /// Picks a search query — 60% weighted toward the user's top-played
  /// artists (if any exist), 40% a varied fallback, so the feed feels
  /// personalized without becoming a repetitive single-artist loop.
  String _pickQuery() {
    if (_artistPlayCounts.isNotEmpty && _random.nextDouble() < 0.6) {
      final sorted = _artistPlayCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topArtists = sorted.take(5).map((e) => e.key).toList();
      final artist = topArtists[_random.nextInt(topArtists.length)];
      return '$artist songs official audio';
    }
    return _fallbackQueries[_random.nextInt(_fallbackQueries.length)];
  }

  String _cleanTitle(String title, String artist) {
    var c = title;
    if (c.startsWith('$artist - ')) c = c.substring(artist.length + 3);
    c = c
        .replaceAll(RegExp(r'\s*\(Official.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Official.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Lyric.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Lyric.*?\]', caseSensitive: false), '')
        .trim();
    return c.isEmpty ? title : c;
  }
}
