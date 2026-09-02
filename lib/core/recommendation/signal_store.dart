// ════════════════════════════════════════════════
// V Shots — Recommendation Engine: Signal persistence (Phase 7, Part I)
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

  /// Bumped after every persisted signal so only recommendation surfaces
  /// that depend on taste can refresh. Home/Discover no longer need a global
  /// screen rebuild just because one signal changed.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

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
      debugPrint('[SignalStore] Failed to initialize: $e');
    }
  }

  Future<void> record(SignalEvent event) async {
    _events.add(event);
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }
    await _persist();
    revision.value++;
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(_events.map((e) => e.toJson()).toList());
    await _prefs?.setString(_kEvents, encoded);
  }

  Future<void> clear() async {
    _events.clear();
    await _prefs?.remove(_kEvents);
    revision.value++;
  }
}
