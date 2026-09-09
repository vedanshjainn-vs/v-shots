// ═════════════════════════════════════════════════════════════════════════
// V Shots — Native Ad Widget (Unity LevelPlay)
//
// Renders a LevelPlay NATIVE ad (predefined SMALL template) inside the V
// Shots card system.
//
// Important lifecycle rule: LevelPlayNativeAdView MUST remain mounted while
// the ad is loading. The previous implementation returned SizedBox.shrink
// until _loaded became true, while loadAd() was only called from
// onPlatformViewCreated. That created a circular dependency:
//   view not mounted → platform view not created → loadAd never called →
//   onAdLoaded never fired → view stayed unmounted.
//
// The view is now mounted immediately after the native ad object is created;
// its visual opacity is held at zero until the SDK reports onAdLoaded. This
// preserves the existing fail-safe UX without blocking the actual request.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../../core/theme/app_colors.dart';
import 'ad_analytics.dart';
import 'ad_policy.dart';
import 'levelplay_config.dart';
import 'levelplay_service.dart';

/// A self-contained native ad card (LevelPlay SMALL template).
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({
    super.key,
    this.height = 175,
    this.placement = AdPlacement.home,
  });

  final double height;
  final AdPlacement placement;

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget>
    with LevelPlayNativeAdListener {
  LevelPlayNativeAd? _nativeAd;
  bool _loaded = false;
  bool _platformViewCreated = false;
  String? _loadError;

  String get _placementName => _vShotsPlacement(widget.placement);

  String _vShotsPlacement(AdPlacement placement) {
    switch (placement) {
      case AdPlacement.home:
        return LevelPlayPlacement.homeNative;
      case AdPlacement.forYouFeed:
        return LevelPlayPlacement.discoveryNative;
      case AdPlacement.player:
        return LevelPlayPlacement.playerNative;
      case AdPlacement.playlist:
      case AdPlacement.library:
        return LevelPlayPlacement.libraryNative;
      case AdPlacement.search:
        return LevelPlayPlacement.searchNative;
    }
  }

  @override
  void initState() {
    super.initState();
    if (AdPolicy.instance.adsAvailable &&
        VShotsLevelPlay.instance.initSucceeded) {
      _createAd();
    } else if (AdPolicy.instance.adsAvailable) {
      _initWhenReady();
    }
  }

  void _initWhenReady() {
    if (VShotsLevelPlay.instance.initSucceeded) {
      _createAd();
      return;
    }
    VShotsLevelPlay.instance.readyNotifier.addListener(_onReadyChanged);
  }

  void _onReadyChanged() {
    if (!mounted) return;
    if (!VShotsLevelPlay.instance.initSucceeded) return;
    VShotsLevelPlay.instance.readyNotifier.removeListener(_onReadyChanged);
    if (AdPolicy.instance.adsAvailable) {
      _createAd();
    }
  }

  void _createAd() {
    if (!mounted || _nativeAd != null) return;
    AdAnalytics.log(
      'ad_request',
      placement: widget.placement.key,
      detail: 'native',
    );
    VShotsLevelPlay.instance.noteActivity(
      'native',
      'REQUESTED (${widget.placement.key})',
    );
    _nativeAd = LevelPlayNativeAd.builder()
        .withPlacementName(_placementName)
        .withListener(this)
        .build();
    if (mounted) setState(() {});
  }

  void _loadNativeAdOnce() {
    final ad = _nativeAd;
    if (ad == null || _platformViewCreated) return;
    _platformViewCreated = true;
    VShotsLevelPlay.instance.noteActivity(
      'native',
      'SDK REQUESTED (${widget.placement.key})',
    );
    ad.loadAd();
  }

  @override
  void dispose() {
    VShotsLevelPlay.instance.readyNotifier.removeListener(_onReadyChanged);
    _nativeAd?.destroyAd();
    _nativeAd = null;
    super.dispose();
  }

  @override
  void onAdLoaded(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    VShotsLevelPlay.instance.noteFill('native', adInfo.adNetwork);
    VShotsLevelPlay.instance.noteActivity(
      'native',
      'LOADED (network: ${adInfo.adNetwork})',
    );
    AdAnalytics.log(
      'native_rendered',
      placement: widget.placement.key,
      detail: adInfo.adNetwork ?? '-',
    );
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void onAdImpression(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    VShotsLevelPlay.instance.noteActivity(
      'native',
      'DISPLAYED (network: ${adInfo.adNetwork})',
    );
    AdAnalytics.log(
      'ad_impression',
      placement: widget.placement.key,
      detail:
          'network=${adInfo.adNetwork ?? '-'} revenue=${adInfo.revenue ?? 0}',
    );
  }

  @override
  void onAdClicked(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    VShotsLevelPlay.instance.noteActivity('native', 'CLICKED');
  }

  @override
  void onAdLoadFailed(LevelPlayNativeAd nativeAd, dynamic error) {
    _loadError = '$error';
    VShotsLevelPlay.instance.noteActivity(
      'native',
      'LOAD FAILED — $_loadError',
    );
    AdAnalytics.log(
      'ad_load_failed',
      placement: widget.placement.key,
      detail: _loadError,
    );
    if (mounted) setState(() => _loaded = false);
  }

  @override
  Widget build(BuildContext context) {
    final ad = _nativeAd;
    if (!AdPolicy.instance.adsAvailable ||
        ad == null ||
        !VShotsLevelPlay.instance.initSucceeded ||
        _loadError != null) {
      return const SizedBox.shrink();
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
          SizedBox(
            height: widget.height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!_loaded) const SizedBox.shrink(),
                AnimatedOpacity(
                  opacity: _loaded ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: RepaintBoundary(
                    child: LevelPlayNativeAdView(
                      nativeAd: ad,
                      templateType: LevelPlayTemplateType.SMALL,
                      width: MediaQuery.sizeOf(context).width - 40,
                      height: widget.height,
                      onPlatformViewCreated: _loadNativeAdOnce,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
