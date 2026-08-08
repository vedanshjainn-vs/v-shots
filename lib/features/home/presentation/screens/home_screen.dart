// ════════════════════════════════════════════════
// V Shots — Home Screen
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/extensions/color_extension.dart';
import '../../../../config/theme/extensions/theme_extension.dart';
import '../../../../config/theme/typography/app_typography.dart';
import '../../../../core/router/route_paths.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Home screen — main content feed.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyra = context.lyra;
    final colors = context.colors;
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            floating: true,
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: lyra.gradientPrimary,
                    borderRadius: BorderRadius.circular(lyra.radiusSm),
                  ),
                  child: Icon(Icons.music_note, size: 20, color: colors.onPrimary),
                ),
                SizedBox(width: lyra.spacingSm),
                Text('V Shots', style: AppTypography.headlineMedium),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push(RoutePaths.notifications),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push(RoutePaths.settings),
              ),
            ],
          ),

          // Welcome message
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(lyra.spacingMd),
              child: userAsync.when(
                data: (user) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${user?.displayName ?? 'User'}! 👋',
                      style: AppTypography.headlineLarge,
                    ),
                    SizedBox(height: lyra.spacingSm),
                    Text(
                      'What do you want to listen to today?',
                      style: AppTypography.bodyLarge.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => Text(
                  'Hello! 👋',
                  style: AppTypography.headlineLarge,
                ),
              ),
            ),
          ),

          // Trending section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Trending Now', style: AppTypography.headlineSmall),
                      TextButton(
                        onPressed: () {},
                        child: Text('See All', style: TextStyle(color: colors.primary)),
                      ),
                    ],
                  ),
                  SizedBox(height: lyra.spacingSm),
                ],
              ),
            ),
          ),

          // Trending cards
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd),
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(right: lyra.spacingSm),
                    child: _MusicCard(
                      title: 'Trending ${index + 1}',
                      subtitle: 'Artist ${index + 1}',
                      imageUrl: 'https://picsum.photos/200?random=$index',
                    ),
                  );
                },
              ),
            ),
          ),

          SizedBox(height: lyra.spacingLg).toSliver,

          // Recently Played section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recently Played', style: AppTypography.headlineSmall),
                  SizedBox(height: lyra.spacingSm),
                ],
              ),
            ),
          ),

          // Recently played cards
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd),
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(right: lyra.spacingSm),
                    child: _MusicCard(
                      title: 'Song ${index + 1}',
                      subtitle: 'Album ${index + 1}',
                      imageUrl: 'https://picsum.photos/200?random=${index + 10}',
                    ),
                  );
                },
              ),
            ),
          ),

          SizedBox(height: lyra.spacingLg).toSliver,

          // Quick Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick Actions', style: AppTypography.headlineSmall),
                  SizedBox(height: lyra.spacingMd),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.favorite,
                          label: 'Liked Songs',
                          color: Colors.red,
                          onTap: () => context.push(RoutePaths.likedSongs),
                        ),
                      ),
                      SizedBox(width: lyra.spacingSm),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.download,
                          label: 'Downloads',
                          color: Colors.green,
                          onTap: () => context.push(RoutePaths.downloads),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: lyra.spacingSm),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.history,
                          label: 'History',
                          color: Colors.orange,
                          onTap: () {},
                        ),
                      ),
                      SizedBox(width: lyra.spacingSm),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.workspace_premium,
                          label: 'Premium',
                          color: Colors.amber,
                          onTap: () => context.push(RoutePaths.premium),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom padding for mini player
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }
}

class _MusicCard extends StatelessWidget {
  const _MusicCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  final String title;
  final String subtitle;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return GestureDetector(
      onTap: () {},
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(lyra.radiusLarge),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(lyra.radiusLarge),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.music_note,
                    color: colors.onSurfaceVariant,
                    size: 48,
                  ),
                ),
              ),
            ),
            SizedBox(height: lyra.spacingSm),
            Text(
              title,
              style: AppTypography.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(lyra.spacingMd),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(lyra.radiusLarge),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(width: lyra.spacingSm),
            Text(
              label,
              style: AppTypography.titleSmall.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

extension _SliverBox on Widget {
  Widget get toSliver => SliverToBoxAdapter(child: this);
}
