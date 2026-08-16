// ═════════════════════════════════════════════════════════════════════════════
// V Shots — History grouper (pure, testable day-bucketing)
// ═════════════════════════════════════════════════════════════════════════════
//
// Groups listening-history entries (each with a parseable 'playedAt' ISO-8601
// timestamp) into "Today", "Yesterday", and "Earlier" buckets. Pure function —
// no widget/network dependencies — so it can be unit-tested and reused by any
// screen that shows history. Entries keep their original relative order within
// each bucket (callers pass most-recent-first).
// ═════════════════════════════════════════════════════════════════════════════

/// One day-bucket of history entries.
class HistoryGroup {
  const HistoryGroup({required this.label, required this.items});

  final String label;
  final List<Map<String, dynamic>> items;
}

/// Buckets [history] by calendar day relative to [now] (defaults to the real
/// current time; tests can pass a fixed clock for determinism). Entries whose
/// 'playedAt' is missing/unparseable fall into "Earlier".
List<HistoryGroup> groupHistoryByDay(
  List<Map<String, dynamic>> history, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final todayItems = <Map<String, dynamic>>[];
  final yesterdayItems = <Map<String, dynamic>>[];
  final earlierItems = <Map<String, dynamic>>[];

  for (final entry in history) {
    final playedAt = DateTime.tryParse((entry['playedAt'] as String?) ?? '');
    if (playedAt == null) {
      earlierItems.add(entry);
      continue;
    }
    final day = DateTime(playedAt.year, playedAt.month, playedAt.day);
    if (!day.isBefore(today)) {
      todayItems.add(entry);
    } else if (!day.isBefore(yesterday)) {
      yesterdayItems.add(entry);
    } else {
      earlierItems.add(entry);
    }
  }

  return [
    if (todayItems.isNotEmpty) HistoryGroup(label: 'Today', items: todayItems),
    if (yesterdayItems.isNotEmpty)
      HistoryGroup(label: 'Yesterday', items: yesterdayItems),
    if (earlierItems.isNotEmpty)
      HistoryGroup(label: 'Earlier', items: earlierItems),
  ];
}
