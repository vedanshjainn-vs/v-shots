// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Personalization store (onboarding preferences + cold-start)
// ═════════════════════════════════════════════════════════════════════════════
//
// Persists the user's onboarding choices (languages, genres, favorite
// artists, favorite seed songs) and the onboarded flag via
// shared_preferences — same storage technology as LocalLibrary/SignalStore.
// This is the single source of truth the RecommendationEngine's COLD-START
// candidate generation reads, so a brand-new user gets a Home/Discovery
// seeded with their stated taste instead of a completely generic feed. The
// engine's ongoing personalization (plays, likes, skips) lives in
// SignalStore/TasteProfile and takes over once there is real history.
//
// Cross-device sync for signed-in users: [UserPreferenceSync] mirrors this
// bundle into the existing `user_taste_profile` table (owner-only RLS).
//
// [revision] bumps on EVERY change so caches (RecommendationCache, shelf
// caches) can detect preference changes and recompute — cached personalized
// content must never outlive the preferences that produced it.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A favorite song chosen during onboarding (or later from the player).
/// `id` is the provider video id; `title`/`artist` power seed queries.
class FavoriteSong {
  const FavoriteSong({required this.id, required this.title, this.artist = ''});

  final String id;
  final String title;
  final String artist;

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'artist': artist};

  static FavoriteSong? fromMap(Object? map) {
    if (map is! Map) return null;
    final id = map['id'];
    final title = map['title'];
    if (id is! String || id.isEmpty || title is! String || title.isEmpty) {
      return null;
    }
    final artist = map['artist'];
    return FavoriteSong(
      id: id,
      title: title,
      artist: artist is String ? artist : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FavoriteSong && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);
}

class PersonalizationStore extends ChangeNotifier {
  PersonalizationStore._();

  static final PersonalizationStore instance = PersonalizationStore._();

  static const _kOnboarded = 'v_shots.onboarded.v1';
  static const _kLanguages = 'v_shots.pref_languages.v1';
  static const _kGenres = 'v_shots.pref_genres.v1';
  static const _kArtists = 'v_shots.pref_artists.v1';
  static const _kSongs = 'v_shots.pref_songs.v1';
  static const _kUpdatedAt = 'v_shots.pref_updated_at.v1';

  SharedPreferences? _prefs;
  bool _ready = false;

  bool _onboarded = false;
  List<String> _preferredLanguages = const [];
  List<String> _preferredGenres = const [];
  List<String> _favoriteArtists = const [];
  List<FavoriteSong> _favoriteSongs = const [];
  DateTime? _updatedAt;

  /// Increments on every preference change — caches compare this to detect
  /// staleness (preferences changed ⇒ personalized caches must recompute).
  int _revision = 0;

  bool get onboarded => _onboarded;
  List<String> get preferredLanguages => List.unmodifiable(_preferredLanguages);
  List<String> get preferredGenres => List.unmodifiable(_preferredGenres);
  List<String> get favoriteArtists => List.unmodifiable(_favoriteArtists);
  List<FavoriteSong> get favoriteSongs => List.unmodifiable(_favoriteSongs);
  DateTime? get updatedAt => _updatedAt;
  int get revision => _revision;

  /// True once the user has completed onboarding with at least one choice
  /// (or explicitly skipped it after making choices).
  bool get hasPreferences =>
      _preferredLanguages.isNotEmpty ||
      _preferredGenres.isNotEmpty ||
      _favoriteArtists.isNotEmpty ||
      _favoriteSongs.isNotEmpty;

  Future<void> initialize() async {
    if (_ready) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _onboarded = _prefs?.getBool(_kOnboarded) ?? false;
      _preferredLanguages = _readStringList(_kLanguages);
      _preferredGenres = _readStringList(_kGenres);
      _favoriteArtists = _readStringList(_kArtists);
      _favoriteSongs = _readSongs();
      final rawUpdated = _prefs?.getString(_kUpdatedAt);
      _updatedAt = rawUpdated != null ? DateTime.tryParse(rawUpdated) : null;
      _ready = true;
      debugPrint(
        '[Personalization] onboarded=$_onboarded '
        'languages=${_preferredLanguages.length} '
        'genres=${_preferredGenres.length} '
        'artists=${_favoriteArtists.length} '
        'songs=${_favoriteSongs.length}',
      );
    } catch (e) {
      debugPrint('[Personalization] initialize failed: $e');
    }
  }

  List<String> _readStringList(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  List<FavoriteSong> _readSongs() {
    final raw = _prefs?.getString(_kSongs);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(FavoriteSong.fromMap)
          .whereType<FavoriteSong>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Persists the user's onboarding choices and marks onboarding complete.
  Future<void> completeOnboarding({
    List<String> languages = const [],
    List<String> genres = const [],
    List<String> artists = const [],
    List<FavoriteSong> songs = const [],
  }) async {
    _preferredLanguages = List.of(languages);
    _preferredGenres = List.of(genres);
    _favoriteArtists = List.of(artists);
    _favoriteSongs = List.of(songs);
    _onboarded = true;
    await _persist();
  }

  /// Post-onboarding edits (Profile → Preferences). Any null field keeps
  /// the current value; provided lists replace wholesale.
  Future<void> updatePreferences({
    List<String>? languages,
    List<String>? genres,
    List<String>? artists,
    List<FavoriteSong>? songs,
  }) async {
    if (languages != null) {
      _preferredLanguages = List.of(languages);
    }
    if (genres != null) {
      _preferredGenres = List.of(genres);
    }
    if (artists != null) {
      _favoriteArtists = List.of(artists);
    }
    if (songs != null) {
      _favoriteSongs = List.of(songs);
    }
    await _persist();
  }

  /// Marks onboarding as completed WITHOUT choices (explicit skip).
  Future<void> markOnboardedSkipped() async {
    _onboarded = true;
    await _persist();
  }

  Future<void> _persist() async {
    _updatedAt = DateTime.now();
    _revision++;
    try {
      await _prefs?.setBool(_kOnboarded, _onboarded);
      await _prefs?.setString(_kLanguages, jsonEncode(_preferredLanguages));
      await _prefs?.setString(_kGenres, jsonEncode(_preferredGenres));
      await _prefs?.setString(_kArtists, jsonEncode(_favoriteArtists));
      await _prefs?.setString(
        _kSongs,
        jsonEncode(_favoriteSongs.map((s) => s.toMap()).toList()),
      );
      await _prefs?.setString(_kUpdatedAt, _updatedAt!.toIso8601String());
    } catch (e) {
      debugPrint('[Personalization] persist failed: $e');
    }
    notifyListeners();
  }

  /// Adopt preferences synced from another device (fresher `updatedAt`).
  /// Used by [UserPreferenceSync] on login. Returns false when the remote
  /// bundle is older than what we already have.
  bool adoptRemoteBundle(Map<String, dynamic> bundle) {
    final remoteUpdated =
        DateTime.tryParse(bundle['updated_at'] as String? ?? '');
    if (remoteUpdated == null) return false;
    if (_updatedAt != null && !_updatedAt!.isBefore(remoteUpdated)) {
      return false;
    }

    final languages = (bundle['languages'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    final genres =
        (bundle['genres'] as List<dynamic>? ?? []).whereType<String>().toList();
    final artists = (bundle['artists'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    final songs = (bundle['songs'] as List<dynamic>? ?? [])
        .map(FavoriteSong.fromMap)
        .whereType<FavoriteSong>()
        .toList();

    _preferredLanguages = languages;
    _preferredGenres = genres;
    _favoriteArtists = artists;
    _favoriteSongs = songs;
    _onboarded = bundle['onboarded'] == true || hasPreferences;
    _updatedAt = remoteUpdated;
    _revision++;
    // Persist without bumping updatedAt again.
    _prefs
      ?..setBool(_kOnboarded, _onboarded)
      ..setString(_kLanguages, jsonEncode(_preferredLanguages))
      ..setString(_kGenres, jsonEncode(_preferredGenres))
      ..setString(_kArtists, jsonEncode(_favoriteArtists))
      ..setString(
          _kSongs, jsonEncode(_favoriteSongs.map((s) => s.toMap()).toList()))
      ..setString(_kUpdatedAt, remoteUpdated.toIso8601String());
    notifyListeners();
    return true;
  }

  /// The serializable bundle mirrored to `user_taste_profile.profile` for
  /// signed-in users (owner-only RLS on that table).
  Map<String, dynamic> toBundle() => {
        'onboarded': _onboarded,
        'languages': _preferredLanguages,
        'genres': _preferredGenres,
        'artists': _favoriteArtists,
        'songs': _favoriteSongs.map((s) => s.toMap()).toList(),
        'updated_at': _updatedAt?.toIso8601String(),
      };

  /// Test/debug helper.
  Future<void> reset() async {
    _onboarded = false;
    _preferredLanguages = const [];
    _preferredGenres = const [];
    _favoriteArtists = const [];
    _favoriteSongs = const [];
    _updatedAt = null;
    _revision++;
    await _prefs?.remove(_kOnboarded);
    await _prefs?.remove(_kLanguages);
    await _prefs?.remove(_kGenres);
    await _prefs?.remove(_kArtists);
    await _prefs?.remove(_kSongs);
    await _prefs?.remove(_kUpdatedAt);
    notifyListeners();
  }
}
