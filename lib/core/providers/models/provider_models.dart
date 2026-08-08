// ════════════════════════════════════════════════
// Project Lyra — Provider Models
// ════════════════════════════════════════════════
//
// Unified models that ALL providers map into.
// The Flutter app only sees these models.
// Provider-specific responses are mapped to these.
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'provider_models.freezed.dart';
part 'provider_models.g.dart';

/// Unified track model — all providers map to this.
@freezed
class ProviderTrack with _$ProviderTrack {
  const factory ProviderTrack({
    required String id,
    required String title,
    required String artist,
    String? artistId,
    String? album,
    String? albumId,
    String? artworkUrl,
    @Default(Duration.zero) Duration duration,
    @Default(false) bool isExplicit,
    int? trackNumber,
    int? discNumber,
    int? popularity,
    String? previewUrl,
    @Default([]) List<String> genres,
    @Default({}) Map<String, dynamic> metadata,
  }) = _ProviderTrack;

  factory ProviderTrack.fromJson(Map<String, dynamic> json) =>
      _$ProviderTrackFromJson(json);
}

/// Unified album model.
@freezed
class ProviderAlbum with _$ProviderAlbum {
  const factory ProviderAlbum({
    required String id,
    required String title,
    required String artist,
    String? artistId,
    String? artworkUrl,
    String? releaseDate,
    int? totalTracks,
    @Default([]) List<String> genres,
    String? label,
    String? copyright,
    @Default({}) Map<String, dynamic> metadata,
  }) = _ProviderAlbum;

  factory ProviderAlbum.fromJson(Map<String, dynamic> json) =>
      _$ProviderAlbumFromJson(json);
}

/// Unified artist model.
@freezed
class ProviderArtist with _$ProviderArtist {
  const factory ProviderArtist({
    required String id,
    required String name,
    String? imageUrl,
    String? biography,
    @Default(0) int followersCount,
    @Default([]) List<String> genres,
    @Default([]) List<String> images,
    @Default(false) bool isVerified,
    @Default({}) Map<String, dynamic> metadata,
  }) = _ProviderArtist;

  factory ProviderArtist.fromJson(Map<String, dynamic> json) =>
      _$ProviderArtistFromJson(json);
}

/// Unified playlist model.
@freezed
class ProviderPlaylist with _$ProviderPlaylist {
  const factory ProviderPlaylist({
    required String id,
    required String title,
    String? description,
    String? artworkUrl,
    String? ownerName,
    @Default(0) int trackCount,
    @Default(0) int followersCount,
    @Default(false) bool isPublic,
    @Default({}) Map<String, dynamic> metadata,
  }) = _ProviderPlaylist;

  factory ProviderPlaylist.fromJson(Map<String, dynamic> json) =>
      _$ProviderPlaylistFromJson(json);
}

/// Unified lyrics model.
@freezed
class ProviderLyrics with _$ProviderLyrics {
  const factory ProviderLyrics({
    required String trackId,
    @Default([]) List<ProviderLyricsLine> lines,
    @Default(false) bool isSynced,
    String? source,
    String? language,
  }) = _ProviderLyrics;

  factory ProviderLyrics.fromJson(Map<String, dynamic> json) =>
      _$ProviderLyricsFromJson(json);
}

@freezed
class ProviderLyricsLine with _$ProviderLyricsLine {
  const factory ProviderLyricsLine({
    required String text,
    required Duration timestamp,
    @Default(false) bool isChorus,
  }) = _ProviderLyricsLine;

  factory ProviderLyricsLine.fromJson(Map<String, dynamic> json) =>
      _$ProviderLyricsLineFromJson(json);
}

/// Stream information for playback.
@freezed
class ProviderStreamInfo with _$ProviderStreamInfo {
  const factory ProviderStreamInfo({
    required String url,
    required StreamQuality quality,
    @Default(0) int bitrateKbps,
    String? format,
    Duration? expiresAt,
    Map<String, String>? headers,
    @Default({}) Map<String, dynamic> metadata,
  }) = _ProviderStreamInfo;

  factory ProviderStreamInfo.fromJson(Map<String, dynamic> json) =>
      _$ProviderStreamInfoFromJson(json);
}

/// Stream quality levels.
enum StreamQuality {
  low(96, 'Low'),
  normal(128, 'Normal'),
  high(256, 'High'),
  lossless(320, 'Lossless');

  const StreamQuality(this.bitrate, this.label);
  final int bitrate;
  final String label;
}

/// Artwork size options.
enum ArtworkSize {
  small(64),
  medium(300),
  large(640),
  original(0);

  const ArtworkSize(this.pixelSize);
  final int pixelSize;
}

/// Unified search result.
@freezed
class ProviderSearchResult with _$ProviderSearchResult {
  const factory ProviderSearchResult({
    @Default([]) List<ProviderTrack> tracks,
    @Default([]) List<ProviderAlbum> albums,
    @Default([]) List<ProviderArtist> artists,
    @Default([]) List<ProviderPlaylist> playlists,
    @Default(0) int totalResults,
    String? query,
    String? providerId,
  }) = _ProviderSearchResult;

  factory ProviderSearchResult.fromJson(Map<String, dynamic> json) =>
      _$ProviderSearchResultFromJson(json);
}
