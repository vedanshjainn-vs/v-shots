// ════════════════════════════════════════════════
// Project Lyra — Sync Manager
// ════════════════════════════════════════════════
//
// Orchestrates offline-first synchronization.
// Queues operations when offline, replays when online.
// Handles conflict resolution and retry logic.
// ════════════════════════════════════════════════

import 'dart:async';

import '../../enums/connection_status.dart';
import '../../logging/app_logger.dart';
import '../conflict/conflict_resolver.dart';
import '../queue/sync_operation.dart';

/// Manages offline-first synchronization.
///
/// Queues operations performed while offline and
/// replays them when connectivity is restored.
///
/// ```dart
/// final sync = SyncManager();
/// await sync.initialize();
///
/// // Queue an operation.
/// await sync.enqueue(SyncOperation(
///   id: '1',
///   type: SyncOperationType.like,
///   entityType: 'track',
///   entityId: 'track_123',
/// ));
/// ```
class SyncManager {
  SyncManager({
    this.conflictResolver,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final ConflictResolver? conflictResolver;
  final AppLogger _logger;

  /// Pending sync operations.
  final List<SyncOperation> _pendingOps = [];

  /// Completed operations (for audit trail).
  final List<SyncOperation> _completedOps = [];

  /// Whether sync is currently running.
  bool _isSyncing = false;

  /// Stream of sync status changes.
  final _statusController = StreamController<SyncStatus>.broadcast();

  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Number of pending operations.
  int get pendingCount => _pendingOps.where((op) => op.isPending).length;

  /// Whether there are pending operations.
  bool get hasPending => pendingCount > 0;

  /// Initialize the sync manager.
  Future<void> initialize() async {
    // TODO(team): Load persisted operations from Hive.
    _logger.d('SyncManager: Initialized with $pendingCount pending operations');
  }

  /// Enqueue an operation for later sync.
  Future<void> enqueue(SyncOperation operation) async {
    _pendingOps.add(operation.copyWith(
      status: SyncOperationStatus.pending,
      createdAt: DateTime.now(),
    ));

    _logger.d('SyncManager: Enqueued ${operation.type.name} for ${operation.entityType}:${operation.entityId}');
    _statusController.add(SyncStatus(hasPending: true, pendingCount: pendingCount));

    // TODO(team): Persist to Hive.
  }

  /// Sync all pending operations.
  ///
  /// Called when connectivity is restored.
  Future<SyncResult> syncAll() async {
    if (_isSyncing) return SyncResult.alreadyRunning;
    if (_pendingOps.isEmpty) return SyncResult.nothingToSync;

    _isSyncing = true;
    _statusController.add(SyncStatus(isSyncing: true, pendingCount: pendingCount));

    int successCount = 0;
    int failCount = 0;

    try {
      for (final op in _pendingOps.where((op) => op.isPending).toList()) {
        try {
          // Mark as in-progress.
          _updateOp(op, SyncOperationStatus.inProgress);

          // Execute the operation.
          await _executeOperation(op);

          // Mark as completed.
          _updateOp(op, SyncOperationStatus.completed);
          _completedOps.add(op.copyWith(status: SyncOperationStatus.completed));
          successCount++;
        } catch (e) {
          failCount++;
          _logger.w('SyncManager: Operation ${op.id} failed: $e');

          if (op.canRetry) {
            _updateOp(op.copyWith(
              retryCount: op.retryCount + 1,
              error: e.toString(),
              lastAttemptAt: DateTime.now(),
            ), SyncOperationStatus.pending);
          } else {
            _updateOp(op.copyWith(error: e.toString()), SyncOperationStatus.failed);
          }
        }
      }

      // Clean up completed operations.
      _pendingOps.removeWhere((op) => op.isTerminal);

      return SyncResult(
        successCount: successCount,
        failCount: failCount,
        totalProcessed: successCount + failCount,
      );
    } finally {
      _isSyncing = false;
      _statusController.add(SyncStatus(
        hasPending: hasPending,
        pendingCount: pendingCount,
        lastSyncAt: DateTime.now(),
      ));
    }
  }

  /// Execute a single sync operation.
  Future<void> _executeOperation(SyncOperation op) async {
    // TODO(team): Implement actual API calls based on operation type.
    // switch (op.type) {
    //   case SyncOperationType.like:
    //     await api.likeTrack(op.entityId);
    //   case SyncOperationType.addToPlaylist:
    //     await api.addToPlaylist(op.entityId, op.data['playlistId']);
    //   ...
    // }

    _logger.d('SyncManager: Executing ${op.type.name} for ${op.entityType}:${op.entityId}');
  }

  void _updateOp(SyncOperation op, SyncOperationStatus status) {
    final index = _pendingOps.indexWhere((o) => o.id == op.id);
    if (index >= 0) {
      _pendingOps[index] = op.copyWith(status: status);
    }
  }

  /// Clear all pending operations.
  void clearPending() {
    _pendingOps.clear();
    _statusController.add(SyncStatus(hasPending: false, pendingCount: 0));
  }

  /// Dispose resources.
  void dispose() {
    _statusController.close();
  }
}

/// Current sync status.
class SyncStatus {
  const SyncStatus({
    this.isSyncing = false,
    this.hasPending = false,
    this.pendingCount = 0,
    this.lastSyncAt,
  });

  final bool isSyncing;
  final bool hasPending;
  final int pendingCount;
  final DateTime? lastSyncAt;
}

/// Result of a sync operation.
class SyncResult {
  const SyncResult({
    required this.successCount,
    required this.failCount,
    required this.totalProcessed,
  });

  final int successCount;
  final int failCount;
  final int totalProcessed;

  static const SyncResult alreadyRunning = SyncResult(
    successCount: 0, failCount: 0, totalProcessed: 0,
  );
  static const SyncResult nothingToSync = SyncResult(
    successCount: 0, failCount: 0, totalProcessed: 0,
  );
}
