// ════════════════════════════════════════════════
// Project Lyra — Player Data Models
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/player_entities.dart';

part 'player_models.freezed.dart';
part 'player_models.g.dart';

@freezed
class TrackModel with _$TrackModel {
  const factory TrackModel({
    required String id,
    required String title,
    required String artist,
    String? album,
    String? artUrl,
    String? streamUrl,
    @Default(0) int durationMs,
    @Default(false) bool isLiked,
    @Default(false) bool isDownloaded,
    String? genre,
    int? year,
    @Default(0) int playCount,
    @Default({}) Map<String, dynamic> metadata,
  }) = _TrackModel;

  factory TrackModel.fromJson(Map<String, dynamic> json) => _$TrackModelFromJson(json);
}

@freezed
class AlbumModel with _$AlbumModel {
  const factory AlbumModel({
    required String id,
    required String title,
    required String artist,
    String? artUrl,
    @Default([]) List<TrackModel> tracks,
    String? genre,
    int? year,
    String? description,
  }) = _AlbumModel;

  factory AlbumModel.fromJson(Map<String, dynamic> json) => _$AlbumModelFromJson(json);
}

@freezed
class LyricsModel with _$LyricsModel {
  const factory LyricsModel({
    required String trackId,
    @Default([]) List<LyricsLineModel> lines,
    @Default(false) bool isSynced,
    String? source,
    String? language,
  }) = _LyricsModel;

  factory LyricsModel.fromJson(Map<String, dynamic> json) => _$LyricsModelFromJson(json);
}

@freezed
class LyricsLineModel with _$LyricsLineModel {
  const factory LyricsLineModel({
    required String text,
    required int timestampMs,
    @Default(false) bool isChorus,
  }) = _LyricsLineModel;

  factory LyricsLineModel.fromJson(Map<String, dynamic> json) => _$LyricsLineModelFromJson(json);
}

/// Entity conversion extensions.
extension TrackModelX on TrackModel {
  Track toEntity() => Track(
        id: id, title: title, artist: artist, album: album,
        artUrl: artUrl, streamUrl: streamUrl,
        duration: Duration(milliseconds: durationMs),
        isLiked: isLiked, isDownloaded: isDownloaded,
        genre: genre, year: year, playCount: playCount,
        metadata: metadata,
      );
}

extension AlbumModelX on AlbumModel {
  Album toEntity() => Album(
        id: id, title: title, artist: artist, artUrl: artUrl,
        tracks: tracks.map((t) => t.toEntity()).toList(),
        genre: genre, year: year, description: description,
      );
}

extension LyricsModelX on LyricsModel {
  Lyrics toEntity() => Lyrics(
        trackId: trackId,
        lines: lines.map((l) => l.toEntity()).toList(),
        isSynced: isSynced, source: source, language: language,
      );
}

extension LyricsLineModelX on LyricsLineModel {
  LyricsLine toEntity() => LyricsLine(
        text: text,
        timestamp: Duration(milliseconds: timestampMs),
        isChorus: isChorus,
      );
}
