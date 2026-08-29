// ═════════════════════════════════════════════════════════════════════════════
// V Shots — RecommendationService (Location, Mood & Preference Blending)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:math';

import '../backend/supabase_service.dart';
import '../storage/local_library.dart';

class UserContext {
  UserContext({
    this.selectedMood,
    this.selectedMoodQuery,
    this.locationRegion,
    this.preferredLanguages = const ['Hindi', 'Punjabi', 'English'],
  });

  String? selectedMood;
  String? selectedMoodQuery;
  String? locationRegion;
  List<String> preferredLanguages;

  Map<String, dynamic> toJson() => {
        'selected_mood': selectedMood,
        'selected_mood_query': selectedMoodQuery,
        'location_region': locationRegion,
        'preferred_languages': preferredLanguages,
      };
}

class RecommendationService {
  RecommendationService._();
  static final RecommendationService instance = RecommendationService._();

  final UserContext _context = UserContext();

  UserContext get context => _context;

  void setMood(String moodLabel, String moodQuery) {
    _context.selectedMood = moodLabel;
    _context.selectedMoodQuery = moodQuery;
    _syncToSupabase();
  }

  void setLocationRegion(String region) {
    _context.locationRegion = region;
    _syncToSupabase();
  }

  void setPreferredLanguages(List<String> languages) {
    _context.preferredLanguages = languages;
    _syncToSupabase();
  }

  Future<void> _syncToSupabase() async {
    final user = SupabaseService.currentUser;
    if (user == null || !SupabaseService.isAvailable) return;
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'user_context': _context.toJson()}).eq('id', user.id);
    } catch (_) {
      // Non-fatal, local fallback is preserved
    }
  }

  /// Calculates recency-weighted artist scores from recently played signals.
  Map<String, double> getRecencyWeightedArtistScores() {
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

  /// Generates a personalized query for Home "Made For You".
  String getPersonalizedHomeQuery() {
    final scores = getRecencyWeightedArtistScores();
    if (scores.isNotEmpty) {
      final sorted = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topArtist = sorted.first.key;
      return '$topArtist top hit songs official audio';
    }

    if (_context.selectedMoodQuery != null &&
        _context.selectedMoodQuery!.isNotEmpty) {
      return _context.selectedMoodQuery!;
    }

    if (_context.locationRegion != null) {
      final region = _context.locationRegion!.toLowerCase();
      if (region.contains('punjab')) {
        return 'latest punjabi pop hits official audio';
      }
      if (region.contains('maharashtra') || region.contains('mumbai')) {
        return 'top bollywood hindi and marathi songs';
      }
      if (region.contains('tamil')) {
        return 'latest tamil super hit songs official audio';
      }
      if (region.contains('telangana') || region.contains('andhra')) {
        return 'top telugu hit songs official audio';
      }
    }

    return 'trending hits top songs official audio';
  }

  /// Generates a query for "Because You Listened To" section.
  String getBecauseYouListenedQuery() {
    final scores = getRecencyWeightedArtistScores();
    if (scores.length >= 2) {
      final sorted = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final secondArtist = sorted[1].key;
      return '$secondArtist hit songs official audio';
    } else if (scores.isNotEmpty) {
      return 'similar songs to ${scores.keys.first} official audio';
    }
    return 'new official music releases 2026';
  }
}
