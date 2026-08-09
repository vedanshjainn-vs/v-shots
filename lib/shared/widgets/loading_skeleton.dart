// ═════════════════════════════════════════════════════════════════════════════
// V Shots — LoadingSkeleton (Nova Design System with Shimmer)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';

class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceElevated,
      period: const Duration(milliseconds: 1400),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(borderRadius) : null,
        ),
      ),
    );
  }
}

/// Pre-built Skeleton for Shot Cards
class ShotCardSkeleton extends StatelessWidget {
  const ShotCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LoadingSkeleton(width: 44, height: 44, shape: BoxShape.circle),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoadingSkeleton(width: 120, height: 14),
                    SizedBox(height: 6),
                    LoadingSkeleton(width: 80, height: 11),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: LoadingSkeleton(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 14,
              ),
            ),
            SizedBox(height: 14),
            LoadingSkeleton(width: double.infinity, height: 14),
            SizedBox(height: 8),
            LoadingSkeleton(width: 180, height: 12),
          ],
        ),
      ),
    );
  }
}
