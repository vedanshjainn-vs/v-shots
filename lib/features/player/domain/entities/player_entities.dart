// ════════════════════════════════════════════════
// Project Lyra — Player Entities
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'player_entities.freezed.dart';
part 'player_entities.g.dart';

@freezed
class Track with _$Track {
  const factory Track({
    required String id,
    required String title,
    required String artist,
    String? album,
    String? artUrl,
    String? streamUrl,
    @Default(Duration.zero) Duration duration,
    @Default(false) bool isLiked,
    @Default(false) bool isDownloaded,
    String? genre,
    int? year,
    @Default(0) int playCount,
    @Default({}) Map<String, dynamic> metadata,
  }) = _Track;

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
}

@freezed
class Album with _$Album {
  const factory Album({
    required String id,
    required String title,
    required String artist,
    String? artUrl,
    @Default([]) List<Track> tracks,
    String? genre,
    int? year,
    String? description,
    @Default(0) int totalDuration,
  }) = _Album;

  factory Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);
}

@freezed
class PlaybackSession with _$PlaybackSession {
  const factory PlaybackSession({
    required String id,
    Track? currentTrack,
    @Default(0) int currentIndex,
    @Default([]) List<Track> queue,
    @Default(Duration.zero) Duration position,
    @Default(Duration.zero) Duration duration,
    @Default(false) bool isPlaying,
    @Default(false) bool shuffleEnabled,
    @Default(RepeatMode.off) RepeatMode repeatMode,
    @Default(1.0) double speed,
    DateTime? startedAt,
  }) = _PlaybackSession;

  factory PlaybackSession.fromJson(Map<String, dynamic> json) => _$PlaybackSessionFromJson(json);
}

@freezed
class Lyrics with _$Lyrics {
  const factory Lyrics({
    required String trackId,
    @Default([]) List<LyricsLine> lines,
    @Default(false) bool isSynced,
    String? source,
    String? language,
  }) = _Lyrics;

  factory Lyrics.fromJson(Map<String, dynamic> json) => _$LyricsFromJson(json);
}

@freezed
class LyricsLine with _$LyricsLine {
  const factory LyricsLine({
    required String text,
    required Duration timestamp,
    @Default(false) bool isChorus,
  }) = _LyricsLine;

  factory LyricsLine.fromJson(Map<String, dynamic> json) => _$LyricsLineFromJson(json);
}

enum RepeatMode { off, one, all }
