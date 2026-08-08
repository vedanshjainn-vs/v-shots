// ════════════════════════════════════════════════
// Project Lyra — Local Storage Interface
// ════════════════════════════════════════════════
//
// Abstract interface for local persistence.
// Implementations: HiveStorage, SharedPrefsStorage.
// Allows swapping backends without changing callers.
// ════════════════════════════════════════════════

/// Abstract local storage contract.
///
/// Feature modules depend on this interface,
/// not on a concrete implementation.
/// Injected via Riverpod.
abstract class LocalStorage {
  // ── String ───────────────────────────────────
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);

  // ── Int ──────────────────────────────────────
  Future<int?> getInt(String key);
  Future<bool> setInt(String key, int value);

  // ── Double ───────────────────────────────────
  Future<double?> getDouble(String key);
  Future<bool> setDouble(String key, double value);

  // ── Bool ─────────────────────────────────────
  Future<bool?> getBool(String key);
  Future<bool> setBool(String key, bool value);

  // ── List<String> ─────────────────────────────
  Future<List<String>?> getStringList(String key);
  Future<bool> setStringList(String key, List<String> value);

  // ── Object (JSON-serializable) ───────────────
  Future<T?> getObject<T>(String key, T Function(Map<String, dynamic>) fromJson);
  Future<bool> setObject<T>(String key, T object, Map<String, dynamic> Function(T) toJson);

  // ── Management ───────────────────────────────
  Future<bool> remove(String key);
  Future<bool> clear();
  Future<bool> containsKey(String key);
  Future<Set<String>> getKeys();
}
