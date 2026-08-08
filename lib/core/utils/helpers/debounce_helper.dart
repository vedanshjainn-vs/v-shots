// ════════════════════════════════════════════════
// Project Lyra — Debounce Helper
// ════════════════════════════════════════════════
//
// Debounce and throttle utilities for search,
// scroll handlers, and rapid user input.
// ════════════════════════════════════════════════

import 'dart:async';

/// Debounces function calls by a specified duration.
///
/// Only the last call within the debounce window is executed.
/// Ideal for search-as-you-type.
///
/// ```dart
/// final debounce = Debouncer(milliseconds: 400);
/// onChanged: (query) => debounce.run(() => search(query));
/// ```
class Debouncer {
  Debouncer({this.milliseconds = 400});

  final int milliseconds;
  Timer? _timer;

  /// Schedule [action] to run after [milliseconds].
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  /// Cancel any pending action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Whether a call is currently pending.
  bool get isActive => _timer?.isActive ?? false;

  void dispose() => cancel();
}

/// Throttles function calls — executes at most once per duration.
///
/// ```dart
/// final throttle = Throttler(milliseconds: 200);
/// onScroll: () => throttle.run(() => handleScroll());
/// ```
class Throttler {
  Throttler({this.milliseconds = 200});

  final int milliseconds;
  bool _isThrottled = false;

  void run(void Function() action) {
    if (_isThrottled) return;
    _isThrottled = true;
    action();
    Timer(Duration(milliseconds: milliseconds), () {
      _isThrottled = false;
    });
  }
}
