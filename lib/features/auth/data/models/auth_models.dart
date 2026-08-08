// ════════════════════════════════════════════════
// Project Lyra — Auth Data Models
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/auth_entities.dart';

part 'auth_models.freezed.dart';
part 'auth_models.g.dart';

/// Data model for user — extends domain entity with serialization.
@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    String? displayName,
    String? avatarUrl,
    String? phoneNumber,
    @Default(false) bool isEmailVerified,
    @Default(false) bool isAnonymous,
    @Default('free') String subscriptionTier,
    String? createdAt,
    String? updatedAt,
    @Default({}) Map<String, dynamic> metadata,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}

/// Extension to convert between model and entity.
extension UserModelX on UserModel {
  LyraUser toEntity() => LyraUser(
        id: id,
        email: email,
        displayName: displayName,
        avatarUrl: avatarUrl,
        phoneNumber: phoneNumber,
        isEmailVerified: isEmailVerified,
        isAnonymous: isAnonymous,
        subscriptionTier: SubscriptionTier.values.byName(subscriptionTier),
        createdAt: createdAt != null ? DateTime.tryParse(createdAt!) : null,
        updatedAt: updatedAt != null ? DateTime.tryParse(updatedAt!) : null,
        metadata: metadata,
      );
}

/// Extension to convert entity to model.
extension LyraUserX on LyraUser {
  UserModel toModel() => UserModel(
        id: id,
        email: email,
        displayName: displayName,
        avatarUrl: avatarUrl,
        phoneNumber: phoneNumber,
        isEmailVerified: isEmailVerified,
        isAnonymous: isAnonymous,
        subscriptionTier: subscriptionTier.name,
        createdAt: createdAt?.toIso8601String(),
        updatedAt: updatedAt?.toIso8601String(),
        metadata: metadata,
      );
}

/// Data model for auth session.
@freezed
class SessionModel with _$SessionModel {
  const factory SessionModel({
    required String accessToken,
    required String refreshToken,
    required String expiresAt,
    required String userId,
    String? provider,
    @Default({}) Map<String, dynamic> providerData,
  }) = _SessionModel;

  factory SessionModel.fromJson(Map<String, dynamic> json) =>
      _$SessionModelFromJson(json);
}

extension SessionModelX on SessionModel {
  AuthSession toEntity() => AuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: DateTime.parse(expiresAt),
        userId: userId,
        provider: provider,
        providerData: providerData,
      );
}
