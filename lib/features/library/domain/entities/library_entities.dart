// ════════════════════════════════════════════════
// Project Lyra — Library Entities
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'library_entities.freezed.dart';
part 'library_entities.g.dart';

/// User's library containing all saved content.
@freezed
class Library with _$Library {
  const factory Library({
    @Default([]) List<SavedTrack> likedSongs,
    @Default([]) List<SavedAlbum> savedAlbums,
    @Default([]) List<SavedArtist> followedArtists,
    @Default([]) List<SavedPlaylist> savedPlaylists,
    @Default([]) List<RecentlyPlayed> recentlyPlayed,
    @Default(0) int totalTracks,
    @Default(0) int totalAlbums,
    @Default(0) int totalArtists,
    DateTime? lastSyncedAt,
  }) = _Library;

  factory Library.fromJson(Map<String, dynamic> json) => _$LibraryFromJson(json);
}

@freezed
class SavedTrack with _$SavedTrack {
  const factory SavedTrack({
    required String id,
    required String title,
    required String artist,
    String? album,
    String? artUrl,
    @Default(Duration.zero) Duration duration,
    DateTime? likedAt,
    @Default(false) bool isDownloaded,
  }) = _SavedTrack;

  factory SavedTrack.fromJson(Map<String, dynamic> json) => _$SavedTrackFromJson(json);
}

@freezed
class SavedAlbum with _$SavedAlbum {
  const factory SavedAlbum({
    required String id,
    required String title,
    required String artist,
    String? artUrl,
    @Default(0) int trackCount,
    DateTime? savedAt,
  }) = _SavedAlbum;

  factory SavedAlbum.fromJson(Map<String, dynamic> json) => _$SavedAlbumFromJson(json);
}

@freezed
class SavedArtist with _$SavedArtist {
  const factory SavedArtist({
    required String id,
    required String name,
    String? imageUrl,
    DateTime? followedAt,
    @Default(false) bool hasNewRelease,
  }) = _SavedArtist;

  factory SavedArtist.fromJson(Map<String, dynamic> json) => _$SavedArtistFromJson(json);
}

@freezed
class SavedPlaylist with _$SavedPlaylist {
  const factory SavedPlaylist({
    required String id,
    required String title,
    String? description,
    String? artUrl,
    @Default(0) int trackCount,
    DateTime? savedAt,
  }) = _SavedPlaylist;

  factory SavedPlaylist.fromJson(Map<String, dynamic> json) => _$SavedPlaylistFromJson(json);
}

@freezed
class RecentlyPlayed with _$RecentlyPlayed {
  const factory RecentlyPlayed({
    required String id,
    required String title,
    String? subtitle,
    String? imageUrl,
    required String contentType,
    DateTime? playedAt,
  }) = _RecentlyPlayed;

  factory RecentlyPlayed.fromJson(Map<String, dynamic> json) => _$RecentlyPlayedFromJson(json);
}
