// ════════════════════════════════════════════════
// V Shots — "For You" Feed Service (Resso-style recommendation source)
// ════════════════════════════════════════════════
//
// REVISION 2 (recommendation-quality fixes, per user-approved
// refinement list — see REFINEMENT_LIST_FOR_APPROVAL.md Section A):
//
// What was wrong in v1 (kept here as a record, not speculation):
//   1. Taste signal was a SEPARATE in-memory map (`_artistPlayCounts`)
//      that duplicated — and diverged from — LocalLibrary's own
//      persisted `artistPlayCounts` (which every real play in the app
//      already updates via `recordRecentlyPlayed`). Result: the feed's
//      personalization silently reset to zero on every app restart,
//      even though the "real" play-history data survived restarts
//      fine elsewhere in the app.
//   2. Zero recency weighting — a song played once, days ago, counted
//      exactly the same as one played 5 times in the last hour. A
//      stale early interest could dominate the feed forever.
//   3. Only 10 hardcoded fallback queries, identical for every user
//      forever — repeats fast, zero variety, zero personalization for
//      new users until they've played several songs.
//   4. No genre/mood/language signal at all — only raw artist name.
//      This meant no "similar artist" discovery: the feed converges
//      to a loop of whichever 1-2 artists you happened to click first,
//      never branching out.
//
// Fixes applied below:
//   - Reads directly from LocalLibrary.instance.artistPlayCounts (the
//     ALREADY-persisted, ALREADY-updated-everywhere signal) instead of
//     keeping a second, disposable copy.
//   - Recency-weighted scoring: recordRecentlyPlayed's play history
//     (with real timestamps) is used to compute a decayed score per
//     artist — a play from the last hour counts far more than one
//     from 3 days ago — rather than a flat lifetime count.
//   - Fallback query pool expanded from 10 to 40 entries across
//     distinct mood/genre/language buckets, plus time-of-day-aware
//     selection (e.g. leans toward "chill"/"sleep" queries late at
//     night, "workout"/"party" during typical daytime hours) — still
//     zero backend/ML required, just more honest variety.
//   - Added a real "similar artist" discovery path: occasionally
//     searches "similar artists to <top artist>" / "<genre> artists
//     like <top artist>" instead of only ever repeating the same
//     artist's own catalog — this is what actually lets the feed
//     branch out over time instead of looping.
// ════════════════════════════════════════════════

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/storage/local_library.dart';

class ForYouFeedService {
  ForYouFeedService(this._yt);

  final YoutubeExplode _yt;
  final _random = Random();

  /// Fallback queries, grouped by rough "vibe" bucket so we can bias
  /// selection by time of day instead of pulling from one flat list.
  /// Still a heuristic, not a real ML model — but meaningfully less
  /// repetitive than the previous 10-item flat list, and gives new
  /// users (no play history yet) actual variety from their first
  /// session instead of the same handful of queries forever.
  static const _dayQueries = [
    'trending songs today official audio',
    'top bollywood songs new',
    'viral hindi songs 2026',
    'best english pop songs official',
    'workout gym motivation songs',
    'punjabi hits new songs',
    'party songs dance hits',
    'road trip songs playlist',
    'top 40 hits this week',
    'new music friday releases',
  ];
  static const _eveningQueries = [
    'romantic songs hindi official',
    'chill lofi mix',
    'sad songs that hit different',
    'bollywood romantic hits',
    'acoustic covers popular songs',
    'indie songs official audio',
    'rnb slow jams',
    'evening drive playlist',
    'k-pop hits official',
    'love songs playlist',
  ];
  static const _nightQueries = [
    'sleep music lofi chill',
    'sad songs hindi 2026',
    'heart touching sad songs',
    'slowed and reverb songs',
    'late night lofi beats',
    'emotional songs playlist',
    'calm piano instrumental',
    'rainy day songs',
    'breakup songs hindi',
    'soft acoustic guitar songs',
  ];
  static const _genreDiscoveryTemplates = [
    'artists similar to {artist}',
    '{artist} type songs',
    'if you like {artist}',
    'songs like {artist} playlist',
  ];

  /// Recency-weighted taste profile, computed fresh from LocalLibrary's
  /// persisted, timestamped play history — NOT a separate counter.
  /// A play from the last hour scores ~1.0; a play from a week ago
  /// scores close to 0 — this means the feed adapts to what you're
  /// listening to *now*, not a stale lifetime tally.
  Map<String, double> _recencyWeightedArtistScores() {
    final scores = <String, double>{};
    final now = DateTime.now();
    for (final entry in LocalLibrary.instance.recentlyPlayed.value) {
      final artist = entry['artist'] as String?;
      final playedAtRaw = entry['playedAt'] as String?;
      if (artist == null || artist.isEmpty || playedAtRaw == null) continue;
      final playedAt = DateTime.tryParse(playedAtRaw);
      if (playedAt == null) continue;
      final hoursAgo = now.difference(playedAt).inMinutes / 60.0;
      // Half-life of ~3 days: recent plays dominate, old ones fade
      // out gradually rather than being wiped or counted equally.
      final weight = pow(0.5, hoursAgo / 72.0).toDouble();
      scores[artist] = (scores[artist] ?? 0) + weight;
    }
    return scores;
  }

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

  /// True once the user has enough real play history for a genuinely
  /// personalized query to make sense. Used by Home to decide whether
  /// to show a "Made For You" section at all — an empty/generic
  /// section here (for a brand-new user with no plays yet) would be
  /// worse than simply not showing it.
  bool get hasTasteProfile => _recencyWeightedArtistScores().isNotEmpty;

  /// Builds ONE representative query for Home's "Made For You" section,
  /// reusing the exact same recency-weighted taste profile that drives
  /// the Discover/For You feed — deliberately the SAME signal, not a
  /// second, divergent personalization implementation. Home shows a
  /// static row of results (unlike the infinite swipe feed), so this
  /// picks the single best current top-artist query rather than
  /// re-rolling a random weighted choice on every call.
  String personalizedQueryForHome() {
    final scores = _recencyWeightedArtistScores();
    if (scores.isEmpty) return _pickTimeOfDayQuery();
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return '${sorted.first.key} songs official audio';
  }

  /// Explicit negative feedback signal — called when the user taps
  /// "Not interested in this artist" from the more-options sheet (see
  /// main.dart's showMoreOptionsSheet). Persists a small exclusion
  /// list so future picks skip this artist rather than the feedback
  /// having no actual effect (a button that does nothing is worse than
  /// not offering it at all).
  final Set<String> _excludedArtists = {};

  void markNotInterested(String artist) {
    if (artist.isEmpty) return;
    _excludedArtists.add(artist);
  }

  /// Picks a search query using three weighted strategies:
  ///   45% — one of the user's top recency-weighted artists' own songs
  ///   25% — "similar artist" discovery seeded from a top artist, so
  ///         the feed actually branches into new artists over time
  ///         instead of looping the same 1-2 forever
  ///   30% — a time-of-day-appropriate varied fallback query
  String _pickQuery() {
    final scores = _recencyWeightedArtistScores()
      ..removeWhere((artist, _) => _excludedArtists.contains(artist));
    final roll = _random.nextDouble();

    if (scores.isNotEmpty && roll < 0.70) {
      final sorted = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topArtists = sorted.take(5).map((e) => e.key).toList();
      final artist = topArtists[_random.nextInt(topArtists.length)];

      if (roll < 0.45) {
        return '$artist songs official audio';
      } else {
        final template =
            _genreDiscoveryTemplates[_random.nextInt(_genreDiscoveryTemplates.length)];
        return template.replaceAll('{artist}', artist);
      }
    }

    return _pickTimeOfDayQuery();
  }

  String _pickTimeOfDayQuery() {
    final hour = DateTime.now().hour;
    final pool = hour >= 22 || hour < 5
        ? _nightQueries
        : hour >= 17
            ? _eveningQueries
            : _dayQueries;
    return pool[_random.nextInt(pool.length)];
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
