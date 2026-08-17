// ═════════════════════════════════════════════════════════════════════════════
// V Shots — MusicSeenStore (decaying seen-item memory)
// ═════════════════════════════════════════════════════════════════════════════
//
// Remembers which canonical songs the user has recently been shown — NOT to
// hide them forever, but to apply a DECAYING penalty so great songs return
// naturally (just-played = strong, ~7 days = ~nothing).
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicSeenStore {
  MusicSeenStore();

  static const _kSeen = 'v_shots.music_seen.v1';
  static const _kCounts = 'v_shots.music_seen_counts.v1';

  final Map<String, DateTime> _lastSeen = {};
  final Map<String, int> _counts = {};
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final lastRaw = _prefs?.getString(_kSeen);
      if (lastRaw != null && lastRaw.isNotEmpty) {
        final decoded = jsonDecode(lastRaw) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          final ts = DateTime.tryParse(v as String? ?? '');
          if (ts != null) _lastSeen[k] = ts;
        });
      }
      final countsRaw = _prefs?.getString(_kCounts);
      if (countsRaw != null && countsRaw.isNotEmpty) {
        final decoded = jsonDecode(countsRaw) as Map<String, dynamic>;
        decoded.forEach((k, v) => _counts[k] = v as int? ?? 0);
      }
    } catch (e) {
      debugPrint('[MusicSeenStore] init failed: $e');
    }
  }

  Future<void> record(String canonicalSongId) async {
    if (canonicalSongId.isEmpty) return;
    _lastSeen[canonicalSongId] = DateTime.now();
    _counts[canonicalSongId] = (_counts[canonicalSongId] ?? 0) + 1;
    await _persist();
  }

  /// Test-only: seed a past "last seen" time to verify the decay curve.
  @visibleForTesting
  void debugSetLastSeen(String canonicalSongId, DateTime at) {
    _lastSeen[canonicalSongId] = at;
    _counts[canonicalSongId] = (_counts[canonicalSongId] ?? 0) + 1;
  }

  bool hasSeen(String canonicalSongId) =>
      _lastSeen.containsKey(canonicalSongId);

  int timesSeen(String canonicalSongId) => _counts[canonicalSongId] ?? 0;

  DateTime? lastSeen(String canonicalSongId) => _lastSeen[canonicalSongId];

  /// Decaying penalty in [0,1]: 1.0 right after play, ~0.5 after 24h, ~0.125
  /// after 3 days, ~0.008 after 7 days. Never permanently hides a song.
  double penalty(String canonicalSongId, {DateTime? now}) {
    final last = _lastSeen[canonicalSongId];
    if (last == null) return 0;
    final hours = (now ?? DateTime.now()).difference(last).inMinutes / 60.0;
    return pow(0.5, hours / 24.0).toDouble().clamp(0.0, 1.0);
  }

  Future<void> _persist() async {
    try {
      await _prefs?.setString(
        _kSeen,
        jsonEncode(_lastSeen.map((k, v) => MapEntry(k, v.toIso8601String()))),
      );
      await _prefs?.setString(_kCounts, jsonEncode(_counts));
    } catch (_) {}
  }
}
