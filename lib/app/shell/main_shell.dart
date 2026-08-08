// ════════════════════════════════════════════════
// Project Lyra — Main App Shell
// ════════════════════════════════════════════════
//
// Main scaffold with bottom navigation, mini player,
// and persistent layout structure.
// ════════════════════════════════════════════════

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/extensions/color_extension.dart';
import '../../config/theme/extensions/theme_extension.dart';
import '../../config/theme/typography/app_typography.dart';
import '../../core/router/route_paths.dart';

/// Main app shell with bottom nav and mini player.
class MainShell extends ConsumerWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyra = context.lyra;
    final colors = context.colors;
    final currentIndex = _getCurrentIndex(context);

    return Scaffold(
      body: Stack(
        children: [
          // Main content.
          child,

          // Mini player — sits above bottom nav.
          Positioned(
            left: lyra.spacingSm,
            right: lyra.spacingSm,
            bottom: 72,
            child: const _MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
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
      ),
    );
  }

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return switch (location) {
      _ when location.startsWith('/home') => 0,
      _ when location.startsWith('/explore') => 1,
      _ when location.startsWith('/library') => 2,
      _ => 0,
    };
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RoutePaths.home);
      case 1:
        context.go('/explore');
      case 2:
        context.go(RoutePaths.library);
    }
  }
}

/// Mini player widget — shows current track in a compact card.
class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    // TODO(team): Connect to player state provider.
    // Show only when a track is playing.
    // For now, show a placeholder.

    return GestureDetector(
      onTap: () => context.push(RoutePaths.player),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(lyra.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(lyra.radiusLarge),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Row(
              children: [
                // Artwork
                Container(
                  width: 48,
                  height: 48,
                  margin: EdgeInsets.all(lyra.spacingSm),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(lyra.radiusSm),
                  ),
                  child: Icon(Icons.music_note, color: colors.onSurfaceVariant, size: 24),
                ),

                // Track info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Track Title',
                        style: AppTypography.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Artist Name',
                        style: AppTypography.bodySmall.copyWith(color: colors.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Controls
                IconButton(
                  icon: Icon(Icons.play_arrow_rounded, color: colors.onSurface),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(Icons.skip_next_rounded, color: colors.onSurfaceVariant),
                  onPressed: () {},
                ),
                SizedBox(width: lyra.spacingSm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
