import 'package:flutter/material.dart';

import 'ad_policy.dart';
import 'mrec_ad_manager.dart';
import 'premium_mrec_ad_card.dart';

/// Backward-compatible wrapper for existing placements.
///
/// All legacy NativeAdWidget call sites now render the real Unity LevelPlay
/// MEDIUM_RECTANGLE (300x250) MREC. Keeping this class avoids touching the
/// surrounding Home/Search/Discover layout code and prevents unrelated UI
/// regressions.
class NativeAdWidget extends StatelessWidget {
  const NativeAdWidget({
    super.key,
    this.height = MRECConfig.height,
    this.placement = AdPlacement.home,
  });

  // Kept for source compatibility with older callers. MREC has a fixed
  // 300x250 LevelPlay size and therefore intentionally ignores this value.
  final double height;
  final AdPlacement placement;

  MRECPlacement get _mrecPlacement => switch (placement) {
        AdPlacement.home => MRECPlacement.home,
        AdPlacement.forYouFeed => MRECPlacement.discoverFeed,
        AdPlacement.search => MRECPlacement.search,
        AdPlacement.playlist => MRECPlacement.playlist,
        AdPlacement.library => MRECPlacement.library,
        AdPlacement.player => MRECPlacement.discoverDwell,
      };

  @override
  Widget build(BuildContext context) {
    return PremiumMRECAdCard(placement: _mrecPlacement);
  }
}
