// ════════════════════════════════════════════════
// V Shots — Recommendation Engine: Signal persistence (Phase 7, Part I)
// ════════════════════════════════════════════════
//
// Persists a rolling window of `SignalEvent`s via shared_preferences —
// same storage technology `LocalLibrary` already uses (no new
// dependency, matches this app's established "no server required"
// local-persistence pattern). Deliberately capped ([_maxEvents]) so
// this doesn't grow unbounded over a long-running install — old
// events age out in favor of new ones, since recency dominates the
// scoring model anyway (see taste_profile.dart's recency weighting).
// ════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'signal_event.dart';

class SignalStore {
  SignalStore._();
  static final SignalStore instance = SignalStore._();

  static const _kEvents = 'v_shots.recommendation_signals.v1';
  static const int _maxEvents = 2000;

  SharedPreferences? _prefs;
  final List<SignalEvent> _events = [];
  bool _ready = false;

  List<SignalEvent> get events => List.unmodifiable(_events);

  Future<void> initialize() async {
    if (_ready) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_kEvents);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _events.addAll(
          decoded.map((e) => SignalEvent.fromJson(e as Map<String, dynamic>)),
        );
      }
      _ready = true;
      debugPrint('[SignalStore] Loaded ${_events.length} signal events.');
    } catch (e) {
      // Same "never block app startup" contract as LocalLibrary's own
      // initialize() — a corrupt/missing signal history must not
      // prevent playback; recommendations just fall back to cold-start
      // behavior (see candidate_generator.dart's cold-start path).
      debugPrint('[SignalStore] Failed to initialize: $e');
    }
  }

  Future<void> record(SignalEvent event) async {
    _events.add(event);
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }
    await _persist();
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(_events.map((e) => e.toJson()).toList());
    await _prefs?.setString(_kEvents, encoded);
  }

  /// Test/debug helper — clears all recorded signals.
  Future<void> clear() async {
    _events.clear();
    await _prefs?.remove(_kEvents);
  }
}
