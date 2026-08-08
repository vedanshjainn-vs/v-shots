// ════════════════════════════════════════════════
// Project Lyra — Formatters
// ════════════════════════════════════════════════
//
// Display formatters for duration, file size,
// numbers, and music metadata.
// ════════════════════════════════════════════════

import 'package:intl/intl.dart';

/// Formatters for display-ready strings.
abstract final class Formatters {
  // ── Duration ─────────────────────────────────

  /// Format seconds as "mm:ss". Example: "03:45"
  static String duration(int totalSeconds) {
    final mins = (totalSeconds / 60).floor();
    final secs = (totalSeconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Format seconds as "h:mm:ss" or "mm:ss".
  static String durationLong(int totalSeconds) {
    final hours = (totalSeconds / 3600).floor();
    final mins = ((totalSeconds % 3600) / 60).floor();
    final secs = (totalSeconds % 60).floor();

    if (hours > 0) {
      return '$hours:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// "3 hr 45 min"
  static String durationReadable(int totalSeconds) {
    final hours = (totalSeconds / 3600).floor();
    final mins = ((totalSeconds % 3600) / 60).floor();

    if (hours > 0 && mins > 0) return '$hours hr $mins min';
    if (hours > 0) return '$hours hr';
    if (mins > 0) return '$mins min';
    return '< 1 min';
  }

  // ── File Size ────────────────────────────────

  /// Format bytes as "3.5 MB", "1.2 GB".
  static String fileSize(int bytes) {
    if (bytes >= 1e9) return '${(bytes / 1e9).toStringAsFixed(1)} GB';
    if (bytes >= 1e6) return '${(bytes / 1e6).toStringAsFixed(1)} MB';
    if (bytes >= 1e3) return '${(bytes / 1e3).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  // ── Numbers ──────────────────────────────────

  /// Compact number: "1.2K", "3.4M"
  static String compactNumber(num value) {
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)}B';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  /// With locale: "1,234,567"
  static String numberWithCommas(num value) {
    return NumberFormat('#,###').format(value);
  }

  // ── Music Metadata ───────────────────────────

  /// "Rock · Alternative · Indie"
  static String genres(List<String> genres) {
    return genres.take(3).join(' · ');
  }

  /// "Artist1, Artist2, Artist3"
  static String artists(List<String> artists) {
    return artists.take(3).join(', ');
  }

  /// "128 kbps"
  static String bitrate(int kbps) => '$kbps kbps';

  /// "2024"
  static String year(DateTime date) => date.year.toString();

  /// Track number with leading zero: "03"
  static String trackNumber(int number) => number.toString().padLeft(2, '0');
}
