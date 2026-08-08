// ════════════════════════════════════════════════
// Project Lyra — Application Event Bus
// ════════════════════════════════════════════════
//
// Type-safe, decoupled event system.
// Features communicate without direct dependencies.
// ════════════════════════════════════════════════

import 'dart:async';

import '../../logging/app_logger.dart';
import '../types/app_event.dart';

/// Central event bus for decoupled feature communication.
///
/// Features publish and subscribe to typed events
/// without knowing about each other.
///
/// ```dart
/// // Subscribe.
/// eventBus.on<TrackPlayedEvent>((event) => updateUI(event.track));
///
/// // Publish.
/// eventBus.emit(TrackPlayedEvent(trackId: '123'));
/// ```
class AppEventBus {
  AppEventBus({AppLogger? logger}) : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;
  final _controller = StreamController<AppEvent>.broadcast();

  /// Stream of all events.
  Stream<AppEvent> get stream => _controller.stream;

  /// Emit an event to all listeners.
  void emit(AppEvent event) {
    _logger.d('EventBus: ${event.runtimeType}');
    _controller.add(event);
  }

  /// Listen to events of a specific type.
  ///
  /// Returns a [StreamSubscription] that can be cancelled.
  StreamSubscription<T> on<T extends AppEvent>(
    void Function(T event) handler,
  ) {
    return _controller.stream
        .where((event) => event is T)
        .cast<T>()
        .listen(handler);
  }

  /// Listen to events of a specific type with error handling.
  StreamSubscription<T> onSafe<T extends AppEvent>(
    void Function(T event) handler, {
    void Function(Object error, StackTrace stack)? onError,
  }) {
    return _controller.stream
        .where((event) => event is T)
        .cast<T>()
        .listen(handler, onError: onError ?? (e, st) {
      _logger.e('EventBus: Error handling ${T.toString()}', error: e, stackTrace: st);
    });
  }

  /// Get a filtered stream of a specific event type.
  Stream<T> where<T extends AppEvent>() {
    return _controller.stream.where((event) => event is T).cast<T>();
  }

  /// Dispose the event bus.
  void dispose() {
    _controller.close();
  }
}
