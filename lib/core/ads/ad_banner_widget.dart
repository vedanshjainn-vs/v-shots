// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Banner Widget (banner / MREC)
//
// Self-contained in-flow banner. Only used in placements where a banner fits
// the existing layout naturally (playlist pages, library) — see AdPolicy.
// Never placed over playback controls, navigation, dialogs, or critical
// actions; it is a normal list item at the bottom of scrollable content.
//
// Fail-safe: disabled / no fill / SDK error ⇒ SizedBox.shrink (normal UI).
//
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_analytics.dart';
import 'ad_config.dart';
import 'ad_manager.dart';
import 'ad_policy.dart';
import 'consent_manager.dart';

/// A self-contained banner ad card (default: 320×50 banner; pass [size] for
/// MREC, e.g. `AdSize.mediumRectangle`). Renders nothing when the policy
/// gate fails or the ad does not load.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({
    super.key,
    this.placement = AdPlacement.library,
    this.size = AdSize.banner,
  });

  final AdPlacement placement;
  final AdSize size;

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (AdPolicy.instance.canShowBanner(widget.placement)) {
      unawaited(_loadWhenReady());
    }
  }

  Future<void> _loadWhenReady() async {
    await AdManager.instance.waitForReady(timeout: const Duration(seconds: 5));
    if (!mounted || !AdPolicy.instance.canShowBanner(widget.placement)) {
      return;
    }
    _loadAd();
  }

  void _loadAd() {
    AdAnalytics.log('ad_request', placement: widget.placement.key);
    final banner = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: widget.size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          AdAnalytics.log('ad_loaded', placement: widget.placement.key);
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          AdAnalytics.log('ad_load_failed',
              placement: widget.placement.key, detail: error.message);
          ad.dispose();
          _banner = null;
          if (mounted) setState(() => _loaded = false);
        },
        onAdOpened: (ad) =>
            AdAnalytics.log('ad_impression', placement: widget.placement.key),
      ),
      request: ConsentManager.instance.buildAdRequest(),
    )..load();
    _banner = banner;
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdPolicy.instance.canShowBanner(widget.placement) ||
        !_loaded ||
        _banner == null) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: AdWidget(ad: _banner!),
      ),
    );
  }
}
