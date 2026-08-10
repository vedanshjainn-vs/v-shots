// ════════════════════════════════════════════════
// V Shots — "For You" Feed Service (Music Recommendation Source)
// ════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/providers/music_repository.dart';
import '../../core/storage/local_library.dart';

class ForYouFeedService {
  ForYouFeedService(this._repository);

  final MusicRepository _repository;
  final _random = Random();

  String? activeMood;
  String? activeMoodQuery;

  static const List<Map<String, String>> availableMoods = [
    {
      'id': 'trending',
      'label': 'Trending Hits',
      'icon': '🌟',
      'query': 'viral trending songs today official audio',
    },
    {
      'id': 'latenight',
      'label': 'Late Night Chill',
      'icon': '🌙',
      'query': 'late night lofi chill songs official audio',
    },
    {
      'id': 'romantic',
      'label': 'Romantic & Love',
      'icon': '💖',
      'query': 'romantic love songs official audio hindi punjabi',
    },
    {
      'id': 'party',
      'label': 'Party & Dance',
      'icon': '🔥',
      'query': 'party dance edm club songs official audio',
    },
    {
      'id': 'workout',
      'label': 'Gym & Hype',
      'icon': '⚡',
      'query': 'workout gym motivation hype songs official',
    },
    {
      'id': 'sad',
      'label': 'Heartbroken & Sad',
      'icon': '🌧️',
      'query': 'sad heartbroken emotional songs official audio',
    },
    {
      'id': 'focus',
      'label': 'Focus & Study',
      'icon': '🧘',
      'query': 'lofi study focus chill beats instrumental',
    },
    {
      'id': 'roadtrip',
      'label': 'Road Trip Drive',
      'icon': '🚗',
      'query': 'road trip travel drive songs playlist',
    },
    {
      'id': 'bollywood',
      'label': 'Bollywood Hits',
      'icon': '🎬',
      'query': 'top bollywood songs official music video',
    },
    {
      'id': 'punjabi',
      'label': 'Punjabi Bangers',
      'icon': '🎸',
      'query': 'latest punjabi pop hits official audio',
    },
    {
      'id': 'indie',
      'label': 'Hindi Indie',
      'icon': '🎧',
      'query': 'hindi indie acoustic songs official audio',
    },
    {
      'id': 'global',
      'label': 'Global Pop 100',
      'icon': '🌍',
      'query': 'billboard top global pop hits official audio',
    },
  ];

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

  void setMood(String? moodLabel, String? query) {
    activeMood = moodLabel;
    activeMoodQuery = query;
  }

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
      final weight = pow(0.5, hoursAgo / 72.0).toDouble();
      scores[artist] = (scores[artist] ?? 0) + weight;
    }
    return scores;
  }

  Future<List<Map<String, dynamic>>> fetchNextBatch({
    required Set<String> excludeIds,
    int count = 10,
  }) async {
    final query = _pickQuery();
    try {
      final detailed = await _repository.searchDetailed(
        query,
        limit: count,
        maxDurationMinutes: 12,
        minDurationMinutes: 1,
        excludeIds: excludeIds,
      );
      if (!detailed.success) {
        debugPrint(
          '[ForYouFeedService] fetchNextBatch failed: ${detailed.error}',
        );
        return [];
      }
      return detailed.tracks;
    } catch (e) {
      debugPrint('[ForYouFeedService] fetchNextBatch failed: $e');
      return [];
    }
  }

  bool get hasTasteProfile => _recencyWeightedArtistScores().isNotEmpty;

  String personalizedQueryForHome() {
    final scores = _recencyWeightedArtistScores();
    if (scores.isEmpty) return _pickTimeOfDayQuery();
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return '${sorted.first.key} songs official audio';
  }

  final Set<String> _excludedArtists = {};

  void markNotInterested(String artist) {
    if (artist.isEmpty) return;
    _excludedArtists.add(artist);
  }

  String _pickQuery() {
    if (activeMoodQuery != null && activeMoodQuery!.isNotEmpty) {
      final scores = _recencyWeightedArtistScores()
        ..removeWhere((artist, _) => _excludedArtists.contains(artist));
      if (scores.isNotEmpty && _random.nextDouble() < 0.40) {
        final sorted = scores.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topArtist = sorted.first.key;
        return '$topArtist $activeMoodQuery';
      }
      return activeMoodQuery!;
    }

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
        final template = _genreDiscoveryTemplates[_random.nextInt(
          _genreDiscoveryTemplates.length,
        )];
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
}
