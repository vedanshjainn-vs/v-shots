// ════════════════════════════════════════════════
// Project Lyra — Background Job
// ════════════════════════════════════════════════
//
// Defines a background job that can run:
// - Periodically (e.g., sync every 15 min)
// - On connectivity change
// - On app lifecycle events
// - On-demand
// ════════════════════════════════════════════════

/// Type of background job.
enum BackgroundJobType {
  /// Runs on a periodic schedule.
  periodic,

  /// Runs when connectivity is restored.
  onConnectivity,

  /// Runs when app comes to foreground.
  onAppResume,

  /// Runs once on-demand.
  oneTime,

  /// Runs on a specific event.
  onEvent,
}

/// Status of a background job.
enum BackgroundJobStatus {
  idle,
  queued,
  running,
  completed,
  failed,
  cancelled,
}

/// A background job definition.
class BackgroundJob {
  const BackgroundJob({
    required this.id,
    required this.name,
    required this.type,
    this.interval,
    this.status = BackgroundJobStatus.idle,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.lastRunAt,
    this.nextRunAt,
    this.error,
    this.data = const {},
  });

  final String id;
  final String name;
  final BackgroundJobType type;
  final Duration? interval;
  final BackgroundJobStatus status;
  final int retryCount;
  final int maxRetries;
  final DateTime? lastRunAt;
  final DateTime? nextRunAt;
  final String? error;
  final Map<String, dynamic> data;

  bool get canRetry => retryCount < maxRetries;
  bool get isDue => nextRunAt != null && DateTime.now().isAfter(nextRunAt!);

  BackgroundJob copyWith({
    BackgroundJobStatus? status,
    int? retryCount,
    DateTime? lastRunAt,
    DateTime? nextRunAt,
    String? error,
  }) {
    return BackgroundJob(
      id: id,
      name: name,
      type: type,
      interval: interval,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      error: error ?? this.error,
      data: data,
    );
  }
}

/// A function that executes a background job.
typedef BackgroundJobRunner = Future<void> Function(BackgroundJob job);
