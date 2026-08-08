// ════════════════════════════════════════════════
// Project Lyra — Download Remote Data Source
// ════════════════════════════════════════════════

import 'package:dio/dio.dart';

import '../../../../../core/logging/app_logger.dart';
import '../models/download_models.dart';

abstract class DownloadRemoteDataSource {
  Future<String> getDownloadUrl(String trackId, {int bitrate = 320});
  Future<DownloadModel> downloadTrack(String trackId, String savePath, {
    int bitrate = 320,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  });
  Future<int> getFileSize(String trackId, {int bitrate = 320});
}

class DioDownloadRemoteDataSource implements DownloadRemoteDataSource {
  DioDownloadRemoteDataSource({required this.dio, AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final Dio dio;
  final AppLogger _logger;

  @override
  Future<String> getDownloadUrl(String trackId, {int bitrate = 320}) async {
    try {
      // TODO(team): Implement with Supabase Storage signed URL.
      return 'https://download.projectlyra.com/tracks/$trackId?bitrate=$bitrate';
    } catch (e, st) {
      _logger.e('DownloadRemote: getDownloadUrl failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<DownloadModel> downloadTrack(String trackId, String savePath, {
    int bitrate = 320,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final url = await getDownloadUrl(trackId, bitrate: bitrate);

      await dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
      );

      return DownloadModel(
        id: trackId,
        trackId: trackId,
        title: '',
        artist: '',
        filePath: savePath,
        status: 'completed',
        progress: 1.0,
        bitrate: bitrate,
      );
    } catch (e, st) {
      _logger.e('DownloadRemote: downloadTrack failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<int> getFileSize(String trackId, {int bitrate = 320}) async {
    try {
      final url = await getDownloadUrl(trackId, bitrate: bitrate);
      final response = await dio.head(url);
      return int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
