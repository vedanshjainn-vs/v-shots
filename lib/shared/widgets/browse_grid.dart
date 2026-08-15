// ═════════════════════════════════════════════════════════════════════════
// V Shots — Browse Grid (ArchiveTune-inspired "grid of categories" layout)
//
// An original Flutter reimplementation of the ArchiveTune "Browse" look
// (Material-3 style, rounded colored category cards in a responsive grid).
// It is NOT a copy of ArchiveTune's code (that repo is GPL Kotlin). Tapping a
// card opens a mood/genre search scaffold that plays through V Shots' official
// YouTube IFrame player.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BrowseCategory {
  const BrowseCategory(this.label, this.emoji, this.color, this.query);
  final String label;
  final String emoji;
  final Color color;
  final String query;
}

const List<BrowseCategory> kBrowseCategories = [
  BrowseCategory('Trending', '🔥', Color(0xFFE91E63),
      'trending hits viral songs official audio'),
  BrowseCategory('Romantic', '💖', Color(0xFFEC4899),
      'romantic love songs official audio hindi'),
  BrowseCategory(
      'Party', '🎉', Color(0xFF7C3AED), 'party dance bollywood punjabi hits'),
  BrowseCategory('Chill', '😌', Color(0xFF22D3EE),
      'chill lofi sleep beats official audio'),
  BrowseCategory(
      'Workout', '💪', Color(0xFFF59E0B), 'workout gym motivation hype songs'),
  BrowseCategory(
      'Sad', '🌧️', Color(0xFF64748B), 'sad heartbroken emotional songs'),
  BrowseCategory('Devotional', '🙏', Color(0xFF8B5CF6),
      'devotional bhajan aarti official audio'),
  BrowseCategory(
      'Hip-Hop', '🎤', Color(0xFF111827), 'hip hop rap desi english songs'),
  BrowseCategory(
      'EDM', '🎧', Color(0xFF0891B2), 'edm electronic dance music hits'),
  BrowseCategory('Bollywood', '🎬', Color(0xFFE91E63),
      'top bollywood hindi songs official'),
  BrowseCategory('Punjabi', '🥁', Color(0xFFFF9800),
      'latest punjabi pop hits official audio'),
  BrowseCategory('English Pop', '🌍', Color(0xFF2196F3),
      'top english pop billboard hits official'),
];

/// A responsive grid of category cards (ArchiveTune Browse style). Safe area
/// respected; each card is tappable and opens a genre search scaffold.
class BrowseGrid extends StatelessWidget {
  const BrowseGrid({
    super.key,
    this.categories = kBrowseCategories,
    this.onCategoryTap,
  });

  final List<BrowseCategory> categories;
  final void Function(BrowseCategory)? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 4),
          child: Row(
            children: [
              Icon(Icons.explore_rounded, size: 20, color: AppColors.accent),
              SizedBox(width: 8),
              Text(
                'Browse',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
            'Explore by mood, genre and language',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: categories.length,
            itemBuilder: (context, i) {
              final c = categories[i];
              return GestureDetector(
                onTap: () => onCategoryTap?.call(c),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        c.color.withValues(alpha: 0.28),
                        c.color.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.color.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Text(c.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 12, color: AppColors.textMuted),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
