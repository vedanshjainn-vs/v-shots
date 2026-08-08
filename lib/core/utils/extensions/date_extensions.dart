// ════════════════════════════════════════════════
// Project Lyra — Date Extensions
// ════════════════════════════════════════════════

import 'package:intl/intl.dart';

/// Utility extensions on [DateTime].
extension DateExtensions on DateTime {
  /// "2 hours ago", "Yesterday", "3 days ago"
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  /// "Jan 15, 2024"
  String get formattedDate => DateFormat.yMMMd().format(this);

  /// "15 Jan 2024"
  String get formattedDateLong => DateFormat.yMMMMd().format(this);

  /// "10:30 AM"
  String get formattedTime => DateFormat.jm().format(this);

  /// "Jan 15, 2024 at 10:30 AM"
  String get formattedDateTime => DateFormat.yMMMd().add_jm().format(this);

  /// "2024-01-15"
  String get isoDate => DateFormat('yyyy-MM-dd').format(this);

  /// Whether this date is today.
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Whether this date is yesterday.
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Start of day (00:00:00).
  DateTime get startOfDay => DateTime(year, month, day);

  /// End of day (23:59:59).
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);
}
