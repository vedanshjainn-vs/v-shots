// ════════════════════════════════════════════════
// Project Lyra — Conflict Resolver
// ════════════════════════════════════════════════
//
// Interface for resolving data conflicts that
// occur when offline changes conflict with
// server state.
// ════════════════════════════════════════════════

/// Strategy for resolving data conflicts.
enum ConflictStrategy {
  /// Server wins — discard local changes.
  serverWins,

  /// Client wins — overwrite server with local.
  clientWins,

  /// Merge — combine both versions (feature-specific).
  merge,

  /// Manual — prompt user to resolve.
  manual,
}

/// A conflict between local and server data.
class Conflict<T> {
  const Conflict({
    required this.entityId,
    required this.entityType,
    required this.localVersion,
    required this.serverVersion,
    this.localTimestamp,
    this.serverTimestamp,
  });

  final String entityId;
  final String entityType;
  final T localVersion;
  final T serverVersion;
  final DateTime? localTimestamp;
  final DateTime? serverTimestamp;
}

/// Resolves conflicts between local and server data.
///
/// Implement this for entity-specific conflict resolution.
///
/// ```dart
/// class PlaylistConflictResolver extends ConflictResolver<Playlist> {
///   @override
///   ConflictStrategy get strategy => ConflictStrategy.merge;
///
///   @override
///   Playlist resolve(Conflict<Playlist> conflict) {
///     // Merge playlist tracks from both versions.
///     return conflict.localVersion.copyWith(
///       tracks: {...conflict.serverVersion.tracks, ...conflict.localVersion.tracks}.toList(),
///     );
///   }
/// }
/// ```
abstract class ConflictResolver<T> {
  /// The default strategy for this resolver.
  ConflictStrategy get strategy;

  /// Resolve a conflict between local and server versions.
  T resolve(Conflict<T> conflict);

  /// Check if a conflict exists between two versions.
  bool hasConflict(T local, T server);
}
