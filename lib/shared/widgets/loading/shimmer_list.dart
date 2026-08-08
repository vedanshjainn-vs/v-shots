// ════════════════════════════════════════════════
// Project Lyra — Shimmer Loading Widgets
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// Shimmer loading for track list.
class ShimmerTrackList extends StatelessWidget {
  const ShimmerTrackList({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd),
      itemBuilder: (_, __) => Padding(
        padding: EdgeInsets.only(bottom: lyra.spacingSm),
        child: Shimmer.fromColors(
          baseColor: lyra.shimmerBase,
          highlightColor: lyra.shimmerHighlight,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: lyra.shimmerBase,
                  borderRadius: BorderRadius.circular(lyra.radiusSm),
                ),
              ),
              SizedBox(width: lyra.spacingMd),
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
      ),
    );
  }
}

/// Shimmer loading for horizontal card list.
class ShimmerCardRow extends StatelessWidget {
  const ShimmerCardRow({super.key, this.itemCount = 4, this.cardWidth = 160});

  final int itemCount;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    return SizedBox(
      height: cardWidth + 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: lyra.spacingMd),
        itemCount: itemCount,
        itemBuilder: (_, __) => Padding(
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
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer loading for section header.
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
