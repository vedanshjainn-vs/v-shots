// ════════════════════════════════════════════════
// Project Lyra — Sleep Timer Service
// ════════════════════════════════════════════════
//
// Manages sleep timer for music playback.
// Supports countdown, end-of-track, and fade-out.
// ════════════════════════════════════════════════

import 'dart:async';

import '../../logging/app_logger.dart';
import '../state/playback_models.dart';

/// Service for managing a playback sleep timer.
///
/// ```dart
/// final timer = SleepTimerService();
/// timer.start(Duration(minutes: 30));
/// timer.remainingStream.listen((remaining) => updateUI(remaining));
/// ```
class SleepTimerService {
  SleepTimerService({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  Timer? _timer;
  Duration _totalDuration = Duration.zero;
  Duration _remaining = Duration.zero;
  bool _fadeOut = false;
  bool _endOfTrack = false;

  final _stateController = StreamController<SleepTimerConfig>.broadcast();
  final _remainingController = StreamController<Duration>.broadcast();

  /// Stream of sleep timer state changes.
  Stream<SleepTimerConfig> get stateStream => _stateController.stream;

  /// Stream of remaining time (updates every second).
  Stream<Duration> get remainingStream => _remainingController.stream;

  /// Whether the timer is active.
  bool get isActive => _timer != null && _timer!.isActive;

  /// Remaining time.
  Duration get remaining => _remaining;

  /// Total timer duration.
  Duration get totalDuration => _totalDuration;

  /// Start the sleep timer.
  void start(Duration duration, {bool fadeOut = false, bool endOfTrack = false}) {
    cancel();

    _totalDuration = duration;
    _remaining = duration;
    _fadeOut = fadeOut;
    _endOfTrack = endOfTrack;
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);

    _emitState();
    _logger.d('SleepTimer: Started for $duration');
  }

  /// Cancel the sleep timer.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _remaining = Duration.zero;
    _totalDuration = Duration.zero;
    _emitState();
    _logger.d('SleepTimer: Cancelled');
  }

  /// Add time to the timer.
  void addTime(Duration duration) {
    _totalDuration += duration;
    _remaining += duration;
    _emitState();
  }

  void _onTick(Timer timer) {
    _remaining -= const Duration(seconds: 1);
    _remainingController.add(_remaining);

    if (_remaining <= Duration.zero) {
      timer.cancel();
      _timer = null;
      _logger.d('SleepTimer: Expired');
      // TODO(team): Pause playback.
      _emitState();
    }
  }

  void _emitState() {
    _stateController.add(SleepTimerConfig(
      active: isActive,
      remaining: _remaining,
      totalDuration: _totalDuration,
      fadeOut: _fadeOut,
      endOfTrack: _endOfTrack,
    ));
  }

  /// Dispose resources.
  void dispose() {
    _timer?.cancel();
    _stateController.close();
    _remainingController.close();
  }
}
