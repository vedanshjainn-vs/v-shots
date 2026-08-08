// ════════════════════════════════════════════════
// Project Lyra — History Repository Implementation
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/mapper/failure_mapper.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/history_entities.dart';
import '../../domain/repositories/history_repository.dart';
import '../datasources/local/history_local_datasource.dart';
import '../models/history_models.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl({
    required this.localDataSource,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final HistoryLocalDataSource localDataSource;
  final AppLogger _logger;

  @override
  Future<Either<Failure, List<HistoryEntry>>> getHistory({int page = 1, int limit = 50}) async {
    try {
      final entries = await localDataSource.getHistory(page: page, limit: limit);
      return Right(entries.map((e) => e.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<HistoryGroup>>> getGroupedHistory({int days = 30}) async {
    try {
      final entries = await localDataSource.getHistory(limit: 1000);
      final groups = <String, List<HistoryEntryModel>>{};

      for (final entry in entries) {
        final date = entry.playedAt != null
            ? DateTime.tryParse(entry.playedAt!) ?? DateTime.now()
            : DateTime.now();
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        groups.putIfAbsent(key, () => []).add(entry);
      }

      return Right(groups.entries.map((g) => HistoryGroup(
        date: g.key,
        entries: g.value.map((e) => e.toEntity()).toList(),
      )).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> addToHistory(HistoryEntry entry) async {
    try {
      await localDataSource.addToHistory(entry.toModel());
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> removeFromHistory(String entryId) async {
    try {
      await localDataSource.removeFromHistory(entryId);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> clearHistory() async {
    try {
      await localDataSource.clearHistory();
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> clearHistoryBefore(DateTime date) async {
    try {
      await localDataSource.clearHistoryBefore(date);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, int>> getHistoryCount() async {
    try {
      final count = await localDataSource.getHistoryCount();
      return Right(count);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }
}
