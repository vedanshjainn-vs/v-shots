// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — PersonalizedHomeService
//
// ArchiveTune-style Home: combines LOCAL listening intelligence with REMOTE
// YouTube Music discovery into an ordered, personalized shelf feed.
//
// Signals used (from LocalLibrary):
//   • recently played      -> Continue Listening / More like recent artist
//   • song play counts     -> Quick Picks "strong songs"
//   • artist play counts   -> top artists -> similar search
//   • liked songs          -> Because You Liked X / Forgotten Favorites
//
// Fallback chain (ArchiveTune quickPicksWithFallback):
//   Quick Picks (personalized) -> recent songs -> trending (all-songs fallback)
// so a fresh install never shows a dead Home.
//
// Each shelf is real data from InnerTube search (no mock songs). One shelf
// failing never breaks the whole feed.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

import '../storage/local_library.dart';
import 'innertube_music_service.dart';

/// A Home shelf with a contextual emoji label (presentation sugar).
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

  /// Builds the personalized Home shelf feed.
  ///
  /// [recentlyPlayed], [likedSongs] and play counts come from LocalLibrary.
  /// The order personalizes: Quick Picks first, then Continue Listening,
  /// Because You Liked X, More Like, Trending, genre shelves, Forgotten
  /// Favorites.
  Future<List<HomeShelf>> buildHome() async {
    final shelves = <HomeShelf>[];
    final lib = LocalLibrary.instance;
    final recent = lib.recentlyPlayed.value;
    final liked = lib.likedSongs.value;

    // ── 1. Quick Picks (personalized) ──────────────────────────────
    final quickPicks = await _quickPicks(recent: recent, liked: liked);
    if (quickPicks.tracks.isNotEmpty) {
      shelves.add(quickPicks);
    }

    // ── 2. Continue Listening (recent songs, keep listening) ───────
    if (recent.isNotEmpty) {
      final continueTracks = await _continueListening(recent);
      if (continueTracks.isNotEmpty) {
        shelves.add(HomeShelf(
          title: 'Continue Listening',
          emoji: '▶️',
          tracks: continueTracks,
        ));
      }
    }

    // ── 3. Because You Liked X / More Like recent artist ───────────
    if (liked.isNotEmpty) {
      final seed = liked.first;
      final artist = (seed['artist'] as String?)?.trim() ?? '';
      final title = (seed['title'] as String?)?.trim() ?? '';
      final seedName = artist.isNotEmpty ? artist : title;
      if (seedName.isNotEmpty) {
        final related = await _similar(seedName);
        if (related.isNotEmpty) {
          shelves.add(HomeShelf(
            title: 'Because You Liked "${title.isEmpty ? seedName : title}"',
            emoji: '❤️',
            tracks: related,
          ));
        }
      }
    } else if (recent.isNotEmpty) {
      final seed = recent.first;
      final artist = (seed['artist'] as String?)?.trim() ?? '';
      final title = (seed['title'] as String?)?.trim() ?? '';
      final seedName = artist.isNotEmpty ? artist : title;
      if (seedName.isNotEmpty) {
        final related = await _similar(seedName);
        if (related.isNotEmpty) {
          shelves.add(HomeShelf(
            title: 'More Like "${title.isEmpty ? seedName : title}"',
            emoji: '🎧',
            tracks: related,
          ));
        }
      }
    }

    // ── 4. Trending + genre/mood shelves ───────────────────────────
    for (final cfg in kHomeShelfQueries) {
      try {
        final tracks = await discovery.search(cfg['query']!, count: 12);
        if (tracks.isEmpty) continue;
        shelves.add(HomeShelf(
          title: cfg['title']!,
          emoji: _emojiFor(cfg['title']!),
          tracks: tracks,
        ));
      } catch (e) {
        debugPrint('[Home] shelf "${cfg['title']}" skipped: $e');
      }
    }

    // ── 5. Forgotten Favorites (liked but not played recently) ─────
    final forgotten = _forgottenFavorites(liked, recent);
    if (forgotten.isNotEmpty) {
      shelves.add(HomeShelf(
        title: 'Rediscover Your Favorites',
        emoji: '❤️',
        tracks: forgotten,
      ));
    }

    return shelves;
  }

  /// Quick Picks: combine recent plays + top artists + strong songs into a
  /// personalized set. Falls back to recent songs, then trending.
  Future<HomeShelf> _quickPicks({
    required List<Map<String, dynamic>> recent,
    required List<Map<String, dynamic>> liked,
  }) async {
    final lib = LocalLibrary.instance;
    final pickPool = <DiscoveryTrack>{};

    // Signal 1: top artists by play count.
    final topArtists = lib.artistPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final a in topArtists.take(3)) {
      try {
        final tracks = await discovery.search('${a.key} songs', count: 8);
        for (final t in tracks) {
          if (pickPool.length >= 20) break;
          pickPool.add(t);
        }
      } catch (_) {}
      if (pickPool.length >= 20) break;
    }

    // Signal 2: strong songs (highest play count) — re-fetch by title.
    final strongSongs = lib.songPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final s in strongSongs.take(3)) {
      if (pickPool.length >= 20) break;
      final recentTrack = recent.cast<Map<String, dynamic>?>().firstWhere(
            (r) => r?['id'] == s.key,
            orElse: () => null,
          );
      final title = recentTrack?['title'] as String? ?? '';
      if (title.isEmpty) continue;
      try {
        final tracks = await discovery.search(title, count: 5);
        for (final t in tracks) {
          if (pickPool.length >= 20) break;
          pickPool.add(t);
        }
      } catch (_) {}
    }

    if (pickPool.isNotEmpty) {
      return HomeShelf(
        title: 'Quick Picks',
        emoji: '🔥',
        tracks: pickPool.take(15).toList(),
      );
    }

    // Fallback chain.
    if (recent.isNotEmpty) {
      return HomeShelf(
        title: 'Recent for You',
        emoji: '🕘',
        tracks: await _continueListening(recent),
      );
    }
    return const HomeShelf(title: 'Quick Picks', emoji: '🔥', tracks: []);
  }

  Future<List<DiscoveryTrack>> _continueListening(
      List<Map<String, dynamic>> recent) async {
    final out = <DiscoveryTrack>[];
    final seen = <String>{};
    for (final r in recent.take(10)) {
      final title = (r['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) continue;
      try {
        final tracks = await discovery.search(title, count: 1);
        for (final t in tracks) {
          if (seen.add(t.id)) out.add(t);
        }
      } catch (_) {}
    }
    return out;
  }

  Future<List<DiscoveryTrack>> _similar(String artistOrSong) async {
    final seen = <String>{};
    final out = <DiscoveryTrack>[];
    try {
      final tracks = await discovery.search('$artistOrSong songs', count: 15);
      for (final t in tracks) {
        if (seen.add(t.id)) out.add(t);
      }
    } catch (_) {}
    return out;
  }

  List<DiscoveryTrack> _forgottenFavorites(
    List<Map<String, dynamic>> liked,
    List<Map<String, dynamic>> recent,
  ) {
    final playedIds = recent.map((r) => r['id']).toSet();
    final out = <DiscoveryTrack>[];
    final seen = <String>{};
    for (final l in liked) {
      if (playedIds.contains(l['id'])) continue; // still fresh
      final id = l['id'] as String? ?? '';
      final title = l['title'] as String? ?? '';
      final artist = l['artist'] as String? ?? '';
      final artwork = l['artwork'] as String? ?? '';
      if (id.isEmpty || title.isEmpty) continue;
      if (seen.add(id)) {
        out.add(DiscoveryTrack(
          id: id,
          title: title,
          artist: artist,
          artwork: artwork,
        ));
      }
    }
    return out.take(12).toList();
  }

  String _emojiFor(String title) {
    const map = {
      'Quick Picks': '🔥',
      'Trending Music': '🔥',
      'New Music': '🆕',
      'Bollywood Hits': '🎬',
      'Hindi Hits': '🎵',
      'Punjabi Hits': '🥁',
      'English Pop': '🌎',
      'Romantic': '💖',
      'Chill': '🌙',
      'Workout': '💪',
    };
    return map[title] ?? '';
  }
}
