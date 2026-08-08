// ════════════════════════════════════════════════
// Project Lyra — Download Use Cases
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/download_entities.dart';
import '../repositories/download_repository.dart';

class DownloadTrack implements UseCase<Download, DownloadTrackParams> {
  const DownloadTrack(this.repository);
  final DownloadRepository repository;
  @override
  Future<Either<Failure, Download>> call(DownloadTrackParams params) =>
      repository.downloadTrack(params.trackId, bitrate: params.bitrate);
}

class DownloadTrackParams extends Equatable {
  const DownloadTrackParams({required this.trackId, this.bitrate = 320});
  final String trackId;
  final int bitrate;
  @override
  List<Object?> get props => [trackId, bitrate];
}

class PauseDownload implements UseCaseVoid<String> {
  const PauseDownload(this.repository);
  final DownloadRepository repository;
  @override
  Future<Either<Failure, void>> call(String id) => repository.pauseDownload(id);
}

class ResumeDownload implements UseCaseVoid<String> {
  const ResumeDownload(this.repository);
  final DownloadRepository repository;
  @override
  Future<Either<Failure, void>> call(String id) => repository.resumeDownload(id);
}

class CancelDownload implements UseCaseVoid<String> {
  const CancelDownload(this.repository);
  final DownloadRepository repository;
  @override
  Future<Either<Failure, void>> call(String id) => repository.cancelDownload(id);
}

class DeleteDownload implements UseCaseVoid<String> {
  const DeleteDownload(this.repository);
  final DownloadRepository repository;
  @override
  Future<Either<Failure, void>> call(String id) => repository.deleteDownload(id);
}

class GetDownloads implements UseCase<List<Download>, NoParams> {
  const GetDownloads(this.repository);
  final DownloadRepository repository;
  @override
  Future<Either<Failure, List<Download>>> call(NoParams params) => repository.getDownloads();
}
