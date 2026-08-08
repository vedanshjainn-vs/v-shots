// ════════════════════════════════════════════════
// Project Lyra — Playlist Entities
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'playlist_entities.freezed.dart';
part 'playlist_entities.g.dart';

@freezed
class Playlist with _$Playlist {
  const factory Playlist({
    required String id,
    required String title,
    String? description,
    String? artUrl,
    required String ownerId,
    String? ownerName,
    @Default([]) List<PlaylistItem> tracks,
    @Default(false) bool isPublic,
    @Default(false) bool isCollaborative,
    @Default([]) List<Collaborator> collaborators,
    @Default(0) int totalDuration,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default(0) int followerCount,
  }) = _Playlist;

  factory Playlist.fromJson(Map<String, dynamic> json) => _$PlaylistFromJson(json);
}

@freezed
class PlaylistItem with _$PlaylistItem {
  const factory PlaylistItem({
    required String trackId,
    required String title,
    required String artist,
    String? album,
    String? artUrl,
    @Default(Duration.zero) Duration duration,
    required DateTime addedAt,
    String? addedBy,
  }) = _PlaylistItem;

  factory PlaylistItem.fromJson(Map<String, dynamic> json) => _$PlaylistItemFromJson(json);
}

@freezed
class Collaborator with _$Collaborator {
  const factory Collaborator({
    required String userId,
    required String name,
    String? avatarUrl,
    @Default(CollaboratorRole.viewer) CollaboratorRole role,
  }) = _Collaborator;

  factory Collaborator.fromJson(Map<String, dynamic> json) => _$CollaboratorFromJson(json);
}

enum CollaboratorRole { viewer, editor, admin }
