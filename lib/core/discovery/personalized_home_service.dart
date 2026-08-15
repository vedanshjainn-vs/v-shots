// V SHOTS — Personalized Home recommendation composer
//
// The Home surface is intentionally shelf-based like ArchiveTune: local
// listening signals decide the personalized shelves, while InnerTube supplies
// fresh real music candidates. Playback is never handled here.

import 'package:flutter/foundation.dart';

import '../storage/local_library.dart';
import 'innertube_music_service.dart';

class HomeShelf {
  const HomeShelf({
    required this.title,
    required this.tracks,
    this.emoji = '',
  });

  final String title;
  final List<DiscoveryTrack> tracks;
  final String emoji;
}

class PersonalizedHomeService {
  PersonalizedHomeService({required this.discovery});

  final InnerTubeMusicService discovery;

  Future<List<HomeShelf>> buildHome() async {
    final lib = LocalLibrary.instance;
    final recent = lib.recentlyPlayed.value;
    final liked = lib.likedSongs.value;
    final shown = lib.recentlyShownIds;
    final shelves = <HomeShelf>[];

    // 1. Personal shelves always win over generic editorial shelves.
    final quick = await _quickPicks(recent, liked, shown);
    if (quick.isNotEmpty) {
      shelves.add(HomeShelf(title: 'Quick Picks', emoji: '⚡', tracks: quick));
    }

    final continueListening = _localTracks(recent.take(12));
    if (continueListening.isNotEmpty) {
      shelves.add(HomeShelf(
        title: 'Continue Listening',
        emoji: '▶',
        tracks: continueListening,
      ));
    }

    final becauseLiked = await _becauseYouLiked(liked, recent, shown);
    if (becauseLiked.isNotEmpty) {
      shelves.add(HomeShelf(
        title: 'Because You Liked It',
        emoji: '♥',
        tracks: becauseLiked,
      ));
    }

    final similarTaste = await _similarTaste(recent, liked, shown);
    if (similarTaste.isNotEmpty) {
      shelves.add(HomeShelf(
        title: 'More Like Your Taste',
        emoji: '✦',
        tracks: similarTaste,
      ));
    }

    // 2. Editorial shelves are deliberately limited and fetched concurrently.
    // This keeps Home responsive and prevents one failed query from blocking
    // every other shelf.
    const editorial = <Map<String, String>>[
      {'title': 'New Releases', 'query': 'new hindi songs 2026 latest releases'},
      {'title': "India's Biggest Hits", 'query': 'india top songs trending 2026'},
      {'title': 'Bollywood Hits', 'query': 'bollywood latest hits 2026'},
      {'title': 'Punjabi Wave', 'query': 'punjabi latest hits 2026'},
      {'title': 'English Hits', 'query': 'english pop hits 2026'},
      {'title': 'Romantic', 'query': 'romantic love songs hindi 2026'},
      {'title': 'Chill & Lo-fi', 'query': 'chill lofi songs 2026'},
      {'title': 'Workout', 'query': 'workout gym songs 2026'},
      {'title': 'Nostalgia', 'query': '90s bollywood nostalgia songs'},
    ];

    final editorialResults = await Future.wait(
      editorial.map((cfg) async {
        try {
          final tracks = await discovery.search(cfg['query']!, count: 14);
          return HomeShelf(
            title: cfg['title']!,
            emoji: _emoji(cfg['title']!),
            tracks: _fresh(tracks, shown).take(12).toList(),
          );
        } catch (e) {
          debugPrint('[Home] shelf ${cfg['title']} failed: $e');
          return const HomeShelf(title: '', tracks: []);
        }
      }),
      eagerError: false,
    );

    for (final shelf in editorialResults) {
      if (shelf.title.isNotEmpty && shelf.tracks.isNotEmpty) shelves.add(shelf);
    }

    // 3. On a mature library, finish with a rediscovery shelf. This prevents
    // the Home from becoming only a generic YouTube search feed.
    final rediscover = _rediscoverFavorites(liked, recent);
    if (rediscover.isNotEmpty) {
      shelves.add(HomeShelf(
        title: 'Rediscover Your Favorites',
        emoji: '↻',
        tracks: rediscover,
      ));
    }

    return shelves;
  }

  Future<List<DiscoveryTrack>> _quickPicks(
    List<Map<String, dynamic>> recent,
    List<Map<String, dynamic>> liked,
    Set<String> shown,
  ) async {
    final queries = <String>[];
    final lib = LocalLibrary.instance;

    // Strongest signal: artists the user repeatedly plays.
    final topArtists = lib.artistPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final artist in topArtists.take(3)) {
      if (artist.key.trim().isNotEmpty) queries.add('${artist.key} songs');
    }

    // Second signal: the most recent artists/songs.
    for (final track in recent.take(3)) {
      final artist = (track['artist'] as String?)?.trim() ?? '';
      final title = (track['title'] as String?)?.trim() ?? '';
      final q = artist.isNotEmpty ? '${artist} songs' : title;
      if (q.isNotEmpty && !queries.contains(q)) queries.add(q);
    }

    // Fresh install: use a real editorial fallback, never a fake item.
    if (queries.isEmpty) queries.add('trending songs india 2026');

    final batches = await Future.wait(
      queries.take(5).map((q) => discovery.search(q, count: 8)),
      eagerError: false,
    );
    final result = <DiscoveryTrack>[];
    final seen = <String>{};
    for (final batch in batches) {
      for (final track in batch) {
        if (!seen.add(track.id)) continue;
        if (shown.contains(track.id)) continue;
        if (track.id.isEmpty) continue;
        result.add(track);
        if (result.length >= 15) return result;
      }
    }

    // If freshness filtering was too aggressive, still return personalized
    // candidates rather than leaving Quick Picks empty.
    if (result.isEmpty) {
      for (final batch in batches) {
        for (final track in batch) {
          if (seen.add('fallback:${track.id}')) result.add(track);
          if (result.length >= 15) return result;
        }
      }
    }
    return result;
  }

  Future<List<DiscoveryTrack>> _becauseYouLiked(
    List<Map<String, dynamic>> liked,
    List<Map<String, dynamic>> recent,
    Set<String> shown,
  ) async {
    final seeds = liked.isNotEmpty ? liked.take(2).toList() : recent.take(2).toList();
    if (seeds.isEmpty) return const [];

    final result = <DiscoveryTrack>[];
    final seen = <String>{};
    for (final seed in seeds) {
      final artist = (seed['artist'] as String?)?.trim() ?? '';
      final title = (seed['title'] as String?)?.trim() ?? '';
      final query = artist.isNotEmpty ? '${artist} similar songs' : title;
      if (query.isEmpty) continue;
      try {
        final tracks = await discovery.search(query, count: 8);
        for (final track in tracks) {
          if (track.id == seed['id']) continue;
          if (shown.contains(track.id)) continue;
          if (seen.add(track.id)) result.add(track);
          if (result.length >= 12) return result;
        }
      } catch (e) {
        debugPrint('[Home] liked seed failed: $e');
      }
    }
    return result;
  }

  Future<List<DiscoveryTrack>> _similarTaste(
    List<Map<String, dynamic>> recent,
    List<Map<String, dynamic>> liked,
    Set<String> shown,
  ) async {
    final artists = <String>{};
    for (final track in [...liked, ...recent]) {
      final artist = (track['artist'] as String?)?.trim() ?? '';
      if (artist.isNotEmpty) artists.add(artist);
      if (artists.length >= 3) break;
    }
    if (artists.isEmpty) return const [];

    final result = <DiscoveryTrack>[];
    final seen = <String>{};
    for (final artist in artists) {
      try {
        final tracks = await discovery.search('$artist similar artists songs', count: 8);
        for (final track in tracks) {
          if (shown.contains(track.id)) continue;
          if (seen.add(track.id)) result.add(track);
          if (result.length >= 12) return result;
        }
      } catch (e) {
        debugPrint('[Home] taste seed failed: $e');
      }
    }
    return result;
  }

  List<DiscoveryTrack> _localTracks(Iterable<Map<String, dynamic>> source) {
    final seen = <String>{};
    final result = <DiscoveryTrack>[];
    for (final track in source) {
      final id = track['id'] as String? ?? track['videoId'] as String? ?? '';
      final title = (track['title'] as String?)?.trim() ?? '';
      if (id.isEmpty || title.isEmpty || !seen.add(id)) continue;
      result.add(DiscoveryTrack(
        id: id,
        title: title,
        artist: (track['artist'] as String?)?.trim() ?? '',
        artwork: (track['artwork'] as String?)?.trim() ?? '',
        album: track['album'] as String?,
        durationSeconds: track['duration'] is int ? track['duration'] as int : null,
      ));
    }
    return result;
  }

  List<DiscoveryTrack> _rediscoverFavorites(
    List<Map<String, dynamic>> liked,
    List<Map<String, dynamic>> recent,
  ) {
    final recentIds = recent.map((e) => e['id']).toSet();
    return _localTracks(
      liked.where((track) => !recentIds.contains(track['id'])),
    ).take(12).toList();
  }

  List<DiscoveryTrack> _fresh(
    Iterable<DiscoveryTrack> tracks,
    Set<String> shown,
  ) {
    final seen = <String>{};
    return tracks.where((track) {
      if (track.id.isEmpty || !seen.add(track.id)) return false;
      return !shown.contains(track.id);
    }).toList();
  }

  String _emoji(String title) {
    switch (title) {
      case 'New Releases':
        return '✦';
      case "India's Biggest Hits":
        return '🔥';
      case 'Bollywood Hits':
        return '🎬';
      case 'Punjabi Wave':
        return '🥁';
      case 'English Hits':
        return '🌎';
      case 'Romantic':
        return '♥';
      case 'Chill & Lo-fi':
        return '☾';
      case 'Workout':
        return '⚡';
      case 'Nostalgia':
        return '↻';
      default:
        return '';
    }
  }
}
