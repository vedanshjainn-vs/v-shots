// ════════════════════════════════════════════════
// Project Lyra — History Repository Interface
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/history_entities.dart';

typedef Result<T> = Either<Failure, T>;

abstract class HistoryRepository {
  Future<Result<List<HistoryEntry>>> getHistory({int page = 1, int limit = 50});
  Future<Result<List<HistoryGroup>>> getGroupedHistory({int days = 30});
  Future<Result<void>> addToHistory(HistoryEntry entry);
  Future<Result<void>> removeFromHistory(String entryId);
  Future<Result<void>> clearHistory();
  Future<Result<void>> clearHistoryBefore(DateTime date);
  Future<Result<int>> getHistoryCount();
}
