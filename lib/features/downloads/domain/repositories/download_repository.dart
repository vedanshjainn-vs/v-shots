// ════════════════════════════════════════════════
// Project Lyra — Download Repository Interface
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/download_entities.dart';

typedef Result<T> = Either<Failure, T>;

abstract class DownloadRepository {
  Future<Result<Download>> downloadTrack(String trackId, {int bitrate = 320});
  Future<Result<void>> pauseDownload(String downloadId);
  Future<Result<void>> resumeDownload(String downloadId);
  Future<Result<void>> cancelDownload(String downloadId);
  Future<Result<void>> deleteDownload(String downloadId);
  Future<Result<List<Download>>> getDownloads();
  Future<Result<List<Download>>> getDownloadsByStatus(DownloadStatus status);
  Future<Result<Download?>> getDownload(String trackId);
  Future<Result<void>> retryDownload(String downloadId);
  Future<Result<int>> getTotalDownloadSize();
  Future<bool> isDownloaded(String trackId);
  Stream<List<Download>> get downloadsStream;
}
