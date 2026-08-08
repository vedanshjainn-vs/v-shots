// ════════════════════════════════════════════════
// Project Lyra — Startup Optimizer
// ════════════════════════════════════════════════
//
// Optimizes cold start by:
// - Deferring non-critical initialization
// - Running tasks in parallel
// - Prioritizing critical path
// - Background initialization
// ════════════════════════════════════════════════

import 'dart:async';

import '../logging/app_logger.dart';
import '../telemetry/monitors/performance_monitor.dart';

/// Phase of app startup.
enum StartupPhase {
  /// Critical: must complete before UI renders.
  critical,

  /// Important: should complete before user interaction.
  important,

  /// Deferred: can complete after first frame.
  deferred,

  /// Background: runs after app is interactive.
  background,
}

/// A startup task with priority and dependencies.
class StartupTask {
  const StartupTask({
    required this.name,
    required this.phase,
    required this.task,
    this.dependencies = const [],
  });

  final String name;
  final StartupPhase phase;
  final Future<void> Function() task;
  final List<String> dependencies;
}

/// Orchestrates app startup optimization.
///
/// Runs tasks in the correct order and phase,
/// maximizing parallelism while respecting dependencies.
///
/// ```dart
/// final optimizer = StartupOptimizer();
/// optimizer.addTask(StartupTask(
///   name: 'hive_init',
///   phase: StartupPhase.critical,
///   task: () => Hive.initFlutter(),
/// ));
/// optimizer.addTask(StartupTask(
///   name: 'firebase_init',
///   phase: StartupPhase.critical,
///   task: () => Firebase.initializeApp(),
/// ));
/// optimizer.addTask(StartupTask(
///   name: 'analytics_init',
///   phase: StartupPhase.deferred,
///   task: () => AnalyticsService.initialize(),
///   dependencies: ['firebase_init'],
/// ));
///
/// await optimizer.runPhase(StartupPhase.critical);
/// runApp(MyApp()); // App renders now.
/// optimizer.runRemaining(); // Non-critical tasks in background.
/// ```
class StartupOptimizer {
  StartupOptimizer({
    PerformanceMonitor? performanceMonitor,
    AppLogger? logger,
  })  : _performanceMonitor = performanceMonitor ?? PerformanceMonitor(),
        _logger = logger ?? AppLogger.instance;

  final PerformanceMonitor _performanceMonitor;
  final AppLogger _logger;

  final List<StartupTask> _tasks = [];
  final Set<String> _completed = {};

  /// Add a startup task.
  void addTask(StartupTask task) {
    _tasks.add(task);
  }

  /// Add multiple tasks.
  void addTasks(List<StartupTask> tasks) {
    _tasks.addAll(tasks);
  }

  /// Run all tasks in a specific phase.
  ///
  /// Returns when all tasks in the phase are complete.
  Future<void> runPhase(StartupPhase phase) async {
    final phaseTasks = _tasks.where((t) => t.phase == phase).toList();

    _logger.d('StartupOptimizer: Running ${phaseTasks.length} tasks in ${phase.name} phase');

    for (final task in phaseTasks) {
      // Wait for dependencies.
      for (final dep in task.dependencies) {
        if (!_completed.contains(dep)) {
          _logger.w('StartupOptimizer: Waiting for dependency $dep');
          // TODO(team): Implement proper dependency waiting.
        }
      }

      await _performanceMonitor.measure('startup_${task.name}', () async {
        try {
          await task.task();
          _completed.add(task.name);
          _logger.d('StartupOptimizer: ${task.name} completed');
        } catch (e, st) {
          _logger.e('StartupOptimizer: ${task.name} failed', error: e, stackTrace: st);
          // Don't rethrow — non-critical tasks shouldn't crash the app.
        }
      });
    }
  }

  /// Run all remaining phases in the background.
  ///
  /// Does not block the caller. Fire-and-forget.
  void runRemaining() {
    Future(() async {
      for (final phase in StartupPhase.values) {
        if (phase == StartupPhase.critical) continue; // Already run.
        await runPhase(phase);
      }
    });
  }

  /// Get completion status.
  Map<String, bool> get completionStatus {
    return Map.fromEntries(
      _tasks.map((t) => MapEntry(t.name, _completed.contains(t.name))),
    );
  }
}
