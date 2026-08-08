// ════════════════════════════════════════════════
// Project Lyra — SharedPreferences Storage
// ════════════════════════════════════════════════
//
// Lightweight key-value store for settings,
// flags, and simple preferences.
// ════════════════════════════════════════════════

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';
import 'local_storage.dart';

/// SharedPreferences-backed implementation of [LocalStorage].
///
/// Use for simple key-value pairs: settings,
/// feature flags, auth tokens, onboarding state.
class SharedPrefsStorage implements LocalStorage {
  SharedPrefsStorage({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;
  final _logger = AppLogger.instance;

  /// Factory that initializes SharedPreferences.
  static Future<SharedPrefsStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPrefsStorage(prefs: prefs);
  }

  @override
  Future<String?> getString(String key) async => _prefs.getString(key);

  @override
  Future<bool> setString(String key, String value) async {
    try {
      return await _prefs.setString(key, value);
    } catch (e, st) {
      _logger.e('SharedPrefs.setString failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<int?> getInt(String key) async => _prefs.getInt(key);

  @override
  Future<bool> setInt(String key, int value) async {
    try {
      return await _prefs.setInt(key, value);
    } catch (e, st) {
      _logger.e('SharedPrefs.setInt failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<double?> getDouble(String key) async => _prefs.getDouble(key);

  @override
  Future<bool> setDouble(String key, double value) async {
    try {
      return await _prefs.setDouble(key, value);
    } catch (e, st) {
      _logger.e('SharedPrefs.setDouble failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<bool?> getBool(String key) async => _prefs.getBool(key);

  @override
  Future<bool> setBool(String key, bool value) async {
    try {
      return await _prefs.setBool(key, value);
    } catch (e, st) {
      _logger.e('SharedPrefs.setBool failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<List<String>?> getStringList(String key) async =>
      _prefs.getStringList(key);

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    try {
      return await _prefs.setStringList(key, value);
    } catch (e, st) {
      _logger.e('SharedPrefs.setStringList failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<T?> getObject<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final raw = _prefs.getString(key);
      if (raw == null) return null;
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      _logger.e('SharedPrefs.getObject failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<bool> setObject<T>(
    String key,
    T object,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      return await _prefs.setString(key, jsonEncode(toJson(object)));
    } catch (e, st) {
      _logger.e('SharedPrefs.setObject failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<bool> remove(String key) async {
    try {
      return await _prefs.remove(key);
    } catch (e, st) {
      _logger.e('SharedPrefs.remove failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<bool> clear() async {
    try {
      return await _prefs.clear();
    } catch (e, st) {
      _logger.e('SharedPrefs.clear failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<bool> containsKey(String key) async => _prefs.containsKey(key);

  @override
  Future<Set<String>> getKeys() async => _prefs.getKeys();
}
