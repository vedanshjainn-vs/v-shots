// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — MusicDiscoveryService
//
// A single, reusable discovery service used by Home, Discovery and Search.
//
// DATA SOURCE (legal): the OFFICIAL YouTube Data API v3 `search` endpoint.
//   • No InnerTube, no unofficial/private YouTube Music endpoints.
//   • No playlistItems.list dependency for auto-generated playlists.
//   • No RDCLAK/OLAK/OLZy playlist ids.
//   • No scraping, no audio extraction.
//
// PLAYBACK: this service only returns metadata (videoId/title/artist/artwork).
// The UI hands those ids to the existing official YouTube IFrame player via
// the existing playTrack() pipeline. This file never plays audio itself.
//
// This service returns "shelves" (category-driven rows) for Home, and search
// results for Discovery/Search — all from the same official API client, so
// there is exactly ONE discovery implementation in the app.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

import '../preferences/user_preferences.dart';
import '../providers/adapters/youtube/youtube_data_api_client.dart';

/// A normalized music item (metadata only — no audio access).
class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.artwork,
    this.durationSeconds = 0,
    this.source = 'youtube_official',
  });

  final String id;
  final String title;
  final String artist;
  final String artwork;
  final int durationSeconds;
  final String source;

  /// Converts to the app's canonical track-map used by playTrack/global player.
  Map<String, dynamic> toTrackMap() => {
        'id': id,
        'videoId': id,
        'title': title,
        'artist': artist,
        'artwork': artwork,
        'duration': durationSeconds,
        'source': source,
      };

  static MusicTrack fromVideoItem(YouTubeVideoItem v) => MusicTrack(
        id: v.id,
        title: v.title,
        artist: v.channelTitle,
        artwork: v.thumbnailUrl,
        durationSeconds: v.durationSeconds,
      );
}

/// A titled row of music (a "shelf" on Home, or a category feed in Discovery).
class MusicShelf {
  const MusicShelf({required this.title, required this.tracks, this.query});

  final String title;
  final List<MusicTrack> tracks;
  final String? query;
}

/// One discovery category: label + emoji + official search query.
class MusicCategory {
  const MusicCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.query,
  });

  final String id;
  final String label;
  final String icon;
  final String query;
}

/// Default Discovery categories (offline fallback). Each maps to a distinct
/// official search query so selecting a category really changes the results.
const List<MusicCategory> kMusicCategories = [
  MusicCategory(
      id: 'trending',
      label: 'Trending',
      icon: '🔥',
      query: 'trending songs 2026 official audio'),
  MusicCategory(
      id: 'new',
      label: 'New Releases',
      icon: '🆕',
      query: 'new music releases official audio'),
  MusicCategory(
      id: 'bollywood',
      label: 'Bollywood',
      icon: '🎬',
      query: 'bollywood hindi hits official audio'),
  MusicCategory(
      id: 'punjabi',
      label: 'Punjabi',
      icon: '🥁',
      query: 'punjabi hits official audio'),
  MusicCategory(
      id: 'hindi',
      label: 'Hindi',
      icon: '🇮🇳',
      query: 'hindi songs official audio'),
  MusicCategory(
      id: 'english',
      label: 'English',
      icon: '🌎',
      query: 'english pop hits official audio'),
  MusicCategory(
      id: 'romantic',
      label: 'Romantic',
      icon: '💖',
      query: 'romantic love songs official audio'),
  MusicCategory(
      id: 'sad',
      label: 'Sad',
      icon: '🌧️',
      query: 'sad heartbreak songs official audio'),
  MusicCategory(
      id: 'party',
      label: 'Party',
      icon: '🎉',
      query: 'party dance songs official audio'),
  MusicCategory(
      id: 'chill',
      label: 'Chill',
      icon: '😌',
      query: 'chill lofi beats official audio'),
  MusicCategory(
      id: 'workout',
      label: 'Workout',
      icon: '💪',
      query: 'workout gym hype songs official audio'),
  MusicCategory(
      id: 'devotional',
      label: 'Devotional',
      icon: '🙏',
      query: 'devotional bhajan aarti official audio'),
];

/// Default Home shelves (offline fallback). Only populated from the live API.
const List<MusicCategory> kHomeShelves = [
  MusicCategory(
      id: 'trending',
      label: 'Trending',
      icon: '🔥',
      query: 'trending songs 2026 official audio'),
  MusicCategory(
      id: 'new',
      label: 'New Music',
      icon: '🆕',
      query: 'new music official audio'),
  MusicCategory(
      id: 'bollywood',
      label: 'Bollywood Hits',
      icon: '🎬',
      query: 'bollywood hindi hits official audio'),
  MusicCategory(
      id: 'punjabi',
      label: 'Punjabi Hits',
      icon: '🥁',
      query: 'punjabi hits official audio'),
  MusicCategory(
      id: 'english',
      label: 'English Pop',
      icon: '🌎',
      query: 'english pop hits official audio'),
  MusicCategory(
      id: 'romantic',
      label: 'Romantic',
      icon: '💖',
      query: 'romantic love songs official audio'),
  MusicCategory(
      id: 'chill',
      label: 'Chill & Lofi',
      icon: '😌',
      query: 'chill lofi beats official audio'),
];

class MusicDiscoveryService {
  MusicDiscoveryService({YouTubeDataApiClient? client})
      : _client = client ?? YouTubeDataApiClient();

  final YouTubeDataApiClient _client;

  bool get isLive => _client.apiKey.isNotEmpty;

  /// Fetches Home shelves. Each shelf comes from a distinct official search.
  /// Silently skips any shelf that returns no usable results — a failing
  /// category never breaks the Home page (STEP 9/11).
  Future<List<MusicShelf>> fetchHomeShelves({
    List<MusicCategory> categories = kHomeShelves,
    int perShelf = 10,
    Set<String> excludeIds = const {},
  }) async {
    final shelves = <MusicShelf>[];
    for (final cat in categories) {
      try {
        final tracks = await search(cat.query, count: perShelf);
        if (tracks.isEmpty) continue;
        shelves.add(MusicShelf(
          title: cat.label,
          tracks: _dedupe(tracks, excludeIds),
          query: cat.query,
        ));
      } catch (e) {
        debugPrint('[Discovery] shelf "${cat.label}" skipped: $e');
      }
    }
    return shelves.where((s) => s.tracks.isNotEmpty).toList();
  }

  /// Searches via the official YouTube Data API search endpoint.
  Future<List<MusicTrack>> search(
    String query, {
    int count = 20,
    Set<String> excludeIds = const {},
    String? regionCode,
    String? relevanceLanguage,
  }) async {
    if (query.trim().isEmpty) return const [];
    final page = await _client.searchMusicVideosPaginated(
      query,
      maxResults: count.clamp(1, 50),
      excludeIds: excludeIds,
      regionCode: regionCode,
      relevanceLanguage: relevanceLanguage,
      videoEmbeddable: true,
    );
    return page.items.map(MusicTrack.fromVideoItem).toList();
  }

  /// Dedup by video id; keeps first occurrence. If everything is excluded the
  /// shelf may become shorter, but we never empty a healthy source entirely
  /// unless every single item is already shown.
  List<MusicTrack> _dedupe(List<MusicTrack> items, Set<String> excludeIds) {
    final seen = <String>{};
    final out = <MusicTrack>[];
    for (final t in items) {
      if (excludeIds.contains(t.id)) continue;
      if (!seen.add(t.id)) continue;
      out.add(t);
    }
    return out;
  }

  /// Region/language code helpers from the user's preferences.
  String? regionCodeFor(UserPreferences prefs) {
    switch (prefs.country) {
      case 'India':
        return 'IN';
      case 'United States':
        return 'US';
      case 'United Kingdom':
        return 'GB';
      case 'Pakistan':
        return 'PK';
      case 'Bangladesh':
        return 'BD';
      case 'Nepal':
        return 'NP';
      default:
        return null;
    }
  }

  String? relevanceLanguageFor(UserPreferences prefs) {
    if (prefs.languages.isNotEmpty) {
      return _languageCode(prefs.languages.first);
    }
    return null;
  }

  String _languageCode(String lang) {
    switch (lang) {
      case 'Hindi':
        return 'hi';
      case 'Punjabi':
        return 'pa';
      case 'Tamil':
        return 'ta';
      case 'Telugu':
        return 'te';
      case 'Bengali':
        return 'bn';
      case 'Marathi':
        return 'mr';
      case 'English':
      default:
        return 'en';
    }
  }

  void dispose() => _client.dispose();
}
