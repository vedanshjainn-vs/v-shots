// ════════════════════════════════════════════════
// Project Lyra — Hive Storage Implementation
// ════════════════════════════════════════════════
//
// Hive-based local storage for complex objects,
// caching, and offline-first data.
// ════════════════════════════════════════════════

import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../logging/app_logger.dart';
import 'local_storage.dart';

/// Hive-backed implementation of [LocalStorage].
///
/// Use for structured data, offline caches, and
/// large datasets that need fast read/write.
class HiveStorage implements LocalStorage {
  HiveStorage({required Box<dynamic> box}) : _box = box;

  final Box<dynamic> _box;
  final _logger = AppLogger.instance;

  /// Opens a named Hive box.
  static Future<HiveStorage> open(String boxName) async {
    final box = await Hive.openBox<dynamic>(boxName);
    return HiveStorage(box: box);
  }

  @override
  Future<String?> getString(String key) async {
    try {
      return _box.get(key) as String?;
    } catch (e, st) {
      _logger.e('HiveStorage.getString failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<bool> setString(String key, String value) async {
    try {
      await _box.put(key, value);
      return true;
    } catch (e, st) {
      _logger.e('HiveStorage.setString failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<int?> getInt(String key) async {
    try {
      return _box.get(key) as int?;
    } catch (e, st) {
      _logger.e('HiveStorage.getInt failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<bool> setInt(String key, int value) async {
    try {
      await _box.put(key, value);
      return true;
    } catch (e, st) {
      _logger.e('HiveStorage.setInt failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<double?> getDouble(String key) async {
    try {
      return _box.get(key) as double?;
    } catch (e, st) {
      _logger.e('HiveStorage.getDouble failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    try {
      await _box.put(key, value);
      return true;
    } catch (e, st) {
      _logger.e('HiveStorage.setDouble failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<bool?> getBool(String key) async {
    try {
      return _box.get(key) as bool?;
    } catch (e, st) {
      _logger.e('HiveStorage.getBool failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    try {
      await _box.put(key, value);
      return true;
    } catch (e, st) {
      _logger.e('HiveStorage.setBool failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    try {
      final raw = _box.get(key);
      if (raw is List) return raw.cast<String>();
      if (raw is String) return (jsonDecode(raw) as List).cast<String>();
      return null;
    } catch (e, st) {
      _logger.e('HiveStorage.getStringList failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    try {
      await _box.put(key, jsonEncode(value));
      return true;
    } catch (e, st) {
      _logger.e('HiveStorage.setStringList failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<T?> getObject<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final raw = _box.get(key);
      if (raw == null) return null;
      if (raw is Map) return fromJson(Map<String, dynamic>.from(raw));
      if (raw is String) return fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return null;
    } catch (e, st) {
      _logger.e('HiveStorage.getObject failed', error: e, stackTrace: st);
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
      await _box.put(key, toJson(object));
      return true;
    } catch (e, st) {
      _logger.e('HiveStorage.setObject failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<bool> remove(String key) async {
    try {
      await _box.delete(key);
      return true;
    } catch (e, st) {
      _logger.e('HiveStorage.remove failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<bool> clear() async {
    try {
      await _box.clear();
      return true;
    } catch (e, st) {
      _logger.e('HiveStorage.clear failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<bool> containsKey(String key) async => _box.containsKey(key);

  @override
  Future<Set<String>> getKeys() async => _box.keys.cast<String>().toSet();
}
