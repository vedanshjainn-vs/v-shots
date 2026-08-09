// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Comment Model
// ═════════════════════════════════════════════════════════════════════════════

import 'profile_model.dart';

class CommentModel {
  const CommentModel({
    required this.id,
    required this.shotId,
    required this.userId,
    required this.body,
    this.author,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String shotId;
  final String userId;
  final String body;
  final ProfileModel? author;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    ProfileModel? author;
    if (json['profiles'] != null && json['profiles'] is Map<String, dynamic>) {
      author = ProfileModel.fromJson(json['profiles'] as Map<String, dynamic>);
    } else if (json['author'] != null && json['author'] is Map<String, dynamic>) {
      author = ProfileModel.fromJson(json['author'] as Map<String, dynamic>);
    }

    return CommentModel(
      id: json['id'] as String? ?? '',
      shotId: json['shot_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      author: author,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'shot_id': shotId,
      'user_id': userId,
      'body': body,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
