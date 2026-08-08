// ════════════════════════════════════════════════
// Project Lyra — Sync Manager Tests
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lyra/core/sync/managers/sync_manager.dart';
import 'package:project_lyra/core/sync/queue/sync_operation.dart';

import '../../../builders/test_data_builder.dart';

void main() {
  group('SyncManager', () {
    late SyncManager manager;

    setUp(() {
      manager = SyncManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('starts with no pending operations', () {
      expect(manager.pendingCount, 0);
      expect(manager.hasPending, false);
    });

    test('enqueue adds pending operation', () async {
      final op = SyncOperationBuilder()
          .withId('1')
          .withType(SyncOperationType.like)
          .build();

      await manager.enqueue(op);

      expect(manager.pendingCount, 1);
      expect(manager.hasPending, true);
    });

    test('syncAll processes pending operations', () async {
      final op1 = SyncOperationBuilder()
          .withId('1')
          .withType(SyncOperationType.like)
          .build();
      final op2 = SyncOperationBuilder()
          .withId('2')
          .withType(SyncOperationType.follow)
          .build();

      await manager.enqueue(op1);
      await manager.enqueue(op2);

      final result = await manager.syncAll();

      expect(result.totalProcessed, 2);
      expect(result.successCount, 2);
      expect(manager.pendingCount, 0);
    });

    test('syncAll returns nothingToSync when empty', () async {
      final result = await manager.syncAll();

      expect(result, SyncResult.nothingToSync);
    });

    test('clearPending removes all operations', () async {
      await manager.enqueue(SyncOperationBuilder().build());

      manager.clearPending();

      expect(manager.pendingCount, 0);
    });
  });
}
