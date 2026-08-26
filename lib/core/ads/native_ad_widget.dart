// ═════════════════════════════════════════════════════════════════════════
// V Shots — Native Ad Widget (Unity LevelPlay)
//
// Renders a LevelPlay NATIVE ad (predefined SMALL template) inside the V
// Shots card system:
//   • always shows the "Ad · Sponsored" label + the SDK's own AdChoices
//     element (inside the template) — never mistaken for music content
//   • visually follows the V Shots card system (bordered card, tag, no
//     play/like/next controls)
//   • policy-gated (AdPolicy): master + LevelPlay config + consent + ad-free
//   • fail-safe: unconfigured / blocked / no fill ⇒ SizedBox.shrink (the
//     normal V Shots UI remains — no fake/empty ad cards)
//
// LevelPlay native = ONE native ad unit per app (resolved from the app
// key); the V Shots stable placement name is passed per request for
// pacing/reporting.
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

  /// Height of the native template area (recommended SMALL = 175).
  final double height;
  final AdPlacement placement;

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget>
    with LevelPlayNativeAdListener {
  LevelPlayNativeAd? _nativeAd;
  bool _loaded = false;
  String? _loadError;

  String get _placementName => _vShotsPlacement(widget.placement);

  String _vShotsPlacement(AdPlacement placement) {
    switch (placement) {
      case AdPlacement.home:
        return LevelPlayPlacement.homeNative;
      case AdPlacement.forYouFeed:
        return LevelPlayPlacement.discoveryNative;
      case AdPlacement.player:
        return LevelPlayPlacement.playerNative; // reserved — never placed
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
      // SDK still initializing: wait (bounded) then create if ready.
      _initWhenReady();
    }
  }

  void _initWhenReady() {
    if (VShotsLevelPlay.instance.initSucceeded) {
      _createAd();
      return;
    }
    // Wait via the ready notifier (no timers — test-safe).
    VShotsLevelPlay.instance.readyNotifier.addListener(_onReadyChanged);
  }

  void _onReadyChanged() {
    VShotsLevelPlay.instance.readyNotifier.removeListener(_onReadyChanged);
    if (mounted &&
        AdPolicy.instance.adsAvailable &&
        VShotsLevelPlay.instance.initSucceeded) {
      _createAd();
    }
  }

  void _createAd() {
    if (!mounted) return;
    AdAnalytics.log('ad_request',
        placement: widget.placement.key, detail: 'native');
    _nativeAd = LevelPlayNativeAd.builder()
        .withPlacementName(_placementName)
        .withListener(this)
        .build();
  }

  @override
  void dispose() {
    VShotsLevelPlay.instance.readyNotifier.removeListener(_onReadyChanged);
    _nativeAd?.destroyAd();
    super.dispose();
  }

  // ── LevelPlayNativeAdListener ──────────────────────────────────────────

  @override
  void onAdLoaded(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    VShotsLevelPlay.instance.noteFill('native', adInfo.adNetwork);
    VShotsLevelPlay.instance
        .noteActivity('native', 'RENDERED (network: ${adInfo.adNetwork})');
    AdAnalytics.log('native_rendered',
        placement: widget.placement.key, detail: adInfo.adNetwork ?? '-');
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void onAdImpression(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    AdAnalytics.log('ad_impression',
        placement: widget.placement.key,
        detail:
            'network=${adInfo.adNetwork ?? '-'} revenue=${adInfo.revenue ?? 0}');
  }

  @override
  void onAdClicked(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    VShotsLevelPlay.instance.noteActivity('native', 'CLICKED');
  }

  @override
  void onAdLoadFailed(LevelPlayNativeAd nativeAd, dynamic error) {
    _loadError = '$error';
    VShotsLevelPlay.instance
        .noteActivity('native', 'LOAD FAILED — $_loadError');
    AdAnalytics.log('ad_load_failed',
        placement: widget.placement.key, detail: _loadError);
    if (mounted) setState(() => _loaded = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ad = _nativeAd;
    if (!AdPolicy.instance.adsAvailable ||
        ad == null ||
        !VShotsLevelPlay.instance.initSucceeded ||
        !_loaded) {
      // Honest fail-safe: normal V Shots UI, no fake/empty ad card.
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 300.0;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                child: LevelPlayNativeAdView(
                  nativeAd: ad,
                  templateType: LevelPlayTemplateType.SMALL,
                  width: width - 8,
                  height: widget.height,
                  onPlatformViewCreated: ad.loadAd,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
