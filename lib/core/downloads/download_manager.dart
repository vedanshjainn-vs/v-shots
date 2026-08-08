// ════════════════════════════════════════════════
// Project Lyra — Download Manager
// ════════════════════════════════════════════════
//
// Central download orchestrator.
// Manages queue, scheduling, retry, and persistence.
// Supports concurrent downloads with priority ordering.
// ════════════════════════════════════════════════

import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';

import '../enums/connection_status.dart';
import '../logging/app_logger.dart';
import 'download_status.dart';
import 'download_task.dart';

/// Central download manager.
///
/// Manages a priority queue of download tasks with
/// concurrent execution, retry logic, and progress tracking.
///
/// ```dart
/// final manager = DownloadManager(dio: dio);
/// await manager.initialize();
///
/// // Queue a download.
/// final task = DownloadTask(id: '1', url: '...', type: DownloadType.track, title: 'Song');
/// manager.enqueue(task);
///
/// // Listen to progress.
/// manager.progressStream('1').listen((task) => print(task.progress));
/// ```
class DownloadManager {
  DownloadManager({
    required this.dio,
    this.maxConcurrent = 3,
    this.wifiOnly = false,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final Dio dio;
  final int maxConcurrent;
  final bool wifiOnly;
  final AppLogger _logger;

  /// Priority queue of download tasks.
  final SplayTreeSet<DownloadTask> _queue = SplayTreeSet(
    (a, b) => b.priority.value.compareTo(a.priority.value),
  );

  /// Active downloads (task ID → cancel token).
  final Map<String, CancelToken> _activeTokens = {};

  /// All known tasks (task ID → task).
  final Map<String, DownloadTask> _tasks = {};

  /// Stream controllers for task updates.
  final Map<String, StreamController<DownloadTask>> _taskControllers = {};

  /// Global task updates.
  final _globalController = StreamController<DownloadTask>.broadcast();

  bool _isInitialized = false;
  bool _isPaused = false;

  // ── Initialization ───────────────────────────

  /// Initialize the download manager.
  ///
  /// Loads persisted tasks from storage and resumes
  /// any incomplete downloads.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // TODO(team): Load persisted tasks from Hive.
    _isInitialized = true;
    _logger.d('DownloadManager: Initialized');
  }

  /// Dispose all resources.
  void dispose() {
    for (final controller in _taskControllers.values) {
      controller.close();
    }
    _taskControllers.clear();
    _globalController.close();
  }

  // ── Queue Operations ─────────────────────────

  /// Enqueue a new download task.
  Future<void> enqueue(DownloadTask task) async {
    _tasks[task.id] = task;
    _queue.add(task);
    _taskControllers[task.id] = StreamController<DownloadTask>.broadcast();
    _globalController.add(task);

    _logger.d('DownloadManager: Enqueued ${task.title} (${task.id})');
    await _processQueue();
  }

  /// Enqueue multiple tasks.
  Future<void> enqueueAll(List<DownloadTask> tasks) async {
    for (final task in tasks) {
      _tasks[task.id] = task;
      _queue.add(task);
      _taskControllers[task.id] = StreamController<DownloadTask>.broadcast();
    }
    _globalController.add(tasks.first);
    await _processQueue();
  }

  /// Cancel a download.
  Future<void> cancel(String taskId) async {
    _activeTokens[taskId]?.cancel('User cancelled');
    _activeTokens.remove(taskId);

    _updateTask(taskId, (task) => task.copyWith(
      status: DownloadStatus.cancelled,
      completedAt: DateTime.now(),
    ));
  }

  /// Pause a download.
  Future<void> pause(String taskId) async {
    _activeTokens[taskId]?.cancel('User paused');
    _activeTokens.remove(taskId);

    _updateTask(taskId, (task) => task.copyWith(
      status: DownloadStatus.paused,
    ));
  }

  /// Resume a paused download.
  Future<void> resume(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || !task.status.canResume) return;

    _updateTask(taskId, (t) => t.copyWith(status: DownloadStatus.queued));
    await _processQueue();
  }

  /// Pause all downloads.
  void pauseAll() {
    _isPaused = true;
    for (final entry in _activeTokens.entries) {
      entry.value.cancel('All paused');
    }
  }

  /// Resume all downloads.
  void resumeAll() {
    _isPaused = false;
    _processQueue();
  }

  /// Remove a task from the queue.
  Future<void> remove(String taskId) async {
    await cancel(taskId);
    _tasks.remove(taskId);
    _taskControllers[taskId]?.close();
    _taskControllers.remove(taskId);
  }

  // ── Query Operations ─────────────────────────

  /// Get a task by ID.
  DownloadTask? getTask(String taskId) => _tasks[taskId];

  /// Get all tasks.
  List<DownloadTask> get allTasks => _tasks.values.toList();

  /// Get tasks by status.
  List<DownloadTask> getTasksByStatus(DownloadStatus status) {
    return _tasks.values.where((t) => t.status == status).toList();
  }

  /// Stream of updates for a specific task.
  Stream<DownloadTask>? taskStream(String taskId) {
    return _taskControllers[taskId]?.stream;
  }

  /// Stream of all task updates.
  Stream<DownloadTask> get globalStream => _globalController.stream;

  /// Number of active downloads.
  int get activeCount => _activeTokens.length;

  /// Whether the queue has pending tasks.
  bool get hasPendingTasks => _queue.any((t) => t.status == DownloadStatus.queued);

  // ── Queue Processing ─────────────────────────

  Future<void> _processQueue() async {
    if (_isPaused) return;

    while (_activeTokens.length < maxConcurrent && _queue.isNotEmpty) {
      final nextTask = _queue.firstWhere(
        (t) => t.status == DownloadStatus.queued,
        orElse: () => _queue.first,
      );

      if (nextTask.status != DownloadStatus.queued) break;

      _queue.remove(nextTask);
      _startDownload(nextTask);
    }
  }

  Future<void> _startDownload(DownloadTask task) async {
    final cancelToken = CancelToken();
    _activeTokens[task.id] = cancelToken;

    _updateTask(task.id, (t) => t.copyWith(
      status: DownloadStatus.downloading,
      startedAt: DateTime.now(),
    ));

    try {
      // TODO(team): Implement actual file download with progress.
      // final response = await dio.download(
      //   task.url,
      //   task.filePath,
      //   cancelToken: cancelToken,
      //   onReceiveProgress: (received, total) {
      //     _updateTask(task.id, (t) => t.copyWith(
      //       progress: total > 0 ? received / total : 0,
      //       downloadedBytes: received,
      //       totalBytes: total,
      //     ));
      //   },
      // );

      _updateTask(task.id, (t) => t.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        completedAt: DateTime.now(),
      ));
    } catch (e) {
      if (cancelToken.isCancelled) {
        // User-initiated cancel — don't retry.
        return;
      }

      _logger.e('DownloadManager: Download failed for ${task.id}', error: e);

      _updateTask(task.id, (t) => t.copyWith(
        status: t.canRetry ? DownloadStatus.failed : DownloadStatus.failed,
        error: e.toString(),
        retryCount: t.retryCount + 1,
      ));

      // Auto-retry if possible.
      if (task.retryCount < task.maxRetries) {
        _queue.add(task.copyWith(status: DownloadStatus.queued));
      }
    } finally {
      _activeTokens.remove(task.id);
      _processQueue();
    }
  }

  void _updateTask(String taskId, DownloadTask Function(DownloadTask) updater) {
    final current = _tasks[taskId];
    if (current == null) return;

    final updated = updater(current);
    _tasks[taskId] = updated;
    _taskControllers[taskId]?.add(updated);
    _globalController.add(updated);
  }
}
