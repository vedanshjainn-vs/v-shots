// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Profile Model
// ═════════════════════════════════════════════════════════════════════════════

class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl = '',
    this.bio = '',
    this.followersCount = 0,
    this.followingCount = 0,
    this.shotsCount = 0,
    this.isFollowing = false,
    this.isCreator = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String username;
  final String fullName;
  final String avatarUrl;
  final String bio;
  final int followersCount;
  final int followingCount;
  final int shotsCount;
  final bool isFollowing;
  final bool isCreator;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? 'user',
      fullName: json['full_name'] as String? ?? 'V Shots Creator',
      avatarUrl: json['avatar_url'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      shotsCount: (json['shots_count'] as num?)?.toInt() ?? 0,
      isFollowing: json['is_following'] as bool? ?? false,
      isCreator: json['is_creator'] as bool? ?? false,
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
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'is_creator': isCreator,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? username,
    String? fullName,
    String? avatarUrl,
    String? bio,
    int? followersCount,
    int? followingCount,
    int? shotsCount,
    bool? isFollowing,
    bool? isCreator,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      shotsCount: shotsCount ?? this.shotsCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isCreator: isCreator ?? this.isCreator,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
