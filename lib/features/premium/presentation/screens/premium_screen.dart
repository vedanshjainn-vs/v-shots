// ════════════════════════════════════════════════
// Project Lyra — Premium Screen
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/extensions/color_extension.dart';
import '../../../../config/theme/extensions/theme_extension.dart';
import '../../../../config/theme/typography/app_typography.dart';

/// Premium subscription screen.
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.primary,
                      colors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 64, color: colors.onPrimary),
                      SizedBox(height: lyra.spacingMd),
                      Text(
                        'Go Premium',
                        style: AppTypography.headlineLarge.copyWith(color: colors.onPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(lyra.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Benefits
                  Text('Why Premium?', style: AppTypography.headlineSmall),
                  SizedBox(height: lyra.spacingMd),
                  _BenefitRow(icon: Icons.music_off, title: 'Ad-free listening', description: 'Enjoy music without interruptions'),
                  _BenefitRow(icon: Icons.download, title: 'Offline mode', description: 'Download and listen anywhere'),
                  _BenefitRow(icon: Icons.high_quality, title: 'High quality audio', description: 'Stream in 320kbps'),
                  _BenefitRow(icon: Icons.skip_next, title: 'Unlimited skips', description: 'Skip as many tracks as you want'),
                  SizedBox(height: lyra.spacingXl),

                  // Plans
                  Text('Choose Your Plan', style: AppTypography.headlineSmall),
                  SizedBox(height: lyra.spacingMd),
                  _PlanCard(
                    title: 'Individual',
                    price: '₹119',
                    period: '/month',
                    features: ['1 account', 'Ad-free', 'Offline', 'High quality'],
                    isPopular: true,
                    onTap: () {},
                  ),
                  SizedBox(height: lyra.spacingMd),
                  _PlanCard(
                    title: 'Family',
                    price: '₹179',
                    period: '/month',
                    features: ['Up to 6 accounts', 'Ad-free', 'Offline', 'High quality'],
                    onTap: () {},
                  ),
                  SizedBox(height: lyra.spacingMd),
                  _PlanCard(
                    title: 'Student',
                    price: '₹59',
                    period: '/month',
                    features: ['1 account', 'Ad-free', 'Offline', 'High quality'],
                    onTap: () {},
                  ),
                  SizedBox(height: lyra.spacingXl),

                  // Restore purchase
                  Center(
                    child: TextButton(
                      onPressed: () {},
                      child: Text('Restore Purchase', style: TextStyle(color: colors.primary)),
                    ),
                  ),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: lyra.spacingMd),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(lyra.radiusMd),
            ),
            child: Icon(icon, color: colors.primary),
          ),
          SizedBox(width: lyra.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall),
                Text(description, style: AppTypography.bodySmall.copyWith(color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.onTap,
    this.isPopular = false,
  });

  final String title;
  final String price;
  final String period;
  final List<String> features;
  final VoidCallback onTap;
  final bool isPopular;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(lyra.spacingMd),
        decoration: BoxDecoration(
          color: isPopular ? colors.primaryContainer : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(lyra.radiusLarge),
          border: isPopular ? Border.all(color: colors.primary, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPopular)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(lyra.radiusCircular),
                ),
                child: Text('POPULAR', style: TextStyle(color: colors.onPrimary, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            SizedBox(height: lyra.spacingSm),
            Text(title, style: AppTypography.titleLarge),
            SizedBox(height: lyra.spacingSm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price, style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w700)),
                Text(period, style: AppTypography.bodyMedium.copyWith(color: colors.onSurfaceVariant)),
              ],
            ),
            SizedBox(height: lyra.spacingMd),
            ...features.map((f) => Padding(
              padding: EdgeInsets.only(bottom: lyra.spacingXs),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: colors.primary),
                  SizedBox(width: lyra.spacingSm),
                  Text(f, style: AppTypography.bodyMedium),
                ],
              ),
            )),
            SizedBox(height: lyra.spacingMd),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                child: Text('Subscribe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
