// ════════════════════════════════════════════════
// Project Lyra — Auth Guard
// ════════════════════════════════════════════════
//
// GoRouter redirect logic for authentication.
// Unauthenticated users → login.
// Authenticated users on auth pages → home.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../route_paths.dart';

/// Provider for the auth guard.
///
/// TODO(team): Wire up to actual auth state provider.
final authGuardProvider = Provider<AuthGuard>((ref) {
  return AuthGuard(ref: ref);
});

/// Controls navigation based on authentication state.
///
/// Implements [ChangeNotifier] so GoRouter can listen
/// for auth state changes and re-evaluate redirects.
class AuthGuard extends ChangeNotifier {
  AuthGuard({required Ref ref}) : _ref = ref;

  final Ref _ref;

  // TODO(team): Replace with actual auth state.
  bool _isAuthenticated = false;
  bool _hasCompletedOnboarding = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  /// Called by GoRouter on every navigation event.
  String? redirect(BuildContext context, GoRouterState state) {
    final path = state.matchedLocation;

    final isSplash = path == RoutePaths.splash;
    final isOnboarding = path == RoutePaths.onboarding;
    final isAuthPage = _isAuthPath(path);

    // Always allow splash to load.
    if (isSplash) return null;

    // Onboarding guard.
    if (!_hasCompletedOnboarding && !isOnboarding && !isAuthPage) {
      return RoutePaths.onboarding;
    }

    // Auth guard — redirect to login if not authenticated.
    if (!_isAuthenticated && !_isPublicPath(path)) {
      return RoutePaths.login;
    }

    // Redirect authenticated users away from auth pages.
    if (_isAuthenticated && (isAuthPage || isOnboarding)) {
      return RoutePaths.home;
    }

    return null; // No redirect needed.
  }

  /// Update auth state — triggers GoRouter re-evaluation.
  void setAuthenticated(bool value) {
    if (_isAuthenticated != value) {
      _isAuthenticated = value;
      notifyListeners();
    }
  }

  /// Update onboarding state.
  void setOnboardingComplete(bool value) {
    if (_hasCompletedOnboarding != value) {
      _hasCompletedOnboarding = value;
      notifyListeners();
    }
  }

  bool _isAuthPath(String path) {
    return path == RoutePaths.login ||
        path == RoutePaths.register ||
        path == RoutePaths.forgotPassword;
  }

  bool _isPublicPath(String path) {
    return _isAuthPath(path) || path == RoutePaths.onboarding;
  }
}
