// ═════════════════════════════════════════════════════════════════════════
// V Shots — UserPreferences (Country / Language / Genre / Vibe personalization)
//
// The single source of truth for a user's content preferences. Set once during
// first-install onboarding (Phase 1-2), editable later in Settings →
// Content Preferences (Phase 19). Persisted locally for instant startup and
// synced to Supabase `user_preferences` when the user is signed in.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted content preferences. Country is a PREFERENCE signal, not a hard
/// filter — international content is still shown per taste/behavior (Phase 5).
class UserPreferences {
  UserPreferences({
    this.country = '',
    List<String> languages = const [],
    List<String> genres = const [],
    List<String> vibes = const [],
    this.onboardingCompleted = false,
  })  : languages = List.of(languages),
        genres = List.of(genres),
        vibes = List.of(vibes);

  String country;
  List<String> languages;
  List<String> genres;
  List<String> vibes;
  bool onboardingCompleted;

  bool get hasCompletedOnboarding => onboardingCompleted;

  Map<String, dynamic> toJson() => {
        'country': country,
        'languages': languages,
        'genres': genres,
        'vibes': vibes,
        'onboardingCompleted': onboardingCompleted,
      };

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        country: (json['country'] as String?) ?? '',
        languages: ((json['languages'] as List?) ?? const []).cast<String>(),
        genres: ((json['genres'] as List?) ?? const []).cast<String>(),
        vibes: ((json['vibes'] as List?) ?? const []).cast<String>(),
        onboardingCompleted: (json['onboardingCompleted'] as bool?) ?? false,
      );

  /// Default region derived from device locale when onboarding is skipped.
  static String defaultCountryFromLocale(String? locale) {
    final loc = (locale ?? 'IN').toUpperCase();
    if (loc.contains('IN')) return 'India';
    if (loc.contains('US')) return 'United States';
    if (loc.contains('GB') || loc.contains('UK')) return 'United Kingdom';
    if (loc.contains('CA')) return 'Canada';
    if (loc.contains('AU')) return 'Australia';
    if (loc.contains('PK')) return 'Pakistan';
    if (loc.contains('BD')) return 'Bangladesh';
    if (loc.contains('NP')) return 'Nepal';
    if (loc.contains('AE')) return 'UAE';
    if (loc.contains('SA')) return 'Saudi Arabia';
    return 'Other';
  }
}

/// Local persistence for [UserPreferences] (SharedPreferences), plus helpers
/// for the taste-profile genre/vibe defaults used in cold start.
class PreferencesStore {
  PreferencesStore._();
  static final PreferencesStore instance = PreferencesStore._();

  static const _kKey = 'v_shots.user_preferences.v1';

  UserPreferences _prefs = UserPreferences();
  UserPreferences get preferences => _prefs;
  bool _loaded = false;

  Future<void> initialize() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _prefs = UserPreferences.fromJson(decoded);
        }
      }
    } catch (_) {}
  }

  Future<void> save(UserPreferences prefs) async {
    _prefs = prefs;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kKey, jsonEncode(prefs.toJson()));
    } catch (_) {}
  }

  /// One-time onboarding flag: returns true only the FIRST time the app runs
  /// without completed onboarding, and is not re-triggered.
  bool get needsOnboarding => !_prefs.onboardingCompleted;
}
