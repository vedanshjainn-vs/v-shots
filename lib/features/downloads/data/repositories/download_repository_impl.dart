// ════════════════════════════════════════════════
// Project Lyra — Download Repository Implementation
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/mapper/failure_mapper.dart';
import '../../../../core/events/bus/app_event_bus.dart';
import '../../../../core/events/types/app_event.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/download_entities.dart';
import '../../domain/repositories/download_repository.dart';
import '../datasources/local/download_local_datasource.dart';
import '../datasources/remote/download_remote_datasource.dart';
import '../models/download_models.dart';

class DownloadRepositoryImpl implements DownloadRepository {
  DownloadRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.eventBus,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final DownloadRemoteDataSource remoteDataSource;
  final DownloadLocalDataSource localDataSource;
  final AppEventBus eventBus;
  final AppLogger _logger;

  final Map<String, CancelToken> _cancelTokens = {};

  @override
  Future<Either<Failure, Download>> downloadTrack(String trackId, {int bitrate = 320}) async {
    try {
      // Check if already downloaded.
      if (await localDataSource.isDownloaded(trackId)) {
        final existing = await localDataSource.getDownload(trackId);
        if (existing != null) return Right(existing.toEntity());
      }

      // Create download record.
      final download = DownloadModel(
        id: 'dl_$trackId',
        trackId: trackId,
        title: '',
        artist: '',
        status: 'downloading',
        progress: 0.0,
        bitrate: bitrate,
        startedAt: DateTime.now().toIso8601String(),
      );

      await localDataSource.saveDownload(download);
      eventBus.emit(DownloadStartedEvent(downloadId: download.id, title: download.title));

      // Start download.
      final cancelToken = CancelToken();
      _cancelTokens[download.id] = cancelToken;

      // TODO(team): Implement actual file download with progress tracking.
      // final result = await remoteDataSource.downloadTrack(
      //   trackId,
      //   savePath,
      //   bitrate: bitrate,
      //   cancelToken: cancelToken,
      //   onProgress: (received, total) {
      //     final progress = total > 0 ? received / total : 0.0;
      //     localDataSource.updateDownload(download.copyWith(
      //       progress: progress,
      //       downloadedBytes: received,
      //       totalBytes: total,
      //     ));
      //   },
      // );

      return Right(download.copyWith(status: 'completed', progress: 1.0).toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> pauseDownload(String downloadId) async {
    try {
      _cancelTokens[downloadId]?.cancel('Paused by user');
      _cancelTokens.remove(downloadId);

      final download = await localDataSource.getDownload(downloadId);
      if (download != null) {
        await localDataSource.updateDownload(download.copyWith(status: 'paused'));
      }
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> resumeDownload(String downloadId) async {
    try {
      final download = await localDataSource.getDownload(downloadId);
      if (download != null) {
        await localDataSource.updateDownload(download.copyWith(status: 'downloading'));
        // TODO(team): Resume download from last position.
      }
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> cancelDownload(String downloadId) async {
    try {
      _cancelTokens[downloadId]?.cancel('Cancelled by user');
      _cancelTokens.remove(downloadId);
      await localDataSource.deleteDownload(downloadId);
      eventBus.emit(DownloadFailedEvent(downloadId: downloadId));
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> deleteDownload(String downloadId) async {
    try {
      await localDataSource.deleteDownload(downloadId);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<Download>>> getDownloads() async {
    try {
      final downloads = await localDataSource.getDownloads();
      return Right(downloads.map((d) => d.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<Download>>> getDownloadsByStatus(DownloadStatus status) async {
    try {
      final downloads = await localDataSource.getDownloads();
      return Right(downloads.where((d) => d.status == status.name).map((d) => d.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, Download?>> getDownload(String trackId) async {
    try {
      final download = await localDataSource.getDownload(trackId);
      return Right(download?.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> retryDownload(String downloadId) async {
    try {
      final download = await localDataSource.getDownload(downloadId);
      if (download != null) {
        await localDataSource.updateDownload(download.copyWith(
          status: 'queued',
          retryCount: download.retryCount + 1,
          error: null,
        ));
      }
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, int>> getTotalDownloadSize() async {
    try {
      final downloads = await localDataSource.getDownloads();
      final totalSize = downloads.fold<int>(0, (sum, d) => sum + d.totalBytes);
      return Right(totalSize);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<bool> isDownloaded(String trackId) async {
    return localDataSource.isDownloaded(trackId);
  }

  @override
  Stream<List<Download>> get downloadsStream => const Stream.empty();
}
