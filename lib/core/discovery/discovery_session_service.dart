import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistent discovery memory: hard exclusion for the current session and a
/// rolling category-specific exclusion across sessions. This is intentionally
/// independent from the UI and can be unit-tested/reused by Home.
class DiscoverySessionService {
  DiscoverySessionService._();
  static final instance = DiscoverySessionService._();

  static const _key = 'v_shots.discovery_history.v1';
  SharedPreferences? _prefs;
  String sessionId = '';
  final Map<String, Set<String>> _history = {};
  final Set<String> currentSessionSeen = {};

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in map.entries) {
          _history[entry.key] = (entry.value as List).cast<String>().toSet();
        }
      } catch (_) {}
    }
    startSession();
  }

  void startSession() {
    sessionId = '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
    currentSessionSeen.clear();
  }

  Set<String> exclusionsFor(String category) => {
        ...(_history[category] ?? const <String>{}),
        ...currentSessionSeen,
      };

  Future<void> recordShown(String category, Iterable<String> ids) async {
    final bucket = _history.putIfAbsent(category, () => <String>{});
    for (final id in ids) {
      if (id.isEmpty) continue;
      bucket.add(id);
      currentSessionSeen.add(id);
    }
    // Keep history bounded; old tracks are allowed to return naturally.
    if (bucket.length > 300) {
      final values = bucket.toList();
      bucket
        ..clear()
        ..addAll(values.skip(values.length - 300));
    }
    await _prefs?.setString(_key, jsonEncode({
      for (final e in _history.entries) e.key: e.value.toList(),
    }));
  }

  Future<void> recordSkipped(String category, String id) =>
      recordShown(category, [id]);
}
