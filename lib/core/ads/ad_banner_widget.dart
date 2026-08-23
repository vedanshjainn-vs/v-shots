// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Banner Widget (AppLovin MAX, in-flow)
//
// In-flow banner (MAX widget AdView) for placements where a banner fits the
// existing layout naturally (playlist pages, library bottom). It is a
// normal list item — never over playback controls, navigation, dialogs,
// or critical actions.
//
// Fail-safe: disabled / not configured / no fill / SDK error ⇒
// SizedBox.shrink (normal UI continues).
// ═════════════════════════════════════════════════════════════════════════

import 'package:applovin_max/applovin_max.dart' as max;
import 'package:flutter/material.dart';

import 'ad_policy.dart';
import 'max_config.dart';

/// A self-contained in-flow banner (MAX widget AdView, AdFormat.banner).
/// Renders nothing when the policy gate fails or the ad is not available.
class AdBannerWidget extends StatelessWidget {
  const AdBannerWidget({
    super.key,
    this.placement = AdPlacement.library,
  });

  final AdPlacement placement;

  @override
  Widget build(BuildContext context) {
    if (!AdPolicy.instance.canShowBanner(placement)) {
      return const SizedBox.shrink();
    }
    final unitId = MaxConfig.unitIdFor(MaxPlacement.bannerHome);
    if (unitId == null) return const SizedBox.shrink();

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: RepaintBoundary(
          child: SizedBox(
            height: 50,
            child: max.MaxAdView(
              adUnitId: unitId,
              adFormat: max.AdFormat.banner,
              placement: placement.key,
              isAdaptiveBannerEnabled: true,
            ),
          ),
        ),
      ),
    );
  }
}
