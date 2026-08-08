// ════════════════════════════════════════════════
// Project Lyra — App Shell
// ════════════════════════════════════════════════
//
// Main scaffold with bottom navigation, mini player,
// and persistent layout structure.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_constants.dart';
import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';
import '../../../core/router/route_paths.dart';

/// Shell widget that wraps main tab screens.
///
/// Provides:
/// - Bottom navigation bar
/// - Mini player placeholder
/// - Consistent scaffold structure
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyra = Theme.of(context).extension<LyraThemeExtension>()!;

    return Scaffold(
      body: Stack(
        children: [
          // Main content area.
          child,

          // Mini player placeholder — sits above bottom nav.
          Positioned(
            left: lyra.spacingSm,
            right: lyra.spacingSm,
            bottom: AppConstants.bottomNavHeight + lyra.spacingSm,
            child: const _MiniPlayerPlaceholder(),
          ),
        ],
      ),
      bottomNavigationBar: const _BottomNav(),
    );
  }
}

/// Bottom navigation bar.
class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentIndex = _getCurrentIndex(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => _onTap(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music_rounded),
            label: 'Library',
          ),
        ],
      ),
    );
  }

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return switch (location) {
      _ when location.startsWith(RoutePaths.home) => 0,
      _ when location.startsWith(RoutePaths.explore) => 1,
      _ when location.startsWith(RoutePaths.library) => 2,
      _ => 0,
    };
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RoutePaths.home);
      case 1:
        context.go(RoutePaths.explore);
      case 2:
        context.go(RoutePaths.library);
    }
  }
}

/// Mini player widget — shows current track in a compact card.
/// TODO(team): Replace with actual mini player implementation.
class _MiniPlayerPlaceholder extends StatelessWidget {
  const _MiniPlayerPlaceholder();

  @override
  Widget build(BuildContext context) {
    // Hidden by default — shown when a track is playing.
    return const SizedBox.shrink();
  }
}
