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

import 'package:flutter/foundation.dart' show debugPrint;

import '../preferences/user_preferences.dart';
import '../providers/adapters/youtube/youtube_data_api_client.dart';
import '../providers/adapters/youtube/youtube_repository.dart';
import 'configured_playlists.dart';

/// The official YouTube Music channel whose playlists feed Home/Discovery.
const String kYouTubeMusicChannelId = 'UC-9-kyTW8ZkZNDHQJ6FgpwQ';

/// Category shown for playlists that do not map to a known genre/mood bucket.
const String kUnknownPlaylistCategory = 'More From YouTube Music';

/// A discovered playlist plus its computed relevance to the user.
class ScoredPlaylist {
  const ScoredPlaylist({
    required this.playlist,
    required this.relevance,
    this.countryScore = 0,
    this.languageScore = 0,
    this.genreScore = 0,
    this.category = kUnknownPlaylistCategory,
  });

  final YouTubePlaylist playlist;
  final double relevance;
  final double countryScore;
  final double languageScore;
  final double genreScore;
  final String category;
}

/// Maps a playlist title to a display category. Unknown playlists keep
/// [kUnknownPlaylistCategory] so no real content is ever dropped.
String classifyPlaylistTitle(String title) {
  final t = title.toLowerCase();
  if (t.contains('trending') || t.contains('popular') || t.contains('top 50')) {
    return 'Trending';
  }
  if (t.contains('new release') ||
      t.contains('new music') ||
      t.contains('fresh')) {
    return 'New Releases';
  }
  if (t.contains('punjabi')) return 'Punjabi';
  if (t.contains('tamil')) return 'Tamil';
  if (t.contains('telugu')) return 'Telugu';
  if (t.contains('hindi') || t.contains('bollywood') || t.contains('i-pop')) {
    return 'Hindi';
  }
  if (t.contains('english') ||
      t.contains('global') ||
      t.contains('international') ||
      t.contains('pop')) {
    return 'English';
  }
  if (t.contains('hip hop') || t.contains('rap')) return 'Hip-Hop';
  if (t.contains('edm') || t.contains('dance') || t.contains('electronic')) {
    return 'EDM';
  }
  if (t.contains('romantic') || t.contains('love')) return 'Romantic';
  if (t.contains('chill') || t.contains('lofi') || t.contains('lo-fi')) {
    return 'Chill';
  }
  if (t.contains('devotional') ||
      t.contains('bhajan') ||
      t.contains('bhakti')) {
    return 'Devotional';
  }
  if (t.contains('workout') || t.contains('gym') || t.contains('hype')) {
    return 'Workout';
  }
  if (t.contains('party') || t.contains('celebration')) return 'Party';
  if (t.contains('sad') || t.contains('heartbroken')) return 'Sad';
  if (t.contains('indie') || t.contains('acoustic')) return 'Indie';
  return kUnknownPlaylistCategory;
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

  /// Discovers all playlists that feed Home/Discovery, sorted by title.
  ///
  /// Source priority (all real, none guessed):
  ///   1. channelSections.list on the YouTube Music channel → playlist refs
  ///      (the ONLY path that surfaces the channel's auto-generated playlists,
  ///      since playlists.list?channelId=... returns 0 for it).
  ///   2. playlists.list?channelId=... (paginated) as a fallback.
  ///   3. [kConfiguredPlaylists] — real, user-verified playlist ids.
  ///
  /// Returns empty only if the API is not live / every path fails.
  Future<List<YouTubePlaylist>> discoverPlaylists({
    int maxPages = 5,
  }) async {
    final unique = <YouTubePlaylist>[];
    final seen = <String>{};

    void addAll(List<YouTubePlaylist> list) {
      for (final p in list) {
        if (seen.add(p.id)) unique.add(p);
      }
    }

    // 1. Primary: channelSections → real playlist refs.
    if (isLive) {
      try {
        final sections =
            await _repo.listChannelSections(kYouTubeMusicChannelId);
        final refs = sections.expand((s) => s.playlistIds).toSet().toList();
        debugPrint('[PLAYLIST] channelSections: ${refs.length} playlist refs');
        if (refs.isNotEmpty) {
          addAll(await _repo.listPlaylistsByIds(refs));
        }
      } catch (e) {
        debugPrint('[PLAYLIST] channelSections error: $e');
      }
    }

    // 2. Fallback: playlists.list by channel (may be 0 for the Music channel).
    if (unique.isEmpty && isLive) {
      addAll(await _discoverViaChannelPlaylists(maxPages: maxPages));
    }

    // 3. Configured, user-verified real playlists.
    for (final c in kConfiguredPlaylists) {
      if (c.id.isEmpty) continue;
      final playlist = YouTubePlaylist(
        id: c.id,
        title: c.title,
        description: '',
        thumbnailUrl: '',
        itemCount: 0,
        channelId: kYouTubeMusicChannelId,
      );
      if (seen.add(c.id)) unique.add(playlist);
    }

    unique
        .sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return unique;
  }

  /// Paginated `playlists.list?channelId=...` (fallback discovery path).
  Future<List<YouTubePlaylist>> _discoverViaChannelPlaylists({
    int maxPages = 5,
  }) async {
    final all = <YouTubePlaylist>[];
    String? token;
    for (var i = 0; i < maxPages; i++) {
      final page = await _repo.listChannelPlaylists(
        kYouTubeMusicChannelId,
        maxResults: 50,
        pageToken: token,
      );
      all.addAll(page.playlists);
      token = page.nextPageToken;
      if (token == null) break;
    }
    final seen = <String>{};
    final unique = <YouTubePlaylist>[];
    for (final p in all) {
      if (seen.add(p.id)) unique.add(p);
    }
    debugPrint('[PLAYLIST] playlists.list: ${unique.length} playlists');
    return unique;
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
      category: classifyPlaylistTitle(playlist.title),
    );
  }

  /// Returns playlists for the user, sorted by relevance desc.
  ///
  /// Unlike a strict cutoff, this keeps EVERY discovered playlist so no real
  /// content is lost — unknown playlists are categorized as
  /// [kUnknownPlaylistCategory] and shown under "More From YouTube Music".
  Future<List<ScoredPlaylist>> relevantPlaylists(
    UserPreferences prefs, {
    int maxPages = 5,
  }) async {
    final playlists = await discoverPlaylists(maxPages: maxPages);
    final scored = playlists.map((p) => scorePlaylist(p, prefs)).toList()
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
