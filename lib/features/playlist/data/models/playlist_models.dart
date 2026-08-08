// ════════════════════════════════════════════════
// Project Lyra — Playlist Data Models
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/playlist_entities.dart';

part 'playlist_models.freezed.dart';
part 'playlist_models.g.dart';

@freezed
class PlaylistModel with _$PlaylistModel {
  const factory PlaylistModel({
    required String id,
    required String title,
    String? description,
    String? artUrl,
    required String ownerId,
    String? ownerName,
    @Default([]) List<PlaylistItemModel> tracks,
    @Default(true) bool isPublic,
    @Default(false) bool isCollaborative,
    @Default([]) List<CollaboratorModel> collaborators,
    @Default(0) int totalDuration,
    String? createdAt,
    String? updatedAt,
    @Default(0) int followerCount,
  }) = _PlaylistModel;

  factory PlaylistModel.fromJson(Map<String, dynamic> json) => _$PlaylistModelFromJson(json);
}

@freezed
class PlaylistItemModel with _$PlaylistItemModel {
  const factory PlaylistItemModel({
    required String trackId,
    required String title,
    required String artist,
    String? album,
    String? artUrl,
    @Default(0) int durationMs,
    required String addedAt,
    String? addedBy,
  }) = _PlaylistItemModel;

  factory PlaylistItemModel.fromJson(Map<String, dynamic> json) => _$PlaylistItemModelFromJson(json);
}

@freezed
class CollaboratorModel with _$CollaboratorModel {
  const factory CollaboratorModel({
    required String userId,
    required String name,
    String? avatarUrl,
    @Default('viewer') String role,
  }) = _CollaboratorModel;

  factory CollaboratorModel.fromJson(Map<String, dynamic> json) => _$CollaboratorModelFromJson(json);
}

/// Entity conversion extensions.
extension PlaylistModelX on PlaylistModel {
  Playlist toEntity() => Playlist(
        id: id, title: title, description: description, artUrl: artUrl,
        ownerId: ownerId, ownerName: ownerName,
        tracks: tracks.map((t) => t.toEntity()).toList(),
        isPublic: isPublic, isCollaborative: isCollaborative,
        collaborators: collaborators.map((c) => c.toEntity()).toList(),
        totalDuration: totalDuration,
        createdAt: createdAt != null ? DateTime.tryParse(createdAt!) : null,
        updatedAt: updatedAt != null ? DateTime.tryParse(updatedAt!) : null,
        followerCount: followerCount,
      );
}

extension PlaylistItemModelX on PlaylistItemModel {
  PlaylistItem toEntity() => PlaylistItem(
        trackId: trackId, title: title, artist: artist, album: album,
        artUrl: artUrl,
        duration: Duration(milliseconds: durationMs),
        addedAt: DateTime.tryParse(addedAt) ?? DateTime.now(),
        addedBy: addedBy,
      );
}

extension CollaboratorModelX on CollaboratorModel {
  Collaborator toEntity() => Collaborator(
        userId: userId, name: name, avatarUrl: avatarUrl,
        role: CollaboratorRole.values.byName(role),
      );
}
