// ═════════════════════════════════════════════════════════════════════════
// V Shots — Premium Native Ad Widget
//
// Renders a Google AdMob NATIVE ad (medium template) as a clearly labeled,
// premium card. It:
//   - always shows an "Ad / Sponsored" label + Google AdChoices (the template
//     includes AdChoices placement)
//   - is visually distinct from organic song cards (bordered card, tag, no
//     play/like/next controls), so it can never be mistaken for content
//   - never sits over the YouTube player or player controls
//   - only renders when AdPolicy allows (ads enabled AND not ad-free AND
//     consent settled) AND a native ad has loaded
//
// Fail-safe: any block/failure ⇒ renders an empty box (normal UI continues).
//
// No ad is ever shown unless the policy gate passes, and the widget returns
// an empty box otherwise (dev/store builds never show test ads to real users
// unless ADMOB_TEST_MODE is explicitly set in a debug build).
//
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/theme/app_colors.dart';
import 'ad_analytics.dart';
import 'ad_config.dart';
import 'ad_manager.dart';
import 'ad_policy.dart';
import 'consent_manager.dart';

/// A self-contained native ad card. Loads one native ad on init and disposes
/// it on dispose. Renders nothing when ads are disabled or the ad fails.
///
/// [placement] is used for policy + analytics only.
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({
    super.key,
    this.height = 132,
    this.placement = AdPlacement.home,
  });

  final double height;
  final AdPlacement placement;

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (AdPolicy.instance.adsAvailable) {
      unawaited(_loadWhenReady());
    }
  }

  Future<void> _loadWhenReady() async {
    // Ad init is non-blocking at startup — wait a bounded moment so the SDK
    // is ready; if it isn't, fail safe (no ad, normal UI).
    await AdManager.instance.waitForReady(timeout: const Duration(seconds: 5));
    if (!mounted || !AdPolicy.instance.adsAvailable) return;
    _loadAd();
  }

  void _loadAd() {
    final ad = NativeAd(
      adUnitId: AdConfig.nativeAdUnitId,
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.accent,
          style: NativeTemplateFontStyle.bold,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.textMain,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.textMuted,
        ),
        mainBackgroundColor: AppColors.surface,
        cornerRadius: 12.0,
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          AdAnalytics.log('native_rendered', placement: widget.placement.key);
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          AdAnalytics.log('ad_load_failed',
              placement: widget.placement.key, detail: error.message);
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
        },
        onAdImpression: (_) =>
            AdAnalytics.log('ad_impression', placement: widget.placement.key),
        onAdClicked: (_) =>
            AdAnalytics.log('ad_closed', placement: widget.placement.key),
      ),
      request: ConsentManager.instance.buildAdRequest(),
    )..load();
    _nativeAd = ad;
    AdAnalytics.log('ad_request', placement: widget.placement.key);
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdPolicy.instance.adsAvailable || !_loaded || _nativeAd == null) {
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
          SizedBox(
            height: widget.height,
            child: AdWidget(ad: _nativeAd!),
          ),
        ],
      ),
    );
  }
}
