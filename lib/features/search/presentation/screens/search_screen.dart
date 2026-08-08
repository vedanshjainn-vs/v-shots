// ════════════════════════════════════════════════
// Project Lyra — Search Screen
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/extensions/color_extension.dart';
import '../../../../config/theme/extensions/theme_extension.dart';
import '../../../../config/theme/typography/app_typography.dart';
import '../../../../core/utils/helpers/debounce_helper.dart';
import '../../../../shared/widgets/lyra_components/lyra_section_header.dart';
import '../../domain/entities/search_entities.dart';

/// Search screen with suggestions, recent searches, and results.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _debouncer = Debouncer(milliseconds: 400);
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(lyra.radiusLarge),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            autofocus: true,
            onChanged: (v) {
              _debouncer.run(() => setState(() => _query = v));
            },
            style: TextStyle(color: colors.onSurface),
            decoration: InputDecoration(
              hintText: 'Search songs, artists, podcasts...',
              hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
              prefixIcon: Icon(Icons.search_rounded, color: colors.onSurfaceVariant),
              suffixIcon: _query.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      child: Icon(Icons.close_rounded, color: colors.onSurfaceVariant),
                    )
                  : GestureDetector(
                      onTap: () {},
                      child: Icon(Icons.mic_rounded, color: colors.onSurfaceVariant),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      body: _query.isEmpty ? _buildDiscoverContent(context) : _buildSearchResults(context),
    );
  }

  Widget _buildDiscoverContent(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return ListView(
      children: [
        SizedBox(height: lyra.spacingMd),

        // Recent searches
        LyraSectionHeader(
          title: 'Recent Searches',
          actionText: 'Clear',
          onViewAll: () {},
        ),
        ...List.generate(
          3,
          (i) => ListTile(
            leading: Icon(Icons.history, color: colors.onSurfaceVariant),
            title: Text('Recent search ${i + 1}'),
            trailing: Icon(Icons.close, size: 18, color: colors.onSurfaceVariant),
            onTap: () {},
          ),
        ),

        SizedBox(height: lyra.spacingLg),

        // Browse categories
        LyraSectionHeader(title: 'Browse All'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: lyra.spacingSm,
            mainAxisSpacing: lyra.spacingSm,
            childAspectRatio: 2,
            children: [
              _CategoryCard(title: 'Pop', color: const Color(0xFFE91E63), icon: Icons.music_note),
              _CategoryCard(title: 'Hip-Hop', color: const Color(0xFF9C27B0), icon: Icons.mic),
              _CategoryCard(title: 'Rock', color: const Color(0xFF2196F3), icon: Icons.electric_bolt),
              _CategoryCard(title: 'R&B', color: const Color(0xFFFF9800), icon: Icons.favorite),
              _CategoryCard(title: 'Podcasts', color: const Color(0xFF4CAF50), icon: Icons.podcasts),
              _CategoryCard(title: 'Audiobooks', color: const Color(0xFF795548), icon: Icons.menu_book),
            ],
          ),
        ),
        SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    // TODO(team): Connect to search repository.
    return ListView(
      children: [
        SizedBox(height: lyra.spacingMd),
        LyraSectionHeader(title: 'Top Results'),
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
            title: Text('Result ${i + 1}'),
            subtitle: Text('Artist ${i + 1}'),
            onTap: () {},
          ),
        ),
        SizedBox(height: 100),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.title, required this.color, required this.icon});

  final String title;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
