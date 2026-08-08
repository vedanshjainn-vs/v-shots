// ════════════════════════════════════════════════
// Project Lyra — Cache Key
// ════════════════════════════════════════════════
//
// Typed, namespaced cache keys that prevent
// collisions and support structured invalidation.
// ════════════════════════════════════════════════

/// A structured, namespaced cache key.
///
/// Keys are composed of a [namespace] (e.g., 'tracks', 'albums')
/// and an [identifier] (e.g., track ID). This prevents collisions
/// and supports bulk invalidation by namespace.
///
/// ```dart
/// final key = CacheKey(namespace: 'tracks', id: 'abc123');
/// print(key.value); // 'tracks:abc123'
/// ```
class CacheKey {
  /// Creates a cache key with a namespace and identifier.
  const CacheKey({
    required this.namespace,
    required this.id,
  });

  /// Namespace groups related keys (e.g., 'tracks', 'user_profile').
  final String namespace;

  /// Unique identifier within the namespace.
  final String id;

  /// The full cache key string: `namespace:id`.
  String get value => '$namespace:$id';

  /// Creates a key for a list/collection in a namespace.
  factory CacheKey.collection(String namespace, {String? query}) {
    return CacheKey(
      namespace: namespace,
      id: query != null ? 'list:$query' : 'list',
    );
  }

  /// Creates a key for a single item.
  factory CacheKey.item(String namespace, String id) {
    return CacheKey(namespace: namespace, id: id);
  }

  /// Creates a key for search results.
  factory CacheKey.search(String query) {
    return CacheKey(namespace: 'search', id: query.toLowerCase().trim());
  }

  /// Creates a key for user-specific data.
  factory CacheKey.userScoped(String userId, String namespace, String id) {
    return CacheKey(namespace: 'user:$userId:$namespace', id: id);
  }

  /// Pattern for bulk invalidation of a namespace.
  String get namespacePattern => '$namespace:*';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheKey &&
          runtimeType == other.runtimeType &&
          namespace == other.namespace &&
          id == other.id;

  @override
  int get hashCode => namespace.hashCode ^ id.hashCode;

  @override
  String toString() => value;
}

/// Well-known cache key namespaces.
abstract final class CacheNamespaces {
  static const String tracks = 'tracks';
  static const String albums = 'albums';
  static const String artists = 'artists';
  static const String playlists = 'playlists';
  static const String podcasts = 'podcasts';
  static const String audiobooks = 'audiobooks';
  static const String search = 'search';
  static const String recommendations = 'recommendations';
  static const String userProfile = 'user_profile';
  static const String settings = 'settings';
  static const String library = 'library';
  static const String feed = 'feed';
}
