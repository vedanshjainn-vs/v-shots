// ════════════════════════════════════════════════
// Project Lyra — Library Data Models
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/library_entities.dart';

part 'library_models.freezed.dart';
part 'library_models.g.dart';

@freezed
class LibraryModel with _$LibraryModel {
  const factory LibraryModel({
    @Default([]) List<SavedTrackModel> likedSongs,
    @Default([]) List<SavedAlbumModel> savedAlbums,
    @Default([]) List<SavedArtistModel> followedArtists,
    @Default([]) List<SavedPlaylistModel> savedPlaylists,
    @Default([]) List<RecentlyPlayedModel> recentlyPlayed,
    @Default(0) int totalTracks,
    @Default(0) int totalAlbums,
    @Default(0) int totalArtists,
    String? lastSyncedAt,
  }) = _LibraryModel;

  factory LibraryModel.fromJson(Map<String, dynamic> json) => _$LibraryModelFromJson(json);
}

@freezed
class SavedTrackModel with _$SavedTrackModel {
  const factory SavedTrackModel({
    required String id,
    required String title,
    required String artist,
    String? album,
    String? artUrl,
    @Default(0) int durationMs,
    String? likedAt,
    @Default(false) bool isDownloaded,
  }) = _SavedTrackModel;

  factory SavedTrackModel.fromJson(Map<String, dynamic> json) => _$SavedTrackModelFromJson(json);
}

@freezed
class SavedAlbumModel with _$SavedAlbumModel {
  const factory SavedAlbumModel({
    required String id,
    required String title,
    required String artist,
    String? artUrl,
    @Default(0) int trackCount,
    String? savedAt,
  }) = _SavedAlbumModel;

  factory SavedAlbumModel.fromJson(Map<String, dynamic> json) => _$SavedAlbumModelFromJson(json);
}

@freezed
class SavedArtistModel with _$SavedArtistModel {
  const factory SavedArtistModel({
    required String id,
    required String name,
    String? imageUrl,
    String? followedAt,
    @Default(false) bool hasNewRelease,
  }) = _SavedArtistModel;

  factory SavedArtistModel.fromJson(Map<String, dynamic> json) => _$SavedArtistModelFromJson(json);
}

@freezed
class SavedPlaylistModel with _$SavedPlaylistModel {
  const factory SavedPlaylistModel({
    required String id,
    required String title,
    String? description,
    String? artUrl,
    @Default(0) int trackCount,
    String? savedAt,
  }) = _SavedPlaylistModel;

  factory SavedPlaylistModel.fromJson(Map<String, dynamic> json) => _$SavedPlaylistModelFromJson(json);
}

@freezed
class RecentlyPlayedModel with _$RecentlyPlayedModel {
  const factory RecentlyPlayedModel({
    required String id,
    required String title,
    String? subtitle,
    String? imageUrl,
    required String contentType,
    String? playedAt,
  }) = _RecentlyPlayedModel;

  factory RecentlyPlayedModel.fromJson(Map<String, dynamic> json) => _$RecentlyPlayedModelFromJson(json);
}

/// Entity conversion extensions.
extension LibraryModelX on LibraryModel {
  Library toEntity() => Library(
        likedSongs: likedSongs.map((t) => t.toEntity()).toList(),
        savedAlbums: savedAlbums.map((a) => a.toEntity()).toList(),
        followedArtists: followedArtists.map((a) => a.toEntity()).toList(),
        savedPlaylists: savedPlaylists.map((p) => p.toEntity()).toList(),
        recentlyPlayed: recentlyPlayed.map((r) => r.toEntity()).toList(),
        totalTracks: totalTracks,
        totalAlbums: totalAlbums,
        totalArtists: totalArtists,
        lastSyncedAt: lastSyncedAt != null ? DateTime.tryParse(lastSyncedAt!) : null,
      );
}

extension SavedTrackModelX on SavedTrackModel {
  SavedTrack toEntity() => SavedTrack(
        id: id, title: title, artist: artist, album: album, artUrl: artUrl,
        duration: Duration(milliseconds: durationMs),
        likedAt: likedAt != null ? DateTime.tryParse(likedAt!) : null,
        isDownloaded: isDownloaded,
      );
}

extension SavedAlbumModelX on SavedAlbumModel {
  SavedAlbum toEntity() => SavedAlbum(
        id: id, title: title, artist: artist, artUrl: artUrl,
        trackCount: trackCount,
        savedAt: savedAt != null ? DateTime.tryParse(savedAt!) : null,
      );
}

extension SavedArtistModelX on SavedArtistModel {
  SavedArtist toEntity() => SavedArtist(
        id: id, name: name, imageUrl: imageUrl,
        followedAt: followedAt != null ? DateTime.tryParse(followedAt!) : null,
        hasNewRelease: hasNewRelease,
      );
}

extension SavedPlaylistModelX on SavedPlaylistModel {
  SavedPlaylist toEntity() => SavedPlaylist(
        id: id, title: title, description: description, artUrl: artUrl,
        trackCount: trackCount,
        savedAt: savedAt != null ? DateTime.tryParse(savedAt!) : null,
      );
}

extension RecentlyPlayedModelX on RecentlyPlayedModel {
  RecentlyPlayed toEntity() => RecentlyPlayed(
        id: id, title: title, subtitle: subtitle, imageUrl: imageUrl,
        contentType: contentType,
        playedAt: playedAt != null ? DateTime.tryParse(playedAt!) : null,
      );
}
