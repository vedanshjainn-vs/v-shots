// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — PlaylistContentService
//
// The PRIMARY live content source for Home. Discovers the official YouTube
// Music channel's playlists dynamically (no hardcoded playlist IDs), scores
// each playlist's relevance to the user's country + language + genres/moods,
// and returns playlist items as Track maps. Uses the official YouTube Data API
// (playlists.list / playlistItems.list) with real pagination.
//
// No mocking, no scraping, no hardcoded songs.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import '../preferences/user_preferences.dart';
import '../providers/adapters/youtube/youtube_data_api_client.dart';
import '../providers/adapters/youtube/youtube_repository.dart';

/// The official YouTube Music channel whose playlists feed Home/Discovery.
const String kYouTubeMusicChannelId = 'UC-9-kyTW8ZkZNDHQJ6FgpwQ';

/// A discovered playlist plus its computed relevance to the user.
class ScoredPlaylist {
  const ScoredPlaylist({
    required this.playlist,
    required this.relevance,
    this.countryScore = 0,
    this.languageScore = 0,
    this.genreScore = 0,
  });

  final YouTubePlaylist playlist;
  final double relevance;
  final double countryScore;
  final double languageScore;
  final double genreScore;
}

/// Country -> language keywords that appear in playlist titles.
const Map<String, List<String>> _countryTerms = {
  'India': ['india', 'hindi', 'bollywood', 'punjabi', 'haryanvi', 'bhojpuri'],
  'United States': ['usa', 'us ', 'global', 'english', 'international'],
  'United Kingdom': ['uk', 'uk ', 'global', 'english'],
  'Pakistan': ['pakistan', 'urdu', 'punjabi'],
  'Bangladesh': ['bangladesh', 'bengali'],
  'Nepal': ['nepal', 'nepali'],
  'UAE': ['arabic', 'international'],
  'Saudi Arabia': ['arabic', 'international'],
};

/// Language -> title keyword signals.
const Map<String, List<String>> _langTerms = {
  'Hindi': ['hindi', 'bollywood', 'i-pop'],
  'Punjabi': ['punjabi', 'bhangra'],
  'English': ['english', 'global', 'international'],
  'Tamil': ['tamil'],
  'Telugu': ['telugu'],
  'Bengali': ['bengali'],
  'Marathi': ['marathi'],
  'Haryanvi': ['haryanvi'],
  'Urdu': ['urdu'],
};

class PlaylistContentService {
  PlaylistContentService({YouTubeRepository? repository})
      : _repo = repository ?? YouTubeRepository();

  final YouTubeRepository _repo;

  /// Whether a live API key is available (playlists require the real API).
  bool get isLive => _repo.isLive;

  /// Discovers playlists from the YouTube Music channel.
  ///
  /// Primary: channelSections.list (auto-generated Music playlists that
  /// playlists.list often hides). Fallback: playlists.list (paginated).
  /// Never guesses playlist IDs. Returns [] if not live / API error.
  Future<List<YouTubePlaylist>> discoverPlaylists({
    int maxPages = 5,
  }) async {
    if (!isLive) return const [];
    final all = <YouTubePlaylist>[];
    final seen = <String>{};

    // 1) channelSections.list → playlist IDs + section titles.
    final sections = await _repo.listChannelSections(kYouTubeMusicChannelId);
    if (sections.playlistIds.isNotEmpty) {
      for (var i = 0; i < sections.playlistIds.length; i++) {
        final pid = sections.playlistIds[i];
        if (pid.isEmpty || !seen.add(pid)) continue;
        final title =
            i < sections.titles.length ? sections.titles[i] : 'Playlist';
        all.add(
          YouTubePlaylist(
            id: pid,
            title: title.isEmpty ? 'Playlist' : title,
            description: '',
            thumbnailUrl: '',
            itemCount: 0,
            channelId: kYouTubeMusicChannelId,
          ),
        );
      }
      if (kDebugMode) {
        debugPrint(
          '[PLAYLIST] channelSections: ${sections.playlistIds.length} playlist refs'
          ' (err=${sections.error})',
        );
      }
      if (all.isNotEmpty) {
        all.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        return all;
      }
    }

    // 2) Fallback: playlists.list paginated.
    String? token;
    for (var i = 0; i < maxPages; i++) {
      final page = await _repo.listChannelPlaylists(
        kYouTubeMusicChannelId,
        maxResults: 50,
        pageToken: token,
      );
      for (final p in page.playlists) {
        if (seen.add(p.id)) all.add(p);
      }
      token = page.nextPageToken;
      if (token == null) break;
    }
    all.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    if (kDebugMode) {
      debugPrint('[PLAYLIST] playlists.list: ${all.length} playlists');
    }
    return all;
  }

  /// Scores a playlist's relevance to the user (deterministic).
  ScoredPlaylist scorePlaylist(
    YouTubePlaylist playlist,
    UserPreferences prefs,
  ) {
    final title = '${playlist.title} ${playlist.description}'.toLowerCase();
    final countryTerms = _countryTerms[prefs.country] ?? const [];
    final langs = prefs.languages.isNotEmpty
        ? prefs.languages
        : const <String>['English'];

    // Country score: how many of the user's country terms appear.
    final countryHits = countryTerms.where(title.contains).length.toDouble();
    final countryScore =
        countryHits > 0 ? (0.5 + countryHits * 0.15).clamp(0.0, 1.0) : 0.2;

    // Language score: strongest match among preferred languages.
    var languageScore = 0.0;
    for (final lang in langs) {
      final terms = _langTerms[lang] ?? [];
      if (terms.isEmpty) continue;
      final hits = terms.where(title.contains).length;
      if (hits > 0) {
        final s = (0.5 + hits * 0.2).clamp(0.0, 1.0);
        if (s > languageScore) languageScore = s;
      }
    }
    if (languageScore == 0) languageScore = 0.25;

    // Genre/mood score from the user's selected genres appearing in the title.
    var genreScore = 0.0;
    for (final g in prefs.genres) {
      if (g.isNotEmpty && title.contains(g.toLowerCase())) {
        genreScore = (genreScore + 0.3).clamp(0.0, 1.0);
      }
    }

    final relevance =
        (countryScore * 0.4 + languageScore * 0.4 + genreScore * 0.2)
            .clamp(0.0, 1.0);
    return ScoredPlaylist(
      playlist: playlist,
      relevance: relevance,
      countryScore: countryScore,
      languageScore: languageScore,
      genreScore: genreScore,
    );
  }

  /// Returns playlists relevant to the user, sorted by relevance desc.
  Future<List<ScoredPlaylist>> relevantPlaylists(
    UserPreferences prefs, {
    int maxPages = 5,
  }) async {
    final playlists = await discoverPlaylists(maxPages: maxPages);
    final scored = playlists
        .map((p) => scorePlaylist(p, prefs))
        .where((s) => s.relevance >= 0.4) // only reasonably relevant
        .toList()
      ..sort((a, b) => b.relevance.compareTo(a.relevance));
    return scored;
  }

  /// Fetches items from a playlist, paginated, converting to Track maps.
  Future<List<Map<String, dynamic>>> playlistItems(
    String playlistId, {
    int maxResults = 50,
  }) async {
    if (!isLive || playlistId.isEmpty) return const [];
    final all = <YouTubePlaylistItem>[];
    String? token;
    for (var i = 0; i < 4; i++) {
      final page = await _repo.listPlaylistItems(
        playlistId,
        maxResults: maxResults,
        pageToken: token,
      );
      all.addAll(page.items);
      token = page.nextPageToken;
      if (token == null) break;
    }
    return all.map(_toTrack).toList();
  }

  Map<String, dynamic> _toTrack(YouTubePlaylistItem item) => {
        'id': item.videoId,
        'title': item.title,
        'artist': item.channelTitle,
        'artwork': item.thumbnailUrl,
        'duration': 0, // filled by video-details layer when needed
        'publishedAt': item.publishedAt?.toIso8601String(),
        'playlistPosition': item.position,
      };
}
