// ════════════════════════════════════════════════
// V Shots — Auth Providers
// ════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_client.dart';
import '../../data/datasources/remote/auth_remote_datasource.dart';
import '../../domain/entities/auth_entities.dart';

/// Auth remote data source provider.
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return SupabaseAuthRemoteDataSource();
});

/// Current user provider.
final currentUserProvider = FutureProvider<LyraUser?>((ref) async {
  final dataSource = ref.watch(authRemoteDataSourceProvider);
  final userModel = await dataSource.getCurrentUser();

  if (userModel == null) return null;

  return LyraUser(
    id: userModel.id,
    email: userModel.email,
    displayName: userModel.displayName,
    avatarUrl: userModel.avatarUrl,
    isEmailVerified: userModel.isEmailVerified,
    isAnonymous: userModel.isAnonymous,
  );
});

/// Auth state provider.
final authStateProvider = StreamProvider<LyraUser?>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);
  return dataSource.authStateChanges.map((userModel) {
    if (userModel == null) return null;
    return LyraUser(
      id: userModel.id,
      email: userModel.email,
      displayName: userModel.displayName,
      avatarUrl: userModel.avatarUrl,
      isEmailVerified: userModel.isEmailVerified,
      isAnonymous: userModel.isAnonymous,
    );
  });
});

/// Login with email provider.
final loginWithEmailProvider = Provider<Future<LyraUser> Function(String, String)>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);

  return (String email, String password) async {
    final userModel = await dataSource.loginWithEmail(
      email: email,
      password: password,
    );

    return LyraUser(
      id: userModel.id,
      email: userModel.email,
      displayName: userModel.displayName,
      avatarUrl: userModel.avatarUrl,
      isEmailVerified: userModel.isEmailVerified,
      isAnonymous: userModel.isAnonymous,
    );
  };
});

/// Register with email provider.
final registerWithEmailProvider = Provider<Future<LyraUser> Function(String, String, String?)>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);

  return (String email, String password, String? displayName) async {
    final userModel = await dataSource.registerWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );

    return LyraUser(
      id: userModel.id,
      email: userModel.email,
      displayName: userModel.displayName,
      avatarUrl: userModel.avatarUrl,
      isEmailVerified: userModel.isEmailVerified,
      isAnonymous: userModel.isAnonymous,
    );
  };
});

/// Login with Google provider.
final loginWithGoogleProvider = Provider<Future<LyraUser> Function()>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);

  return () async {
    final userModel = await dataSource.loginWithGoogle();

    return LyraUser(
      id: userModel.id,
      email: userModel.email,
      displayName: userModel.displayName,
      avatarUrl: userModel.avatarUrl,
      isEmailVerified: userModel.isEmailVerified,
      isAnonymous: userModel.isAnonymous,
    );
  };
});

/// Logout provider.
final logoutProvider = Provider<Future<void> Function()>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);

  return () async {
    await dataSource.logout();
  };
});

/// Is authenticated provider.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenData((user) => user != null).valueOrNull ?? false;
});
