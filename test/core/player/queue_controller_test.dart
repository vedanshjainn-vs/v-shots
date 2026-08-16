// ═════════════════════════════════════════════════════════════════════════════
// V Shots — QueueController queue-mutation tests (play next / add to queue)
//
// Verifies the pure helpers behind the "Play Next" and "Add to Queue" actions:
// deterministic placement and no mutation of the input list.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/player/queue_controller.dart';

Map<String, dynamic> _track(String id) => {'id': id, 'title': 'T $id'};

void main() {
  group('insertNext (Play Next)', () {
    test('inserts immediately after the current index', () {
      final queue = [_track('a'), _track('b'), _track('c')];
      final result = QueueController.insertNext(queue, 0, _track('x'));
      expect(result.map((t) => t['id']).toList(), ['a', 'x', 'b', 'c']);
    });

    test('inserts after a middle index', () {
      final queue = [_track('a'), _track('b'), _track('c')];
      final result = QueueController.insertNext(queue, 1, _track('x'));
      expect(result.map((t) => t['id']).toList(), ['a', 'b', 'x', 'c']);
    });

    test('appends when current index is the last track', () {
      final queue = [_track('a'), _track('b')];
      final result = QueueController.insertNext(queue, 1, _track('x'));
      expect(result.map((t) => t['id']).toList(), ['a', 'b', 'x']);
    });

    test('empty queue yields a single-track queue', () {
      final result = QueueController.insertNext([], 0, _track('x'));
      expect(result.map((t) => t['id']).toList(), ['x']);
    });

    test('never mutates the input list', () {
      final queue = [_track('a'), _track('b')];
      final before = queue.map((t) => t['id']).toList();
      QueueController.insertNext(queue, 0, _track('x'));
      expect(queue.map((t) => t['id']).toList(), before);
    });
  });

  group('appendToQueue (Add to Queue)', () {
    test('appends to the end', () {
      final queue = [_track('a'), _track('b')];
      final result = QueueController.appendToQueue(queue, _track('x'));
      expect(result.map((t) => t['id']).toList(), ['a', 'b', 'x']);
    });

    test('never mutates the input list', () {
      final queue = [_track('a')];
      QueueController.appendToQueue(queue, _track('x'));
      expect(queue.map((t) => t['id']).toList(), ['a']);
    });
  });
}
