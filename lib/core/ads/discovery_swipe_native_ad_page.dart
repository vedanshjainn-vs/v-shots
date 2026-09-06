import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import 'ad_analytics.dart';
import 'ad_policy.dart';
import 'levelplay_config.dart';
import 'levelplay_service.dart';

/// Full-viewport, swipeable Discovery ad page backed by the existing
/// LevelPlay Native ad format. This is an embeddable ad surface, not a
/// modal interstitial and not a custom/fake ad.
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
  bool _platformViewCreated = false;
  bool _loaded = false;
  bool _unavailableSent = false;

  String get _placementName => LevelPlayPlacement.discoveryNative;

  @override
  void initState() {
    super.initState();
    if (AdPolicy.instance.adsAvailable &&
        VShotsLevelPlay.instance.initSucceeded) {
      _createAd();
    } else if (AdPolicy.instance.adsAvailable) {
      VShotsLevelPlay.instance.readyNotifier.addListener(_onReadyChanged);
    } else {
      _failClosed();
    }
  }

  void _onReadyChanged() {
    if (!mounted) return;
    VShotsLevelPlay.instance.readyNotifier.removeListener(_onReadyChanged);
    if (!VShotsLevelPlay.instance.initSucceeded) {
      _failClosed();
      return;
    }
    if (AdPolicy.instance.adsAvailable) {
      _createAd();
    } else {
      _failClosed();
    }
  }

  void _createAd() {
    if (!mounted || _nativeAd != null) return;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onUnavailable();
    });
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
      return const ColoredBox(color: Colors.black);
    }

    final size = MediaQuery.sizeOf(context);

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: AnimatedOpacity(
            opacity: _loaded ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: RepaintBoundary(
              child: LevelPlayNativeAdView(
                nativeAd: ad,
                templateType: LevelPlayTemplateType.MEDIUM,
                width: size.width,
                height: size.height,
                onPlatformViewCreated: _loadOnce,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
