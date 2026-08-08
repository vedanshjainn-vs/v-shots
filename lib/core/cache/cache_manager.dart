class CacheManager {
  final Map<String, String> _store = {};

  String? getRaw(CacheKey key) => _store[key.value];

  Future<void> putRaw(String key, String data, {Duration? ttl}) async {
    _store[key] = data;
  }

  Future<void> put<T>({
    required CacheKey key,
    required T data,
    required Map<String, dynamic> Function(T) toJson,
    Duration? ttl,
  }) async {
    // Simplified - just store as string
  }

  Future<void> invalidate(CacheKey key) async {
    _store.remove(key.value);
  }

  Future<void> invalidateNamespace(String namespace) async {
    _store.removeWhere((k, v) => k.startsWith('$namespace:'));
  }
}

class CacheKey {
  const CacheKey({required this.namespace, required this.id});
  final String namespace;
  final String id;
  String get value => '$namespace:$id';
}
