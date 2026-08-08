// ════════════════════════════════════════════════
// Project Lyra — Download Local Data Source
// ════════════════════════════════════════════════

import '../../../../../core/logging/app_logger.dart';
import '../../../../../core/storage/local_storage.dart';
import '../models/download_models.dart';

abstract class DownloadLocalDataSource {
  Future<List<DownloadModel>> getDownloads();
  Future<DownloadModel?> getDownload(String trackId);
  Future<void> saveDownload(DownloadModel download);
  Future<void> updateDownload(DownloadModel download);
  Future<void> deleteDownload(String downloadId);
  Future<void> saveDownloads(List<DownloadModel> downloads);
  Future<bool> isDownloaded(String trackId);
}

class HiveDownloadLocalDataSource implements DownloadLocalDataSource {
  HiveDownloadLocalDataSource({required this.localStorage, AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final LocalStorage localStorage;
  final AppLogger _logger;

  static const String _downloadsKey = 'downloads';

  @override
  Future<List<DownloadModel>> getDownloads() async {
    try {
      final raw = await localStorage.getString(_downloadsKey);
      if (raw == null) return [];
      // TODO(team): Deserialize from JSON.
      return [];
    } catch (e) {
      _logger.w('DownloadLocal: getDownloads failed');
      return [];
    }
  }

  @override
  Future<DownloadModel?> getDownload(String trackId) async {
    try {
      final downloads = await getDownloads();
      return downloads.where((d) => d.trackId == trackId).firstOrNull;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveDownload(DownloadModel download) async {
    try {
      final downloads = await getDownloads();
      downloads.add(download);
      await saveDownloads(downloads);
    } catch (e) {
      _logger.w('DownloadLocal: saveDownload failed');
    }
  }

  @override
  Future<void> updateDownload(DownloadModel download) async {
    try {
      final downloads = await getDownloads();
      final index = downloads.indexWhere((d) => d.id == download.id);
      if (index >= 0) {
        downloads[index] = download;
        await saveDownloads(downloads);
      }
    } catch (e) {
      _logger.w('DownloadLocal: updateDownload failed');
    }
  }

  @override
  Future<void> deleteDownload(String downloadId) async {
    try {
      final downloads = await getDownloads();
      downloads.removeWhere((d) => d.id == downloadId);
      await saveDownloads(downloads);
    } catch (e) {
      _logger.w('DownloadLocal: deleteDownload failed');
    }
  }

  @override
  Future<void> saveDownloads(List<DownloadModel> downloads) async {
    try {
      // TODO(team): Serialize to JSON.
      await localStorage.setString(_downloadsKey, downloads.length.toString());
    } catch (e) {
      _logger.w('DownloadLocal: saveDownloads failed');
    }
  }

  @override
  Future<bool> isDownloaded(String trackId) async {
    final download = await getDownload(trackId);
    return download?.status == 'completed';
  }
}
