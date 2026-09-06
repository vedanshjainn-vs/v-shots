import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import 'ad_analytics.dart';
import 'ad_policy.dart';
import 'levelplay_config.dart';
import 'levelplay_service.dart';

/// Real embeddable LevelPlay Native ad page for Discovery.
/// No modal Interstitial, MREC, or fake/custom ad surface is used.
class DiscoverySwipeNativeAdPage extends StatefulWidget {
  const DiscoverySwipeNativeAdPage({
    super.key,
    required this.onUnavailable,
  });

  final VoidCallback onUnavailable;

  @override
  State<DiscoverySwipeNativeAdPage> createState() =>
      _DiscoverySwipeNativeAdPageState();
}

class _DiscoverySwipeNativeAdPageState extends State<DiscoverySwipeNativeAdPage>
    with LevelPlayNativeAdListener {
  LevelPlayNativeAd? _nativeAd;
  Timer? _loadTimeout;
  bool _platformViewCreated = false;
  bool _loaded = false;
  bool _unavailableSent = false;

  String get _placementName => LevelPlayPlacement.discoveryNative;

  @override
  void initState() {
    super.initState();
    _startWhenReady();
  }

  void _startWhenReady() {
    if (!AdPolicy.instance.adsAvailable) {
      _failClosed();
      return;
    }
    if (VShotsLevelPlay.instance.initSucceeded) {
      _createAd();
      return;
    }
    VShotsLevelPlay.instance.readyNotifier.addListener(_onReadyChanged);
  }

  void _onReadyChanged() {
    if (!mounted) return;
    VShotsLevelPlay.instance.readyNotifier.removeListener(_onReadyChanged);
    if (AdPolicy.instance.adsAvailable &&
        VShotsLevelPlay.instance.initSucceeded) {
      _createAd();
    } else {
      _failClosed();
    }
  }

  void _createAd() {
    if (!mounted || _nativeAd != null || !AdPolicy.instance.adsAvailable) {
      return;
    }
    AdAnalytics.log(
      'ad_request',
      placement: AdPlacement.forYouFeed.key,
      detail: 'discovery_swipe_native',
    );
    VShotsLevelPlay.instance.noteActivity(
      'native',
      'REQUESTED (discovery swipe)',
    );
    _nativeAd = LevelPlayNativeAd.builder()
        .withPlacementName(_placementName)
        .withListener(this)
        .build();

    // Never leave the user stranded on an ad page. If the platform view or
    // mediation request does not settle promptly, skip the ad page cleanly.
    _loadTimeout = Timer(const Duration(seconds: 4), _failClosed);
    if (mounted) setState(() {});
  }

  void _loadOnce() {
    final ad = _nativeAd;
    if (ad == null || _platformViewCreated) return;
    _platformViewCreated = true;
    VShotsLevelPlay.instance.noteActivity(
      'native',
      'SDK REQUESTED (discovery swipe)',
    );
    ad.loadAd();
  }

  void _failClosed() {
    if (_unavailableSent) return;
    _unavailableSent = true;
    _loadTimeout?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onUnavailable();
    });
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    VShotsLevelPlay.instance.readyNotifier.removeListener(_onReadyChanged);
    _nativeAd?.destroyAd();
    _nativeAd = null;
    super.dispose();
  }

  @override
  void onAdLoaded(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    _loadTimeout?.cancel();
    VShotsLevelPlay.instance.noteFill('native', adInfo.adNetwork);
    VShotsLevelPlay.instance.noteActivity(
      'native',
      'LOADED (discovery swipe, network: ${adInfo.adNetwork})',
    );
    AdAnalytics.log(
      'native_rendered',
      placement: AdPlacement.forYouFeed.key,
      detail: adInfo.adNetwork ?? '-',
    );
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void onAdImpression(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    VShotsLevelPlay.instance.noteActivity(
      'native',
      'DISPLAYED (discovery swipe, network: ${adInfo.adNetwork})',
    );
    AdAnalytics.log(
      'ad_impression',
      placement: AdPlacement.forYouFeed.key,
      detail:
          'network=${adInfo.adNetwork ?? '-'} revenue=${adInfo.revenue ?? 0}',
    );
  }

  @override
  void onAdClicked(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    VShotsLevelPlay.instance.noteActivity('native', 'CLICKED (discovery swipe)');
  }

  @override
  void onAdLoadFailed(LevelPlayNativeAd nativeAd, dynamic error) {
    _loadTimeout?.cancel();
    VShotsLevelPlay.instance.noteActivity(
      'native',
      'LOAD FAILED (discovery swipe) — $error',
    );
    AdAnalytics.log(
      'ad_load_failed',
      placement: AdPlacement.forYouFeed.key,
      detail: '$error',
    );
    _failClosed();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _nativeAd;
    if (ad == null ||
        !AdPolicy.instance.adsAvailable ||
        !VShotsLevelPlay.instance.initSucceeded) {
      return const SizedBox.expand();
    }

    final size = MediaQuery.sizeOf(context);
    final width = size.width.clamp(280.0, 420.0);
    final height = (size.height * 0.48).clamp(280.0, 420.0);

    return ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!_loaded)
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                // Keep the platform view mounted AND visible while loading.
                // Hiding a native PlatformView with AnimatedOpacity can cause
                // black/blank composition on Android; the SDK itself owns the
                // ad surface until onAdLoaded fires.
                RepaintBoundary(
                  child: LevelPlayNativeAdView(
                    nativeAd: ad,
                    templateType: LevelPlayTemplateType.SMALL,
                    width: width,
                    height: height,
                    onPlatformViewCreated: _loadOnce,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
