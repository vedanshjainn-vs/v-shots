// ════════════════════════════════════════════════
// Project Lyra — Number Extensions
// ════════════════════════════════════════════════

/// Utility extensions on [num], [int], [double].
extension NumExtensions on num {
  /// Duration from seconds.
  Duration get seconds => Duration(seconds: toInt());
  Duration get milliseconds => Duration(milliseconds: toInt());
  Duration get minutes => Duration(minutes: toInt());

  /// Format as "1.2K", "3.4M", "500".
  String get compactNumber {
    if (this >= 1e9) return '${(this / 1e9).toStringAsFixed(1)}B';
    if (this >= 1e6) return '${(this / 1e6).toStringAsFixed(1)}M';
    if (this >= 1e3) return '${(this / 1e3).toStringAsFixed(1)}K';
    return toStringAsFixed(0);
  }

  /// Format as currency. "₹120.00"
  String get toCurrency => '₹${toStringAsFixed(2)}';

  /// Format as percentage. "75%"
  String get toPercentage => '${toStringAsFixed(0)}%';

  /// Clamp between 0 and 1.
  double get normalized => clamp(0.0, 1.0).toDouble();

  /// Convert seconds to "mm:ss" format.
  String get toMinutesSeconds {
    final mins = (this / 60).floor();
    final secs = (this % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Convert seconds to "h:mm:ss" or "mm:ss".
  String get toDurationString {
    final hours = (this / 3600).floor();
    final mins = ((this % 3600) / 60).floor();
    final secs = (this % 60).floor();

    if (hours > 0) {
      return '$hours:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
