// ════════════════════════════════════════════════
// Project Lyra — Sync Operation
// ════════════════════════════════════════════════
//
// Represents a pending offline operation that
// needs to be synced when connectivity returns.
// ════════════════════════════════════════════════

import 'package:equatable/equatable.dart';

/// Type of sync operation.
enum SyncOperationType {
  create,
  update,
  delete,
  like,
  unlike,
  follow,
  unfollow,
  addToPlaylist,
  removeFromPlaylist,
  playEvent,
}

/// Status of a sync operation.
enum SyncOperationStatus {
  pending,
  inProgress,
  completed,
  failed,
  cancelled,
}

/// A pending operation to be synced with the server.
class SyncOperation extends Equatable {
  const SyncOperation({
    required this.id,
    required this.type,
    required this.entityType,
    required this.entityId,
    this.data = const {},
    this.status = SyncOperationStatus.pending,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.error,
    this.createdAt,
    this.lastAttemptAt,
  });

  final String id;
  final SyncOperationType type;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> data;
  final SyncOperationStatus status;
  final int retryCount;
  final int maxRetries;
  final String? error;
  final DateTime? createdAt;
  final DateTime? lastAttemptAt;

  bool get canRetry => retryCount < maxRetries;
  bool get isPending => status == SyncOperationStatus.pending;
  bool get isTerminal =>
      status == SyncOperationStatus.completed ||
      status == SyncOperationStatus.cancelled;

  SyncOperation copyWith({
    SyncOperationStatus? status,
    int? retryCount,
    String? error,
    DateTime? lastAttemptAt,
  }) {
    return SyncOperation(
      id: id,
      type: type,
      entityType: entityType,
      entityId: entityId,
      data: data,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries,
      error: error ?? this.error,
      createdAt: createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'entityType': entityType,
        'entityId': entityId,
        'data': data,
        'status': status.name,
        'retryCount': retryCount,
        'maxRetries': maxRetries,
        'error': error,
        'createdAt': createdAt?.toIso8601String(),
        'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      type: SyncOperationType.values.byName(json['type'] as String),
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      status: SyncOperationStatus.values.byName(json['status'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      maxRetries: json['maxRetries'] as int? ?? 3,
      error: json['error'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, type, entityId, status, retryCount];
}
