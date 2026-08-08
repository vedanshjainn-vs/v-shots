// ════════════════════════════════════════════════
// Project Lyra — GoRouter Configuration
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell/main_shell.dart';
import '../../app/observers/app_router_observer.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/player/presentation/screens/player_screen.dart';
import '../../features/premium/presentation/screens/premium_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import 'guards/auth_guard.dart';
import 'route_names.dart';
import 'route_paths.dart';

/// Provider for the app's [GoRouter] instance.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authGuard = ref.watch(authGuardProvider);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: true,
    observers: [AppRouterObserver()],
    redirect: authGuard.redirect,
    refreshListenable: authGuard,
    routes: [
      // ── Splash ─────────────────────────────
      GoRoute(
        path: RoutePaths.splash,
        name: RouteNames.splash,
        builder: (_, __) => const SplashScreen(),
      ),

      // ── Onboarding ─────────────────────────
      GoRoute(
        path: RoutePaths.onboarding,
        name: RouteNames.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),

      // ── Auth ───────────────────────────────
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.register,
        name: RouteNames.register,
        builder: (_, __) => const _PlaceholderScreen('Register'),
      ),

      // ── Main Shell (Bottom Navigation) ─────
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.home,
            name: RouteNames.home,
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/explore',
            name: 'explore',
            builder: (_, __) => const SearchScreen(),
          ),
          GoRoute(
            path: RoutePaths.library,
            name: RouteNames.library,
            builder: (_, __) => const LibraryScreen(),
          ),
        ],
      ),

      // ── Player (full-screen) ───────────────
      GoRoute(
        path: RoutePaths.player,
        name: RouteNames.player,
        pageBuilder: (_, __) => CustomTransitionPage(
          child: const PlayerScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      ),

      // ── Detail pages ───────────────────────
      GoRoute(
        path: RoutePaths.track,
        name: RouteNames.track,
        builder: (_, state) => _PlaceholderScreen('Track: ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: RoutePaths.album,
        name: RouteNames.album,
        builder: (_, state) => _PlaceholderScreen('Album: ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: RoutePaths.artist,
        name: RouteNames.artist,
        builder: (_, state) => _PlaceholderScreen('Artist: ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: RoutePaths.playlist,
        name: RouteNames.playlist,
        builder: (_, state) => _PlaceholderScreen('Playlist: ${state.pathParameters['id']}'),
      ),

      // ── Feature pages ──────────────────────
      GoRoute(
        path: RoutePaths.profile,
        name: RouteNames.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.premium,
        name: RouteNames.premium,
        builder: (_, __) => const PremiumScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        name: RouteNames.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.downloads,
        name: RouteNames.downloads,
        builder: (_, __) => const _PlaceholderScreen('Downloads'),
      ),
      GoRoute(
        path: RoutePaths.likedSongs,
        name: RouteNames.likedSongs,
        builder: (_, __) => const _PlaceholderScreen('Liked Songs'),
      ),
      GoRoute(
        path: RoutePaths.search,
        name: RouteNames.search,
        builder: (_, __) => const SearchScreen(),
      ),
    ],
  );
});

/// Temporary placeholder for unimplemented screens.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}
