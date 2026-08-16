// ═════════════════════════════════════════════════════════════════════════════
// V Shots — History grouper tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/shared/utils/history_grouper.dart';

void main() {
  final now = DateTime(2026, 8, 16, 15, 30); // fixed clock for determinism

  Map<String, dynamic> entry(String id, DateTime playedAt) => {
        'id': id,
        'title': 'T $id',
        'artist': 'A',
        'playedAt': playedAt.toIso8601String(),
      };

  group('groupHistoryByDay', () {
    test('buckets into Today / Yesterday / Earlier', () {
      final history = [
        entry('a', now), // today
        entry('b', now.subtract(const Duration(days: 1))), // yesterday
        entry('c', now.subtract(const Duration(days: 3))), // earlier
      ];

      final groups = groupHistoryByDay(history, now: now);
      expect(groups.map((g) => g.label).toList(),
          ['Today', 'Yesterday', 'Earlier']);
      expect(groups[0].items.map((t) => t['id']).toList(), ['a']);
      expect(groups[1].items.map((t) => t['id']).toList(), ['b']);
      expect(groups[2].items.map((t) => t['id']).toList(), ['c']);
    });

    test('preserves most-recent-first order within each bucket', () {
      final history = [
        entry('a', now),
        entry('b', now.subtract(const Duration(hours: 2))),
        entry('c', now.subtract(const Duration(hours: 5))),
      ];
      final groups = groupHistoryByDay(history, now: now);
      expect(groups.single.items.map((t) => t['id']).toList(), ['a', 'b', 'c']);
    });

    test('omits empty buckets', () {
      final history = [entry('a', now)];
      final groups = groupHistoryByDay(history, now: now);
      expect(groups.map((g) => g.label).toList(), ['Today']);
    });

    test('unparseable playedAt falls into Earlier', () {
      final history = [
        {'id': 'x', 'playedAt': 'not-a-date'},
        entry('a', now),
      ];
      final groups = groupHistoryByDay(history, now: now);
      final earlier = groups.firstWhere((g) => g.label == 'Earlier');
      expect(earlier.items.single['id'], 'x');
    });

    test('empty history yields no groups', () {
      expect(groupHistoryByDay(const [], now: now), isEmpty);
    });
  });
}
