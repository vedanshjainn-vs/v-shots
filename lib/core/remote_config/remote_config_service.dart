// ═════════════════════════════════════════════════════════════════════════
// V Shots — Remote Config Service (Supabase-backed)
//
// Lets Home layout and the Discovery category list be changed WITHOUT an app
// update. A failure to reach Supabase NEVER blocks the app: cached config is
// used if present, otherwise compiled defaults.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/supabase_service.dart';
import '../config/discovery_categories.dart';
import 'home_cms_models.dart';

class RemoteConfigService {
  RemoteConfigService._();

  static final RemoteConfigService instance = RemoteConfigService._();

  static const Duration _cacheTtl = Duration(hours: 1);
  static const _cacheKeyCategories = 'rc_discovery_categories';
  static const _cacheKeyHome = 'rc_home_layout';
  static const _cacheKeyItems = 'rc_home_items';
  static const _cacheKeyFlags = 'rc_feature_flags';
  static const _cacheKeyTs = 'rc_timestamp';

  List<DiscoveryCategory> _categories = kDiscoveryCategories;
  List<DiscoveryCategory> get categories => _categories;

  List<Map<String, dynamic>> _homeSections = const [];
  List<Map<String, dynamic>> get homeSections => _homeSections;

  Map<String, List<Map<String, dynamic>>> _itemsBySection = const {};
  Map<String, List<Map<String, dynamic>>> get itemsBySection => _itemsBySection;

  Map<String, bool> _flags = const {};
  Map<String, bool> get featureFlags => _flags;

  /// When false, Home uses compiled default shelves even if CMS rows exist.
  bool get enableRemoteHome => _flags['enable_remote_home'] ?? true;

  bool _loaded = false;

  /// Loads cached config and refreshes if stale. Safe to call at startup.
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
      final itemsJson = prefs.getString(_cacheKeyItems);
      if (itemsJson != null) {
        _itemsBySection = _decodeItems(itemsJson);
      }
      final flagsJson = prefs.getString(_cacheKeyFlags);
      if (flagsJson != null) {
        _flags = _decodeFlags(flagsJson);
      }

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
        '[RemoteConfig] Supabase unavailable — keeping cached/defaults',
      );
      return;
    }
    try {
      final db = SupabaseService.client;

      final catRows = await db
          .from('discovery_categories')
          .select()
          .eq('active', true)
          .order('sort_order')
          .limit(50);
      if (catRows.isNotEmpty) {
        final parsed = <DiscoveryCategory>[];
        for (final row in catRows) {
          if (row is! Map) continue;
          final map = Map<String, dynamic>.from(row);
          final name = cmsAsString(map['name']);
          final query = cmsAsString(map['query']);
          if (name.isEmpty) continue;
          parsed.add(
            DiscoveryCategory(
              id: cmsAsString(map['id'], name),
              label: name,
              icon: cmsAsString(map['emoji'], '🎵'),
              query: query,
              fallbackCategory: cmsAsString(map['fallback_category'], 'global'),
            ),
          );
        }
        if (parsed.isNotEmpty) {
          _categories = _ensureForYouCategory(parsed);
        }
      }

      final homeRows = await db
          .from('home_layout_config')
          .select()
          .eq('visible', true)
          .eq('published', true)
          .order('sort_order')
          .limit(50);
      if (homeRows.isNotEmpty) {
        _homeSections = [
          for (final row in homeRows)
            if (row is Map) Map<String, dynamic>.from(row),
        ];
      }

      try {
        final itemRows = await db
            .from('home_section_items')
            .select()
            .eq('is_enabled', true)
            .order('sort_order')
            .limit(500);
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final row in itemRows) {
          if (row is! Map) continue;
          final map = Map<String, dynamic>.from(row);
          final sectionId = cmsAsString(map['section_id']);
          if (sectionId.isEmpty) continue;
          grouped.putIfAbsent(sectionId, () => []).add(map);
        }
        _itemsBySection = grouped;
      } catch (e) {
        debugPrint('[RemoteConfig] items fetch skipped: $e');
      }

      try {
        final flagRows = await db.from('feature_flags').select().limit(50);
        final flags = <String, bool>{};
        for (final row in flagRows) {
          final map = Map<String, dynamic>.from(row as Map);
          final key = cmsAsString(map['key']);
          if (key.isEmpty) continue;
          flags[key] = cmsAsBool(map['value'], fallback: false);
        }
        if (flags.isNotEmpty) _flags = flags;
      } catch (e) {
        debugPrint('[RemoteConfig] flags fetch skipped: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKeyCategories,
        _encodeCategories(_categories),
      );
      await prefs.setString(_cacheKeyHome, jsonEncode(_homeSections));
      await prefs.setString(_cacheKeyItems, jsonEncode(_itemsBySection));
      await prefs.setString(_cacheKeyFlags, jsonEncode(_flags));
      await prefs.setInt(_cacheKeyTs, DateTime.now().millisecondsSinceEpoch);
      debugPrint(
        '[RemoteConfig] Refreshed: ${_homeSections.length} home sections, '
        '${_categories.length} categories',
      );
    } catch (e) {
      debugPrint('[RemoteConfig] refresh error (keeping cache): $e');
    }
  }

  /// Test-only: inject CMS rows without hitting Supabase.
  @visibleForTesting
  void debugSetHome({
    List<Map<String, dynamic>> sections = const [],
    Map<String, List<Map<String, dynamic>>> items = const {},
    bool enableRemote = true,
  }) {
    _homeSections = sections;
    _itemsBySection = items;
    _flags = {..._flags, 'enable_remote_home': enableRemote};
  }

  static List<DiscoveryCategory> _ensureForYouCategory(
    List<DiscoveryCategory> parsed,
  ) {
    final hasForYou = parsed.any(
      (c) => c.id == 'for_you' || c.query.isEmpty,
    );
    if (hasForYou) return parsed;
    return [
      const DiscoveryCategory(
        id: 'for_you',
        label: 'For You',
        icon: '✨',
        query: '',
        fallbackCategory: 'global',
      ),
      ...parsed,
    ];
  }

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
      final data = jsonDecode(json) as List<dynamic>;
      return data.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return DiscoveryCategory(
          id: cmsAsString(map['id']),
          label: cmsAsString(map['label']),
          icon: cmsAsString(map['icon'], '🎵'),
          query: cmsAsString(map['query']),
          fallbackCategory: cmsAsString(map['fallbackCategory'], 'global'),
        );
      }).toList();
    } catch (_) {
      return kDiscoveryCategories;
    }
  }

  static List<Map<String, dynamic>> _decodeHome(String json) {
    try {
      final data = jsonDecode(json) as List<dynamic>;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return const [];
    }
  }

  static Map<String, List<Map<String, dynamic>>> _decodeItems(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return data.map((key, value) {
        final list = (value as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return MapEntry(key, list);
      });
    } catch (_) {
      return const {};
    }
  }

  static Map<String, bool> _decodeFlags(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return data.map((key, value) => MapEntry(key, cmsAsBool(value)));
    } catch (_) {
      return const {};
    }
  }
}
