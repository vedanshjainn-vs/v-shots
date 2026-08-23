// ═════════════════════════════════════════════════════════════════════════
// V Shots — Native Ad Widget (AppLovin MAX)
//
// Renders a MAX native ad (custom template) as a clearly labeled card:
//   • always shows an "Ad · Sponsored" label + the SDK AdChoices
//     (MaxNativeAdOptionsView), so it can never be mistaken for content
//   • visually follows the V Shots card system (bordered card, tag, no
//     play/like/next controls)
//   • policy-gated (AdPolicy): master + MAX config + consent + ad-free
//   • fail-safe: unconfigured / blocked / no fill ⇒ SizedBox.shrink
//
// The platform view mounts as soon as policy allows; before the first ad
// loads a compact "Sponsored" strip is shown (clearly an ad slot, no
// broken-looking empty card).
// ═════════════════════════════════════════════════════════════════════════


import 'package:applovin_max/applovin_max.dart' as max;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'ad_analytics.dart';
import 'ad_policy.dart';
import 'max_config.dart';

/// A self-contained native ad card (MAX custom template).
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({
    super.key,
    this.height = 172,
    this.placement = AdPlacement.home,
  });

  /// Height of the ad template area (the "Ad · Sponsored" tag sits above).
  final double height;
  final AdPlacement placement;

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  bool _loaded = false;
  String? _loadError;

  String? get _unitId => MaxConfig.unitIdFor(_maxPlacement(widget.placement));

  @override
  Widget build(BuildContext context) {
    final unitId = _unitId;
    if (!AdPolicy.instance.adsAvailable || unitId == null) {
      return const SizedBox.shrink();
    }

    // Pre-fill: compact clearly-labeled strip (ad slot, not content).
    if (!_loaded) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: const Row(
          children: [
            Icon(Icons.adb_rounded, size: 16, color: AppColors.hotPink),
            SizedBox(width: 8),
            Text(
              'Ad · Sponsored',
              style: TextStyle(
                color: AppColors.hotPink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            Spacer(),
            Text(
              'Loading…',
              style: TextStyle(
                color: AppColors.textSubtle,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clearly-labeled Ad tag.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.hotPink.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Ad · Sponsored',
                style: TextStyle(
                  color: AppColors.hotPink,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          RepaintBoundary(
            child: SizedBox(
              height: widget.height,
              child: max.MaxNativeAdView(
                adUnitId: unitId,
                placement: widget.placement.key,
                listener: max.NativeAdListener(
                  onAdLoadedCallback: (ad) {
                    AdAnalytics.log('native_rendered',
                        placement: widget.placement.key,
                        detail: ad.networkName);
                    if (mounted) setState(() => _loaded = true);
                  },
                  onAdLoadFailedCallback: (adUnitId, error) {
                    _loadError = '${error.code.name}: ${error.message}';
                    AdAnalytics.log('ad_load_failed',
                        placement: widget.placement.key, detail: _loadError);
                    if (mounted) setState(() => _loaded = false);
                  },
                  onAdClickedCallback: (ad) {},
                ),
                child: _template(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// V Shots-style native template (dark, matches song cards).
  Widget _template() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const max.MaxNativeAdIconView(width: 52, height: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const max.MaxNativeAdTitleView(
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const max.MaxNativeAdAdvertiserView(
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                max.MaxNativeAdCallToActionView(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                    foregroundColor: AppColors.accent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // AdChoices / options icon (required for native ads).
          const max.MaxNativeAdOptionsView(width: 18, height: 18),
        ],
      ),
    );
  }

  String _maxPlacement(AdPlacement placement) {
    switch (placement) {
      case AdPlacement.home:
        return MaxPlacement.homeNative;
      case AdPlacement.forYouFeed:
        return MaxPlacement.discoveryNative;
      case AdPlacement.player:
        return MaxPlacement.playerNative; // reserved — never placed
      case AdPlacement.playlist:
      case AdPlacement.library:
        return MaxPlacement.libraryNative;
      case AdPlacement.search:
        return MaxPlacement.searchNative;
    }
  }
}
