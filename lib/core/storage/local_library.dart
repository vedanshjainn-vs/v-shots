// ════════════════════════════════════════════════
// V Shots — Local Library (persisted Liked Songs / Recently Played /
// Playlists / taste-profile)
// ════════════════════════════════════════════════
//
// WHY THIS FILE EXISTS:
// Before this, `likedSongIds`, `recentSearches`, and
// ForYouFeedService's `_artistPlayCounts` were all plain in-memory
// variables — every one of them was silently wiped every time the app
// restarted. The LibraryScreen showed "Liked Songs 0 / Downloads 0 /
// Playlists 0" permanently regardless of actual use, because nothing
// was ever persisted anywhere. This is the single real persistence
// layer for the app, built on `shared_preferences` (simple, reliable,
// zero backend dependency — matching this app's "no server required"
// design elsewhere).
//
// Data model: everything is stored as JSON-encoded strings under a
// small number of keys — this is deliberately simple (not a real
// database) because the data volumes here (liked songs, recent plays,
// a handful of playlists) are small; if this ever needs to scale to
// thousands of entries with complex queries, migrate to Hive/sqflite
// then, not preemptively now.
// ════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalLibrary {
  LocalLibrary._();
  static final LocalLibrary instance = LocalLibrary._();

  static const _kLikedSongs = 'v_shots.liked_songs.v1';
  static const _kRecentlyPlayed = 'v_shots.recently_played.v1';
  static const _kPlaylists = 'v_shots.playlists.v1';
  static const _kArtistPlayCounts = 'v_shots.artist_play_counts.v1';
  static const _kDownloadedTracks = 'v_shots.downloaded_tracks.v1';
  static const _kRecentSearches = 'v_shots.recent_searches.v1';

  SharedPreferences? _prefs;
  bool _ready = false;

  // In-memory mirrors, kept in sync with SharedPreferences so the UI
  // can read synchronously (ValueNotifier-style) without an `await` on
  // every list build.
  final ValueNotifier<List<Map<String, dynamic>>> likedSongs =
      ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> recentlyPlayed =
      ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> playlists =
      ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> downloadedTracks =
      ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> recentSearches =
      ValueNotifier([]);
  Map<String, int> artistPlayCounts = {};

  static const int _maxRecentlyPlayed = 100;

  Future<void> initialize() async {
    if (_ready) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      likedSongs.value = _readList(_kLikedSongs);
      recentlyPlayed.value = _readList(_kRecentlyPlayed);
      playlists.value = _readList(_kPlaylists);
      downloadedTracks.value = _readList(_kDownloadedTracks);
      recentSearches.value = _readList(_kRecentSearches);
      final rawCounts = _prefs!.getString(_kArtistPlayCounts);
      if (rawCounts != null) {
        final decoded = jsonDecode(rawCounts) as Map<String, dynamic>;
        artistPlayCounts = decoded.map((k, v) => MapEntry(k, v as int));
      }
      _ready = true;
      debugPrint('[LocalLibrary] Loaded: '
          '${likedSongs.value.length} liked, '
          '${recentlyPlayed.value.length} recent, '
          '${playlists.value.length} playlists, '
          '${downloadedTracks.value.length} downloaded.');
    } catch (e) {
      // Never let a storage failure block app startup — the app is
      // still fully usable for playback without persisted library
      // data, it just won't remember state across restarts.
      debugPrint('[LocalLibrary] Failed to initialize: $e');
    }
  }

  List<Map<String, dynamic>> _readList(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[LocalLibrary] Corrupt data for $key, resetting: $e');
      return [];
    }
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> value) {
    return _prefs?.setString(key, jsonEncode(value)) ?? Future.value(false);
  }

  // ── Liked Songs ──────────────────────────────────────────────────
  bool isLiked(String trackId) =>
      likedSongs.value.any((t) => t['id'] == trackId);

  Future<void> toggleLiked(Map<String, dynamic> track) async {
    final list = List<Map<String, dynamic>>.from(likedSongs.value);
    final id = track['id'];
    final existingIndex = list.indexWhere((t) => t['id'] == id);
    if (existingIndex >= 0) {
      list.removeAt(existingIndex);
    } else {
      list.insert(0, track);
    }
    likedSongs.value = list;
    await _writeList(_kLikedSongs, list);
  }

  // ── Recently Played ──────────────────────────────────────────────
  Future<void> recordRecentlyPlayed(Map<String, dynamic> track) async {
    final list = List<Map<String, dynamic>>.from(recentlyPlayed.value);
    list.removeWhere((t) => t['id'] == track['id']);
    list.insert(0, {...track, 'playedAt': DateTime.now().toIso8601String()});
    if (list.length > _maxRecentlyPlayed) {
      list.removeRange(_maxRecentlyPlayed, list.length);
    }
    recentlyPlayed.value = list;
    await _writeList(_kRecentlyPlayed, list);

    // Also feed the taste-profile signal used by the "For You" feed —
    // previously this only updated when playing FROM the For You feed
    // itself, meaning normal Home/Search plays never improved
    // recommendations at all. Now every real play anywhere in the app
    // contributes.
    final artist = track['artist'] as String? ?? '';
    if (artist.isNotEmpty) {
      artistPlayCounts[artist] = (artistPlayCounts[artist] ?? 0) + 1;
      await _prefs?.setString(_kArtistPlayCounts, jsonEncode(artistPlayCounts));
    }
  }

  Future<void> clearRecentlyPlayed() async {
    recentlyPlayed.value = [];
    await _writeList(_kRecentlyPlayed, []);
  }

  // ── Playlists ────────────────────────────────────────────────────
  Future<void> createPlaylist(String name) async {
    final list = List<Map<String, dynamic>>.from(playlists.value);
    list.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'tracks': <Map<String, dynamic>>[],
      'createdAt': DateTime.now().toIso8601String(),
    });
    playlists.value = list;
    await _writeList(_kPlaylists, list);
  }

  Future<void> deletePlaylist(String playlistId) async {
    final list = List<Map<String, dynamic>>.from(playlists.value)
      ..removeWhere((p) => p['id'] == playlistId);
    playlists.value = list;
    await _writeList(_kPlaylists, list);
  }

  Future<void> addTrackToPlaylist(
      String playlistId, Map<String, dynamic> track) async {
    final list = List<Map<String, dynamic>>.from(playlists.value);
    final index = list.indexWhere((p) => p['id'] == playlistId);
    if (index < 0) return;
    final playlist = Map<String, dynamic>.from(list[index]);
    final tracks =
        List<Map<String, dynamic>>.from(playlist['tracks'] as List? ?? []);
    if (!tracks.any((t) => t['id'] == track['id'])) {
      tracks.add(track);
    }
    playlist['tracks'] = tracks;
    list[index] = playlist;
    playlists.value = list;
    await _writeList(_kPlaylists, list);
  }

  Future<void> removeTrackFromPlaylist(
      String playlistId, String trackId) async {
    final list = List<Map<String, dynamic>>.from(playlists.value);
    final index = list.indexWhere((p) => p['id'] == playlistId);
    if (index < 0) return;
    final playlist = Map<String, dynamic>.from(list[index]);
    final tracks =
        List<Map<String, dynamic>>.from(playlist['tracks'] as List? ?? []);
    tracks.removeWhere((t) => t['id'] == trackId);
    playlist['tracks'] = tracks;
    list[index] = playlist;
    playlists.value = list;
    await _writeList(_kPlaylists, list);
  }

  // ── Downloaded (local-file-imported) tracks ─────────────────────
  // See features/library/local_import_service.dart for the legal
  // rationale: this only ever indexes files the USER already has on
  // their device (imported via the system file picker), never
  // downloads/caches streamed YouTube audio — that would be the exact
  // illegal pattern this whole project has been built to avoid.
  Future<void> addDownloadedTrack(Map<String, dynamic> track) async {
    final list = List<Map<String, dynamic>>.from(downloadedTracks.value);
    list.removeWhere((t) => t['id'] == track['id']);
    list.insert(0, track);
    downloadedTracks.value = list;
    await _writeList(_kDownloadedTracks, list);
  }

  Future<void> removeDownloadedTrack(String trackId) async {
    final list = List<Map<String, dynamic>>.from(downloadedTracks.value)
      ..removeWhere((t) => t['id'] == trackId);
    downloadedTracks.value = list;
    await _writeList(_kDownloadedTracks, list);
  }

  // ── Recent Searches ──────────────────────────────────────────────
  Future<void> recordRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final list = List<Map<String, dynamic>>.from(recentSearches.value);
    list.removeWhere((s) => s['query'] == query);
    list.insert(0, {'query': query});
    if (list.length > 10) list.removeRange(10, list.length);
    recentSearches.value = list;
    await _writeList(_kRecentSearches, list);
  }
}
