// ════════════════════════════════════════════════
// Project Lyra — Library Screen
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/extensions/color_extension.dart';
import '../../../../config/theme/extensions/theme_extension.dart';
import '../../../../config/theme/typography/app_typography.dart';
import '../../../../core/router/route_paths.dart';

enum LibraryTab { playlists, artists, albums, downloaded }

/// Library screen — user's saved content.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryTab _currentTab = LibraryTab.playlists;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text('Library', style: AppTypography.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(RoutePaths.profile),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd),
              children: LibraryTab.values.map((tab) {
                final isSelected = _currentTab == tab;
                return Padding(
                  padding: EdgeInsets.only(right: lyra.spacingSm),
                  child: GestureDetector(
                    onTap: () => setState(() => _currentTab = tab),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? colors.onSurface : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(lyra.radiusCircular),
                      ),
                      child: Text(
                        tab.name[0].toUpperCase() + tab.name.substring(1),
                        style: TextStyle(
                          color: isSelected ? colors.surface : colors.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: lyra.spacingMd),

          // Content
          Expanded(
            child: _buildTabContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    switch (_currentTab) {
      case LibraryTab.playlists:
        return _buildPlaylistsTab(context);
      case LibraryTab.artists:
        return _buildArtistsTab(context);
      case LibraryTab.albums:
        return _buildAlbumsTab(context);
      case LibraryTab.downloaded:
        return _buildDownloadedTab(context);
    }
  }

  Widget _buildPlaylistsTab(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return ListView(
      children: [
        // Create playlist button
        ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(lyra.radiusSm),
            ),
            child: Icon(Icons.add, color: colors.primary),
          ),
          title: Text('Create Playlist', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
          onTap: () {},
        ),

        // Liked songs
        ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A90D9), Color(0xFF7B68EE)],
              ),
              borderRadius: BorderRadius.circular(lyra.radiusSm),
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 24),
          ),
          title: const Text('Liked Songs'),
          subtitle: const Text('Playlist'),
          onTap: () => context.push(RoutePaths.likedSongs),
        ),

        // Playlists
        ...List.generate(
          5,
          (i) => ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(lyra.radiusSm),
              child: Container(
                width: 48,
                height: 48,
                color: colors.surfaceContainerHighest,
                child: Icon(Icons.music_note, color: colors.onSurfaceVariant),
              ),
            ),
            title: Text('Playlist ${i + 1}'),
            subtitle: Text('${10 + i * 5} songs'),
            onTap: () {},
          ),
        ),
        SizedBox(height: 100),
      ],
    );
  }

  Widget _buildArtistsTab(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return ListView.builder(
      itemCount: 10,
      itemBuilder: (_, i) => ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: colors.surfaceContainerHighest,
          child: Icon(Icons.person, color: colors.onSurfaceVariant),
        ),
        title: Text('Artist ${i + 1}'),
        subtitle: const Text('Following'),
        onTap: () {},
      ),
    );
  }

  Widget _buildAlbumsTab(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return GridView.builder(
      padding: EdgeInsets.all(lyra.spacingMd),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: lyra.spacingMd,
        mainAxisSpacing: lyra.spacingMd,
        childAspectRatio: 0.8,
      ),
      itemCount: 6,
      itemBuilder: (_, i) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(lyra.radiusLarge),
              ),
              child: Center(child: Icon(Icons.album, color: colors.onSurfaceVariant, size: 48)),
            ),
          ),
          SizedBox(height: lyra.spacingSm),
          Text('Album ${i + 1}', style: AppTypography.titleSmall),
          Text('Artist ${i + 1}', style: AppTypography.bodySmall.copyWith(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildDownloadedTab(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_done_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No Downloads', style: AppTypography.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Downloaded music will appear here',
              style: AppTypography.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
