// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Shot Data Model (Short Videos & Media)
// ═════════════════════════════════════════════════════════════════════════════

import 'profile_model.dart';

class ShotModel {
  const ShotModel({
    required this.id,
    required this.userId,
    required this.videoUrl,
    this.caption = '',
    this.thumbnailUrl = '',
    this.durationSeconds = 0,
    this.visibility = 'public',
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isBookmarked = false,
    this.creator,
    this.audioTitle,
    this.audioArtist,
    this.tags = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String videoUrl;
  final String caption;
  final String thumbnailUrl;
  final int durationSeconds;
  final String visibility;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isBookmarked;
  final ProfileModel? creator;
  final String? audioTitle;
  final String? audioArtist;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ShotModel.fromJson(Map<String, dynamic> json) {
    ProfileModel? creator;
    if (json['profiles'] != null && json['profiles'] is Map<String, dynamic>) {
      creator = ProfileModel.fromJson(json['profiles'] as Map<String, dynamic>);
    } else if (json['creator'] != null &&
        json['creator'] is Map<String, dynamic>) {
      creator = ProfileModel.fromJson(json['creator'] as Map<String, dynamic>);
    }

    final rawTags = json['tags'];
    List<String> parsedTags = <String>[];
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    } else if (rawTags is String && rawTags.isNotEmpty) {
      parsedTags = rawTags.split(',').map((e) => e.trim()).toList();
    }

    return ShotModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      videoUrl: json['video_url'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      visibility: json['visibility'] as String? ?? 'public',
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
      creator: creator,
      audioTitle: json['audio_title'] as String?,
      audioArtist: json['audio_artist'] as String?,
      tags: parsedTags,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'video_url': videoUrl,
      'caption': caption,
      'thumbnail_url': thumbnailUrl,
      'duration_seconds': durationSeconds,
      'visibility': visibility,
      'like_count': likeCount,
      'comment_count': commentCount,
      'tags': tags,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ShotModel copyWith({
    String? id,
    String? userId,
    String? videoUrl,
    String? caption,
    String? thumbnailUrl,
    int? durationSeconds,
    String? visibility,
    int? likeCount,
    int? commentCount,
    bool? isLiked,
    bool? isBookmarked,
    ProfileModel? creator,
    String? audioTitle,
    String? audioArtist,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShotModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      videoUrl: videoUrl ?? this.videoUrl,
      caption: caption ?? this.caption,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      visibility: visibility ?? this.visibility,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      creator: creator ?? this.creator,
      audioTitle: audioTitle ?? this.audioTitle,
      audioArtist: audioArtist ?? this.audioArtist,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
