// ════════════════════════════════════════════════
// Project Lyra — History Use Cases
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/history_entities.dart';
import '../repositories/history_repository.dart';

class GetHistory implements UseCase<List<HistoryEntry>, PageParams> {
  const GetHistory(this.repository);
  final HistoryRepository repository;
  @override
  Future<Either<Failure, List<HistoryEntry>>> call(PageParams params) =>
      repository.getHistory(page: params.page, limit: params.limit);
}

class GetGroupedHistory implements UseCase<List<HistoryGroup>, GetGroupedHistoryParams> {
  const GetGroupedHistory(this.repository);
  final HistoryRepository repository;
  @override
  Future<Either<Failure, List<HistoryGroup>>> call(GetGroupedHistoryParams params) =>
      repository.getGroupedHistory(days: params.days);
}

class GetGroupedHistoryParams extends Equatable {
  const GetGroupedHistoryParams({this.days = 30});
  final int days;
  @override
  List<Object?> get props => [days];
}

class AddToHistory implements UseCaseVoid<HistoryEntry> {
  const AddToHistory(this.repository);
  final HistoryRepository repository;
  @override
  Future<Either<Failure, void>> call(HistoryEntry entry) => repository.addToHistory(entry);
}

class ClearHistory implements UseCaseVoid<NoParams> {
  const ClearHistory(this.repository);
  final HistoryRepository repository;
  @override
  Future<Either<Failure, void>> call(NoParams params) => repository.clearHistory();
}
