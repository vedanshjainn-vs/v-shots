// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Banner Widget (Unity LevelPlay, in-flow)
//
// In-flow LevelPlay banner (BANNER 320×50) for placements where a banner
// fits the existing layout naturally (playlist pages, library bottom). It
// is a normal list item — never over playback controls, navigation,
// dialogs, login, or critical actions.
//
// Fail-safe: disabled / not configured / no fill / SDK error ⇒
// SizedBox.shrink (normal UI continues).
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import 'ad_analytics.dart';
import 'ad_policy.dart';
import 'levelplay_config.dart';
import 'levelplay_service.dart';

/// A self-contained in-flow banner (LevelPlay BANNER, 320×50).
/// Renders nothing when the policy gate fails or the ad is not available.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key, this.placement = AdPlacement.library});

  final AdPlacement placement;

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget>
    with LevelPlayBannerAdViewListener {
  late final GlobalKey<LevelPlayBannerAdViewState> _bannerKey;

  String? get _unitId =>
      LevelPlayConfig.unitIdFor(LevelPlayPlacement.bannerHome);

  @override
  void initState() {
    super.initState();
    _bannerKey = GlobalKey<LevelPlayBannerAdViewState>();
  }

  @override
  void dispose() {
    _bannerKey.currentState?.destroy();
    super.dispose();
  }

  // ── LevelPlayBannerAdViewListener ──────────────────────────────────────

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    VShotsLevelPlay.instance.noteFill('banner', adInfo.adNetwork);
    VShotsLevelPlay.instance.noteActivity(
      'widget_ad_view',
      'LOADED (network: ${adInfo.adNetwork})',
    );
    AdAnalytics.log(
      'ad_loaded',
      placement: widget.placement.key,
      detail: adInfo.adNetwork,
    );
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    VShotsLevelPlay.instance.noteActivity(
      'widget_ad_view',
      'LOAD FAILED — $error',
    );
    AdAnalytics.log(
      'ad_load_failed',
      placement: widget.placement.key,
      detail: '$error',
    );
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    AdAnalytics.log(
      'ad_displayed',
      placement: widget.placement.key,
      detail: 'network=${adInfo.adNetwork} revenue=${adInfo.revenue}',
    );
  }

  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {
    AdAnalytics.log(
      'ad_load_failed',
      placement: widget.placement.key,
      detail: 'display: $error',
    );
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  @override
  void onAdExpanded(LevelPlayAdInfo adInfo) {}

  @override
  void onAdCollapsed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdLeftApplication(LevelPlayAdInfo adInfo) {}

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unitId = _unitId;
    if (!AdPolicy.instance.canShowBanner(widget.placement) ||
        unitId == null ||
        !VShotsLevelPlay.instance.initSucceeded) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: RepaintBoundary(
          child: SizedBox(
            width: LevelPlayAdSize.BANNER.width.toDouble(),
            height: LevelPlayAdSize.BANNER.height.toDouble(),
            child: LevelPlayBannerAdView(
              key: _bannerKey,
              adUnitId: unitId,
              adSize: LevelPlayAdSize.BANNER,
              listener: this,
              placementName: widget.placement.key,
              onPlatformViewCreated: () => _bannerKey.currentState?.loadAd(),
            ),
          ),
        ),
      ),
    );
  }
}
