import 'package:flutter/foundation.dart';

import '../storage/local_library.dart';
import 'innertube_music_service.dart';

/// A data-driven Home shelf. Shelves are intentionally small and deduplicated
/// so Home feels like a music catalogue instead of a collection of repeated
/// search results.
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
    final recent = List<Map<String, dynamic>>.from(lib.recentlyPlayed.value);
    final liked = List<Map<String, dynamic>>.from(lib.likedSongs.value);
    final exposed = <String>{};
    final shelves = <HomeShelf>[];

    // Personal shelves are generated first. Remote editorial shelves are then
    // filtered against everything already shown so one song does not appear
    // five times on the same Home screen.
    final personal = <Future<HomeShelf?>>[
      _quickPicks(recent, liked),
      if (recent.isNotEmpty) _continueShelf(recent),
      if (liked.isNotEmpty || recent.isNotEmpty)
        _becauseYouListened(liked, recent),
      _rediscoverShelf(liked, recent),
    ];

    final results = await Future.wait(personal);
    for (final shelf in results) {
      if (shelf == null) continue;
      final filtered = _uniqueFresh(shelf.tracks, exposed);
      if (filtered.isNotEmpty) {
        shelves.add(HomeShelf(
          title: shelf.title,
          emoji: shelf.emoji,
          tracks: filtered.take(12).toList(),
        ));
      }
    }

    // Editorial catalogue shelves are fetched concurrently. This is a major
    // smoothness improvement over the previous serial request chain.
    final editorial = await Future.wait(
      kHomeShelfQueries.map((cfg) async {
        try {
          final tracks = await discovery.search(cfg['query']!, count: 12);
          return HomeShelf(
            title: cfg['title']!,
            emoji: _emojiFor(cfg['title']!),
            tracks: tracks,
          );
        } catch (e) {
          debugPrint('[Home] shelf ${cfg['title']} skipped: $e');
          return null;
        }
      }),
    );

    for (final shelf in editorial) {
      if (shelf == null) continue;
      final filtered = _uniqueFresh(shelf.tracks, exposed);
      if (filtered.isNotEmpty) {
        shelves.add(HomeShelf(
          title: shelf.title,
          emoji: shelf.emoji,
          tracks: filtered.take(12).toList(),
        ));
      }
    }

    return shelves;
  }

  Future<HomeShelf?> _quickPicks(
    List<Map<String, dynamic>> recent,
    List<Map<String, dynamic>> liked,
  ) async {
    final lib = LocalLibrary.instance;
    final seeds = <String>[];

    final topArtists = lib.artistPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    seeds.addAll(topArtists.take(3).map((e) => '${e.key} songs'));

    for (final entry in recent.take(5)) {
      final title = (entry['title'] as String?)?.trim();
      if (title != null && title.isNotEmpty) seeds.add(title);
    }
    for (final entry in liked.take(3)) {
      final artist = (entry['artist'] as String?)?.trim();
      if (artist != null && artist.isNotEmpty) seeds.add('$artist songs');
    }

    final out = <DiscoveryTrack>[];
    final seen = <String>{};
    for (final seed in seeds.take(6)) {
      try {
        final tracks = await discovery.search(seed, count: 6);
        for (final track in tracks) {
          if (seen.add(track.id)) out.add(track);
          if (out.length >= 16) break;
        }
      } catch (_) {}
      if (out.length >= 16) break;
    }

    if (out.isEmpty) return null;
    return HomeShelf(title: 'Quick Picks', emoji: '🔥', tracks: out);
  }

  Future<HomeShelf?> _continueShelf(List<Map<String, dynamic>> recent) async {
    final out = <DiscoveryTrack>[];
    final seen = <String>{};
    for (final item in recent.take(8)) {
      final id = item['id'] as String? ?? '';
      final title = item['title'] as String? ?? '';
      final artist = item['artist'] as String? ?? '';
      final artwork = item['artwork'] as String? ?? '';
      if (id.isNotEmpty && title.isNotEmpty && seen.add(id)) {
        out.add(DiscoveryTrack(
          id: id,
          title: title,
          artist: artist,
          artwork: artwork,
        ));
      }
    }
    return out.isEmpty
        ? null
        : HomeShelf(title: 'Recently Played', emoji: '🕘', tracks: out);
  }

  Future<HomeShelf?> _becauseYouListened(
    List<Map<String, dynamic>> liked,
    List<Map<String, dynamic>> recent,
  ) async {
    final seed = liked.isNotEmpty ? liked.first : recent.first;
    final artist = (seed['artist'] as String?)?.trim() ?? '';
    final title = (seed['title'] as String?)?.trim() ?? '';
    final query = artist.isNotEmpty ? '$artist songs' : '$title similar songs';
    if (query.trim().isEmpty) return null;

    try {
      final tracks = await discovery.search(query, count: 14);
      if (tracks.isEmpty) return null;
      return HomeShelf(
        title: artist.isNotEmpty
            ? 'More from $artist'
            : 'Because You Listened',
        emoji: '💖',
        tracks: tracks,
      );
    } catch (_) {
      return null;
    }
  }

  Future<HomeShelf?> _rediscoverShelf(
    List<Map<String, dynamic>> liked,
    List<Map<String, dynamic>> recent,
  ) async {
    if (liked.isEmpty) return null;
    final recentIds = recent.map((e) => e['id']).toSet();
    final out = liked
        .where((e) => !recentIds.contains(e['id']))
        .take(12)
        .map((e) => DiscoveryTrack(
              id: e['id'] as String? ?? '',
              title: e['title'] as String? ?? '',
              artist: e['artist'] as String? ?? '',
              artwork: e['artwork'] as String? ?? '',
            ))
        .where((t) => t.id.isNotEmpty && t.title.isNotEmpty)
        .toList();
    return out.isEmpty
        ? null
        : HomeShelf(title: 'Rediscover Your Favorites', emoji: '❤️', tracks: out);
  }

  List<DiscoveryTrack> _uniqueFresh(
    List<DiscoveryTrack> source,
    Set<String> globalSeen,
  ) {
    final local = <String>{};
    final out = <DiscoveryTrack>[];
    for (final track in source) {
      if (track.id.isEmpty || !local.add(track.id)) continue;
      if (globalSeen.contains(track.id)) continue;
      globalSeen.add(track.id);
      out.add(track);
    }
    return out;
  }

  String _emojiFor(String title) {
    const map = <String, String>{
      'Trending Music': '🔥',
      'New Music': '🆕',
      'Bollywood Hits': '🎬',
      'Hindi Hits': '🎵',
      'Punjabi Hits': '🥁',
      'English Pop': '🌎',
      'Romantic': '💖',
      'Sad': '💙',
      'Chill': '🌙',
      'Workout': '💪',
      'Party': '🥳',
      'Lo-fi': '🎧',
      'Devotional': '🙏',
    };
    return map[title] ?? '';
  }
}
