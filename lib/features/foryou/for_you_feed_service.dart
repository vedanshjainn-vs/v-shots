// ═════════════════════════════════════════════════════════════════════════════
// V Shots — "For You" Feed Service (Expanded Vibes & Recommendation Pipeline)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/config/discovery_categories.dart';
import '../../core/providers/music_repository.dart';
import '../../core/providers/provider_bootstrap.dart';
import '../../core/recommendation/recommendation_service.dart';
import '../../core/storage/local_library.dart';

class ForYouFeedService {
  ForYouFeedService({
    MusicRepository? repository,
  }) : _repository = repository ?? buildMusicRepository();

  final MusicRepository _repository;
  final _random = Random();

  String? activeMood;
  String? activeMoodQuery;

  /// Tracks the live Data-API page token for the currently selected vibe so
  /// the Discover feed truly pages through results instead of restarting.
  String? _nextPageToken;
  String? _tokenQuery;

  void _resetPagination() {
    _nextPageToken = null;
    _tokenQuery = null;
  }

  void setMood(String? moodLabel, String? query) {
    activeMood = moodLabel;
    activeMoodQuery = query;
    _resetPagination();
    if (moodLabel != null && query != null) {
      RecommendationService.instance.setMood(moodLabel, query);
    }
  }

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
    {
      'id': 'devotional',
      'label': 'Devotional & Bhajans',
      'icon': '🙏',
      'query': 'top devotional bhajan aarti songs official audio',
    },
    {
      'id': 'sufi',
      'label': 'Sufi & Ghazals',
      'icon': '✨',
      'query': 'best sufi songs and soulful ghazals official audio',
    },
    {
      'id': 'nostalgia',
      'label': '90s Nostalgia',
      'icon': '📻',
      'query': '90s 2000s bollywood evergreen classic hit songs',
    },
    {
      'id': 'cardio',
      'label': 'Workout Cardio',
      'icon': '🏃',
      'query': 'high energy cardio running workout music mix',
    },
    {
      'id': 'ambient',
      'label': 'Sleep & Ambient',
      'icon': '🌌',
      'query': 'deep sleep ambient relaxation meditation music',
    },
    {
      'id': 'kids',
      'label': 'Kids & Family',
      'icon': '🎈',
      'query': 'nursery rhymes kids friendly happy music playlist',
    },
    {
      'id': 'marathi',
      'label': 'Marathi Hits',
      'icon': '🥁',
      'query': 'top marathi super hit songs official audio',
    },
    {
      'id': 'gujarati',
      'label': 'Gujarati Hits',
      'icon': '🪕',
      'query': 'gujarati garba and folk hit songs official',
    },
    {
      'id': 'tamil',
      'label': 'Tamil Hits',
      'icon': '🎻',
      'query': 'latest tamil super hit songs official audio',
    },
    {
      'id': 'telugu',
      'label': 'Telugu Hits',
      'icon': '🪘',
      'query': 'top telugu mass and melody hit songs official audio',
    },
    {
      'id': 'bengali',
      'label': 'Bengali Hits',
      'icon': '🎼',
      'query': 'top bengali modern and classic songs official audio',
    },
    {
      'id': 'wedding',
      'label': 'Wedding & Sangeet',
      'icon': '💍',
      'query': 'indian wedding sangeet dance celebration songs',
    },
    {
      'id': 'monsoon',
      'label': 'Monsoon Vibes',
      'icon': '☔',
      'query': 'rainy day monsoon vibes hindi romantic songs',
    },
    {
      'id': 'motivational',
      'label': 'Motivational',
      'icon': '🏆',
      'query': 'inspirational motivational victory songs hindi english',
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

  Map<String, double> _recencyWeightedArtistScores() {
    return RecommendationService.instance.getRecencyWeightedArtistScores();
  }

  Future<List<Map<String, dynamic>>> fetchNextBatch({
    required Set<String> excludeIds,
    int count = 10,
  }) async {
    final query = _pickQuery();
    // Reset page token when the vibe/query changed so we start from page 1.
    if (_tokenQuery != query) {
      _tokenQuery = query;
      _nextPageToken = null;
    }
    try {
      // Primary discovery via InnerTube with YouTube Data API fallback —
      // real pagination through the shared repository.
      final page = await _repository.searchPaginated(
        query,
        limit: count,
        excludeIds: excludeIds,
        pageToken: _nextPageToken,
      );
      _nextPageToken = page.nextPageToken;
      return page.tracks;
    } catch (e) {
      debugPrint('[ForYouFeedService] fetchNextBatch failed: $e');
      return [];
    }
  }

  /// Fetches a batch for a specific [DiscoveryCategory] using its own query.
  /// This is the single reactive path the Discovery feed calls whenever the
  /// active category changes. Live API pagination + category-specific fallback.
  Future<List<Map<String, dynamic>>> fetchForCategory(
    DiscoveryCategory category, {
    required Set<String> excludeIds,
    int count = 10,
  }) async {
    final query = category.query;
    // Reset pagination when the category changed so we start at page 1.
    if (_tokenQuery != query) {
      _tokenQuery = query;
      _nextPageToken = null;
    }
    try {
      final page = await _repository.searchPaginated(
        query,
        limit: count,
        excludeIds: excludeIds,
        pageToken: _nextPageToken,
      );
      _nextPageToken = page.nextPageToken;
      final tracks = page.tracks;
      // Section 2: record shown IDs so the same song isn't re-surfaced soon.
      for (final t in tracks) {
        final id = t['id'] as String?;
        if (id != null) LocalLibrary.instance.recordShownSong(id);
      }
      return tracks;
    } catch (e) {
      debugPrint('[ForYouFeedService] fetchForCategory failed: $e');
      return [];
    }
  }

  bool get hasTasteProfile => _recencyWeightedArtistScores().isNotEmpty;

  String personalizedQueryForHome() {
    return RecommendationService.instance.getPersonalizedHomeQuery();
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
