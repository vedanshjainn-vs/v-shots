// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Personalization store (onboarding preferences + cold-start)
// ═════════════════════════════════════════════════════════════════════════════
//
// Persists the user's onboarding choices (preferred languages + genres) and
// the onboarded flag via shared_preferences — same storage technology as
// LocalLibrary/SignalStore. This is the single source of truth the
// RecommendationEngine's COLD-START candidate generation reads, so a brand-new
// user gets a Home/Discovery seeded with their stated taste instead of a
// completely generic feed. The engine's ongoing personalization (plays, likes,
// skips) lives in SignalStore/TasteProfile and takes over once there is real
// history.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalizationStore {
  PersonalizationStore._();
  static final PersonalizationStore instance = PersonalizationStore._();

  static const _kOnboarded = 'v_shots.onboarded.v1';
  static const _kLanguages = 'v_shots.pref_languages.v1';
  static const _kGenres = 'v_shots.pref_genres.v1';

  SharedPreferences? _prefs;
  bool _ready = false;

  bool _onboarded = false;
  List<String> _preferredLanguages = const [];
  List<String> _preferredGenres = const [];

  bool get onboarded => _onboarded;
  List<String> get preferredLanguages => List.unmodifiable(_preferredLanguages);
  List<String> get preferredGenres => List.unmodifiable(_preferredGenres);

  /// True once the user has completed onboarding (or explicitly skipped it).
  bool get hasPreferences =>
      _preferredLanguages.isNotEmpty || _preferredGenres.isNotEmpty;

  Future<void> initialize() async {
    if (_ready) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _onboarded = _prefs?.getBool(_kOnboarded) ?? false;
      _preferredLanguages = _readStringList(_kLanguages);
      _preferredGenres = _readStringList(_kGenres);
      _ready = true;
      debugPrint(
        '[Personalization] onboarded=$_onboarded '
        'languages=${_preferredLanguages.length} '
        'genres=${_preferredGenres.length}',
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

  /// Persists the user's onboarding choices and marks onboarding complete.
  Future<void> completeOnboarding({
    List<String> languages = const [],
    List<String> genres = const [],
  }) async {
    _preferredLanguages = List.of(languages);
    _preferredGenres = List.of(genres);
    _onboarded = true;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _prefs?.setBool(_kOnboarded, _onboarded);
      await _prefs?.setString(_kLanguages, jsonEncode(_preferredLanguages));
      await _prefs?.setString(_kGenres, jsonEncode(_preferredGenres));
    } catch (e) {
      debugPrint('[Personalization] persist failed: $e');
    }
  }

  /// Test/debug helper.
  Future<void> reset() async {
    _onboarded = false;
    _preferredLanguages = const [];
    _preferredGenres = const [];
    await _prefs?.remove(_kOnboarded);
    await _prefs?.remove(_kLanguages);
    await _prefs?.remove(_kGenres);
  }
}
