// ═════════════════════════════════════════════════════════════════════════
// V Shots — Remote Config Service (Supabase-backed)
//
// Lets Home layout and the Discovery category list be changed WITHOUT an app
// update, by reading two Supabase tables:
//
//   discovery_categories (Section 1 & 3):
//       id text PK, name text, emoji text, query text, fallback_category text,
//       sort_order int, active boolean, updated_at timestamptz
//
//   home_layout_config (Section 3):
//       id text PK, section_key text, title text, section_type text,
//       query text, sort_order int, visible boolean, max_items int,
//       updated_at timestamptz
//
// Behaviour:
//   - Reads from Supabase when available, else falls back to the compiled
//     defaults (kDiscoveryCategories / the default Home sections).
//   - Caches locally (SharedPreferences) with a short TTL (default 1 hour) so
//     the app does NOT hit Supabase on every launch but still stays fresh.
//   - A failure to reach Supabase NEVER blocks the app: it returns the cached
//     value if present, otherwise the compiled defaults.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/supabase_service.dart';
import '../config/discovery_categories.dart';

class RemoteConfigService {
  RemoteConfigService._();

  static final RemoteConfigService instance = RemoteConfigService._();

  static const Duration _cacheTtl = Duration(hours: 1);
  static const _cacheKeyCategories = 'rc_discovery_categories';
  static const _cacheKeyHome = 'rc_home_layout';
  static const _cacheKeyTs = 'rc_timestamp';

  List<DiscoveryCategory> _categories = kDiscoveryCategories;
  List<DiscoveryCategory> get categories => _categories;

  /// The remote Home section layout. Each entry maps to a Home row.
  List<Map<String, dynamic>> _homeSections = const [];
  List<Map<String, dynamic>> get homeSections => _homeSections;

  bool _loaded = false;

  /// Loads cached config synchronously (SharedPreferences) and kicks off a
  /// background refresh if the cache is stale. Safe to call at startup.
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_cacheKeyTs) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;

      final catsJson = prefs.getString(_cacheKeyCategories);
      if (catsJson != null) {
        _categories = _decodeCategories(catsJson);
      }
      final homeJson = prefs.getString(_cacheKeyHome);
      if (homeJson != null) {
        _homeSections = _decodeHome(homeJson);
      }

      // Refresh if stale (but only if we have backend access).
      if (age > _cacheTtl.inMilliseconds || ts == 0) {
        await refresh();
      }
    } catch (e) {
      debugPrint('[RemoteConfig] init error: $e');
    }
  }

  Future<void> refresh() async {
    if (!SupabaseService.isAvailable) {
      debugPrint(
          '[RemoteConfig] Supabase unavailable — keeping cached/defaults');
      return;
    }
    try {
      final db = SupabaseService.client;

      // 1. Discovery categories.
      final catRows = await db
          .from('discovery_categories')
          .select()
          .eq('active', true)
          .order('sort_order')
          .limit(50);
      if (catRows.isNotEmpty) {
        final parsed = <DiscoveryCategory>[];
        for (final row in catRows) {
          final name = row['name'] as String? ?? '';
          final query = row['query'] as String? ?? '';
          final fallback = row['fallback_category'] as String? ?? 'global';
          if (name.isEmpty || query.isEmpty) continue;
          parsed.add(
            DiscoveryCategory(
              id: row['id'] as String? ?? name,
              label: name,
              icon: row['emoji'] as String? ?? '🎵',
              query: query,
              fallbackCategory: fallback,
            ),
          );
        }
        if (parsed.isNotEmpty) {
          _categories = parsed;
        }
      }

      // 2. Home layout.
      final homeRows = await db
          .from('home_layout_config')
          .select()
          .eq('visible', true)
          .order('sort_order')
          .limit(50);
      if (homeRows.isNotEmpty) {
        _homeSections = List<Map<String, dynamic>>.from(homeRows);
      }

      // Persist cache.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cacheKeyCategories, _encodeCategories(_categories));
      await prefs.setString(_cacheKeyHome, jsonEncode(_homeSections));
      await prefs.setInt(_cacheKeyTs, DateTime.now().millisecondsSinceEpoch);
      debugPrint('[RemoteConfig] Refreshed: ${_categories.length} categories');
    } catch (e) {
      debugPrint('[RemoteConfig] refresh error (keeping cache): $e');
    }
  }

  // ── encoding helpers ───────────────────────────────────────────────────
  static String _encodeCategories(List<DiscoveryCategory> list) => jsonEncode(
        list
            .map(
              (c) => {
                'id': c.id,
                'label': c.label,
                'icon': c.icon,
                'query': c.query,
                'fallbackCategory': c.fallbackCategory,
              },
            )
            .toList(),
      );

  static List<DiscoveryCategory> _decodeCategories(String json) {
    try {
      final data = jsonDecode(json) as List;
      return data
          .map(
            (e) => DiscoveryCategory(
              id: (e['id'] as String?) ?? '',
              label: (e['label'] as String?) ?? '',
              icon: (e['icon'] as String?) ?? '🎵',
              query: (e['query'] as String?) ?? '',
              fallbackCategory: (e['fallbackCategory'] as String?) ?? 'global',
            ),
          )
          .toList();
    } catch (_) {
      return kDiscoveryCategories;
    }
  }

  static List<Map<String, dynamic>> _decodeHome(String json) {
    try {
      final data = jsonDecode(json) as List;
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }
}
