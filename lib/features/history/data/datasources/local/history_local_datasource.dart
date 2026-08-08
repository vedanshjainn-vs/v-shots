// ════════════════════════════════════════════════
// Project Lyra — History Local Data Source
// ════════════════════════════════════════════════

import '../../../../../core/logging/app_logger.dart';
import '../../../../../core/storage/local_storage.dart';
import '../models/history_models.dart';

abstract class HistoryLocalDataSource {
  Future<List<HistoryEntryModel>> getHistory({int page = 1, int limit = 50});
  Future<void> addToHistory(HistoryEntryModel entry);
  Future<void> removeFromHistory(String entryId);
  Future<void> clearHistory();
  Future<void> clearHistoryBefore(DateTime date);
  Future<int> getHistoryCount();
}

class HiveHistoryLocalDataSource implements HistoryLocalDataSource {
  HiveHistoryLocalDataSource({required this.localStorage, AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final LocalStorage localStorage;
  final AppLogger _logger;

  static const String _historyKey = 'play_history';
  static const int _maxHistoryEntries = 1000;

  @override
  Future<List<HistoryEntryModel>> getHistory({int page = 1, int limit = 50}) async {
    try {
      final raw = await localStorage.getString(_historyKey);
      if (raw == null) return [];
      // TODO(team): Deserialize from JSON and apply pagination.
      return [];
    } catch (e) {
      _logger.w('HistoryLocal: getHistory failed');
      return [];
    }
  }

  @override
  Future<void> addToHistory(HistoryEntryModel entry) async {
    try {
      final history = await getHistory();
      // Remove if already exists.
      history.removeWhere((e) => e.contentId == entry.contentId);
      // Add to front.
      history.insert(0, entry);
      // Trim to max.
      if (history.length > _maxHistoryEntries) {
        history.removeRange(_maxHistoryEntries, history.length);
      }
      // TODO(team): Serialize and save.
    } catch (e) {
      _logger.w('HistoryLocal: addToHistory failed');
    }
  }

  @override
  Future<void> removeFromHistory(String entryId) async {
    try {
      final history = await getHistory();
      history.removeWhere((e) => e.id == entryId);
      // TODO(team): Serialize and save.
    } catch (e) {
      _logger.w('HistoryLocal: removeFromHistory failed');
    }
  }

  @override
  Future<void> clearHistory() async {
    await localStorage.remove(_historyKey);
  }

  @override
  Future<void> clearHistoryBefore(DateTime date) async {
    try {
      final history = await getHistory();
      history.removeWhere((e) {
        final playedAt = e.playedAt != null ? DateTime.tryParse(e.playedAt!) : null;
        return playedAt != null && playedAt.isBefore(date);
      });
      // TODO(team): Serialize and save.
    } catch (e) {
      _logger.w('HistoryLocal: clearHistoryBefore failed');
    }
  }

  @override
  Future<int> getHistoryCount() async {
    final history = await getHistory();
    return history.length;
  }
}
