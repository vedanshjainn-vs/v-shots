// ════════════════════════════════════════════════
// V Shots — Home Content Service
// ════════════════════════════════════════════════
//
// Fetches and filters content for the Home feed.
// Separates content logic from UI.
// ════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../domain/models/home_models.dart';

/// Service that fetches content for the Home feed.
class HomeContentService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Fetch the complete home feed.
  Future<HomeFeed> fetchFeed() async {
    _log('Fetching home feed...');

    final sections = <HomeSection>[];

    // Fetch sections in parallel.
    final results = await Future.wait([
      _fetchTrending(),
      _fetchNewReleases(),
      _fetchTopIndia(),
      _fetchGlobalHits(),
      _fetchMoodPlaylists(),
      _fetchPopularArtists(),
    ]);

    for (final section in results) {
      if (section.items.isNotEmpty) {
        sections.add(section);
      }
    }

    _log('Home feed loaded: ${sections.length} sections');
    return HomeFeed(sections: sections, lastUpdated: DateTime.now());
  }

  /// Fetch trending music.
  Future<HomeSection> _fetchTrending() async {
    try {
      _log('Fetching trending...');
      final results = await _yt.search.search('trending music today official');
      final videos = results.whereType<Video>().take(15).toList();
      final items = videos
          .where((v) => _isMusicContent(v))
          .map(_videoToItem)
          .toList();
      _log('Trending: ${items.length} items');
      return HomeSection(
        type: HomeSectionType.trending,
        title: 'Trending Now',
        subtitle: "What's hot right now",
        items: items,
      );
    } catch (e) {
      _log('Trending failed: $e');
      return const HomeSection(type: HomeSectionType.trending, title: 'Trending Now');
    }
  }

  /// Fetch new releases.
  Future<HomeSection> _fetchNewReleases() async {
    try {
      _log('Fetching new releases...');
      final results = await _yt.search.search('new music releases 2024 official audio');
      final videos = results.whereType<Video>().take(10).toList();
      final items = videos
          .where((v) => _isMusicContent(v))
          .map(_videoToItem)
          .toList();
      _log('New releases: ${items.length} items');
      return HomeSection(
        type: HomeSectionType.newReleases,
        title: 'New Releases',
        subtitle: 'Fresh music just dropped',
        items: items,
      );
    } catch (e) {
      _log('New releases failed: $e');
      return const HomeSection(type: HomeSectionType.newReleases, title: 'New Releases');
    }
  }

  /// Fetch India top music.
  Future<HomeSection> _fetchTopIndia() async {
    try {
      _log('Fetching India top music...');
      final results = await _yt.search.search('Bollywood hits 2024 official');
      final videos = results.whereType<Video>().take(10).toList();
      final items = videos
          .where((v) => _isMusicContent(v))
          .map(_videoToItem)
          .toList();
      _log('India top: ${items.length} items');
      return HomeSection(
        type: HomeSectionType.topIndia,
        title: "India's Top Music",
        subtitle: 'Bollywood, Hindi & more',
        items: items,
      );
    } catch (e) {
      _log('India top failed: $e');
      return const HomeSection(type: HomeSectionType.topIndia, title: "India's Top Music");
    }
  }

  /// Fetch global hits.
  Future<HomeSection> _fetchGlobalHits() async {
    try {
      _log('Fetching global hits...');
      final results = await _yt.search.search('global top hits 2024 official music');
      final videos = results.whereType<Video>().take(10).toList();
      final items = videos
          .where((v) => _isMusicContent(v))
          .map(_videoToItem)
          .toList();
      _log('Global hits: ${items.length} items');
      return HomeSection(
        type: HomeSectionType.globalHits,
        title: 'Global Hits',
        subtitle: 'International chart-toppers',
        items: items,
      );
    } catch (e) {
      _log('Global hits failed: $e');
      return const HomeSection(type: HomeSectionType.globalHits, title: 'Global Hits');
    }
  }

  /// Fetch mood-based playlists.
  Future<HomeSection> _fetchMoodPlaylists() async {
    try {
      _log('Fetching mood playlists...');
      final results = await _yt.search.search('chill music playlist official');
      final videos = results.whereType<Video>().take(8).toList();
      final items = videos
          .where((v) => _isMusicContent(v))
          .map(_videoToItem)
          .toList();
      _log('Mood playlists: ${items.length} items');
      return HomeSection(
        type: HomeSectionType.mood,
        title: 'Mood & Activity',
        subtitle: 'Music for every moment',
        items: items,
      );
    } catch (e) {
      _log('Mood playlists failed: $e');
      return const HomeSection(type: HomeSectionType.mood, title: 'Mood & Activity');
    }
  }

  /// Fetch popular artists.
  Future<HomeSection> _fetchPopularArtists() async {
    try {
      _log('Fetching popular artists...');
      final results = await _yt.search.search('top music artists official channel');
      final videos = results.whereType<Video>().take(8).toList();
      final items = videos.map((v) => HomeItem(
        id: v.channelId.value,
        title: v.author,
        artwork: v.thumbnails.highResUrl.toString(),
        type: 'artist',
      )).toList();
      _log('Popular artists: ${items.length} items');
      return HomeSection(
        type: HomeSectionType.artists,
        title: 'Popular Artists',
        items: items,
      );
    } catch (e) {
      _log('Popular artists failed: $e');
      return const HomeSection(type: HomeSectionType.artists, title: 'Popular Artists');
    }
  }

  // ═══════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════

  /// Filter: Only music content (not compilations, podcasts, etc.)
  bool _isMusicContent(Video video) {
    final title = video.title.toLowerCase();
    final duration = video.duration?.inMinutes ?? 0;

    // Filter out non-music content.
    final nonMusicKeywords = [
      'podcast', 'episode', 'interview', 'tutorial',
      'review', 'reaction', 'compilation', 'mix 1 hour',
      'mix 2 hour', 'mix 3 hour', 'live stream',
    ];

    for (final keyword in nonMusicKeywords) {
      if (title.contains(keyword)) return false;
    }

    // Filter out very long videos (not songs).
    if (duration > 15) return false;

    // Filter out very short videos.
    if (duration < 1 && (video.duration?.inSeconds ?? 0) < 30) return false;

    return true;
  }

  /// Convert a YouTube video to a HomeItem.
  HomeItem _videoToItem(Video video) {
    return HomeItem(
      id: video.id.value,
      title: _cleanTitle(video.title, video.author),
      subtitle: video.author,
      artwork: video.thumbnails.highResUrl.toString(),
      durationSeconds: video.duration?.inSeconds ?? 0,
      type: 'track',
    );
  }

  /// Clean title by removing artist prefix and common suffixes.
  String _cleanTitle(String title, String artist) {
    var cleaned = title;
    if (cleaned.startsWith('$artist - ')) {
      cleaned = cleaned.substring(artist.length + 3);
    }
    cleaned = cleaned
        .replaceAll(RegExp(r'\s*\(Official.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Official.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Lyric.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Lyric.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Audio.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Audio.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Music Video.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Music Video.*?\]', caseSensitive: false), '')
        .trim();
    return cleaned.isEmpty ? title : cleaned;
  }

  void _log(String message) {
    debugPrint('[HomeContentService] $message');
  }

  void dispose() {
    _yt.close();
  }
}
