import 'package:flutter/material.dart';

import 'ad_policy.dart';
import 'mrec_ad_manager.dart';
import 'premium_mrec_ad_card.dart';

/// Backward-compatible wrapper for existing ad call sites.
/// All legacy native placements now use the real Unity LevelPlay MREC
/// MEDIUM_RECTANGLE (300x250). The player placement is intentionally empty:
/// MREC must never cover or interrupt playback controls.
class NativeAdWidget extends StatelessWidget {
  const NativeAdWidget({
    super.key,
    this.height = MRECConfig.height,
    this.placement = AdPlacement.home,
  });

  final double height;
  final AdPlacement placement;

  MRECPlacement? get _mrecPlacement => switch (placement) {
        AdPlacement.home => MRECPlacement.home,
        AdPlacement.forYouFeed => MRECPlacement.discoverFeed,
        AdPlacement.search => MRECPlacement.search,
        AdPlacement.playlist => MRECPlacement.playlist,
        AdPlacement.library => MRECPlacement.library,
        AdPlacement.player => null,
      };

  @override
  Widget build(BuildContext context) {
    final mrecPlacement = _mrecPlacement;
    if (mrecPlacement == null) return const SizedBox.shrink();
    return PremiumMRECAdCard(placement: mrecPlacement);
  }
}
