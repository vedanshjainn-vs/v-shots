// ════════════════════════════════════════════════
// Project Lyra — Profile Screen
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/extensions/color_extension.dart';
import '../../../../config/theme/extensions/theme_extension.dart';
import '../../../../config/theme/typography/app_typography.dart';
import '../../../../core/router/route_paths.dart';

/// Profile screen — user profile and stats.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(RoutePaths.settings),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(lyra.spacingMd),
        children: [
          // Avatar and name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: colors.surfaceContainerHighest,
                  child: Icon(Icons.person, size: 48, color: colors.onSurfaceVariant),
                ),
                SizedBox(height: lyra.spacingMd),
                Text('User Name', style: AppTypography.headlineSmall),
                SizedBox(height: lyra.spacingXs),
                Text(
                  'user@example.com',
                  style: AppTypography.bodyMedium.copyWith(color: colors.onSurfaceVariant),
                ),
                SizedBox(height: lyra.spacingLg),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem(label: 'Playlists', value: '12'),
                    _StatItem(label: 'Following', value: '45'),
                    _StatItem(label: 'Followers', value: '128'),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: lyra.spacingXl),

          // Menu items
          _ProfileMenuItem(
            icon: Icons.favorite_outline,
            title: 'Liked Songs',
            onTap: () => context.push(RoutePaths.likedSongs),
          ),
          _ProfileMenuItem(
            icon: Icons.history,
            title: 'Listening History',
            onTap: () {},
          ),
          _ProfileMenuItem(
            icon: Icons.download_outlined,
            title: 'Downloads',
            onTap: () => context.push(RoutePaths.downloads),
          ),
          _ProfileMenuItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: () => context.push(RoutePaths.notifications),
          ),
          _ProfileMenuItem(
            icon: Icons.workspace_premium_outlined,
            title: 'Premium',
            onTap: () => context.push(RoutePaths.premium),
          ),
          _ProfileMenuItem(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () => context.push(RoutePaths.settings),
          ),
          SizedBox(height: lyra.spacingLg),

          // Sign out
          ListTile(
            leading: Icon(Icons.logout, color: colors.error),
            title: Text('Sign Out', style: TextStyle(color: colors.error)),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.headlineSmall),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.bodySmall.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        )),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
