// ════════════════════════════════════════════════
// Project Lyra — Shimmer Loading
// ════════════════════════════════════════════════
//
// Reusable shimmer loading widgets for various
// content types: tracks, albums, artists, etc.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// Horizontal shimmer row for media cards.
class ShimmerMediaRow extends StatelessWidget {
  const ShimmerMediaRow({
    this.itemCount = 4,
    this.cardWidth = 160,
    this.showTitle = true,
    super.key,
  });

  final int itemCount;
  final double cardWidth;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;

    return SizedBox(
      height: showTitle ? cardWidth + 50 : cardWidth,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: lyra.spacingSm),
            child: Shimmer.fromColors(
              baseColor: lyra.shimmerBase,
              highlightColor: lyra.shimmerHighlight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: cardWidth,
                    height: cardWidth,
                    decoration: BoxDecoration(
                      color: lyra.shimmerBase,
                      borderRadius: BorderRadius.circular(lyra.radiusLarge),
                    ),
                  ),
                  if (showTitle) ...[
                    SizedBox(height: lyra.spacingSm),
                    Container(
                      height: 12,
                      width: cardWidth * 0.7,
                      decoration: BoxDecoration(
                        color: lyra.shimmerBase,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(height: lyra.spacingXs),
                    Container(
                      height: 10,
                      width: cardWidth * 0.4,
                      decoration: BoxDecoration(
                        color: lyra.shimmerBase,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shimmer placeholder for section headers.
class ShimmerSectionHeader extends StatelessWidget {
  const ShimmerSectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;

    return Padding(
      padding: EdgeInsets.all(lyra.spacingMd),
      child: Shimmer.fromColors(
        baseColor: lyra.shimmerBase,
        highlightColor: lyra.shimmerHighlight,
        child: Container(
          height: 20,
          width: 150,
          decoration: BoxDecoration(
            color: lyra.shimmerBase,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
