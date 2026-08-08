// ════════════════════════════════════════════════
// Project Lyra — Shimmer Effect
// ════════════════════════════════════════════════
//
// Loading skeleton placeholders for lists, cards,
// and content areas. Uses shimmer package.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// Shimmer loading skeleton for a card list.
///
/// Mimics the layout of actual content cards
/// so the UI doesn't jump when data loads.
class ShimmerCardList extends StatelessWidget {
  const ShimmerCardList({
    this.itemCount = 5,
    this.itemHeight = 72,
    super.key,
  });

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) => const ShimmerCard(),
    );
  }
}

/// Single shimmer card placeholder.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;

    return Padding(
      padding: EdgeInsets.only(bottom: lyra.spacingSm),
      child: Shimmer.fromColors(
        baseColor: lyra.shimmerBase,
        highlightColor: lyra.shimmerHighlight,
        child: Row(
          children: [
            // Album art placeholder
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: lyra.shimmerBase,
                borderRadius: BorderRadius.circular(lyra.radiusMedium),
              ),
            ),
            SizedBox(width: lyra.spacingMd),
            // Text placeholders
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: lyra.shimmerBase,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(height: lyra.spacingSm),
                  Container(
                    height: 12,
                    width: 120,
                    decoration: BoxDecoration(
                      color: lyra.shimmerBase,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer media card grid placeholder.
class ShimmerMediaGrid extends StatelessWidget {
  const ShimmerMediaGrid({
    this.itemCount = 6,
    this.crossAxisCount = 2,
    super.key,
  });

  final int itemCount;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: lyra.spacingMd,
        mainAxisSpacing: lyra.spacingMd,
        childAspectRatio: 0.75,
      ),
      padding: EdgeInsets.all(lyra.spacingMd),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: lyra.shimmerBase,
          highlightColor: lyra.shimmerHighlight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Square artwork placeholder
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: lyra.shimmerBase,
                    borderRadius: BorderRadius.circular(lyra.radiusLarge),
                  ),
                ),
              ),
              SizedBox(height: lyra.spacingSm),
              // Title placeholder
              Container(
                height: 12,
                width: 100,
                decoration: BoxDecoration(
                  color: lyra.shimmerBase,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: lyra.spacingXs),
              // Subtitle placeholder
              Container(
                height: 10,
                width: 70,
                decoration: BoxDecoration(
                  color: lyra.shimmerBase,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
