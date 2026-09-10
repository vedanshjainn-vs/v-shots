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

    // Never leave the user stranded on an empty ad page. If mediation does not
    // settle promptly (within 1.5s), skip cleanly to the next video.
    _loadTimeout = Timer(const Duration(milliseconds: 1500), _failClosed);
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
    VShotsLevelPlay.instance
        .noteActivity('native', 'CLICKED (discovery swipe)');
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
    final cardWidth = (size.width - 32).clamp(280.0, 420.0);
    final cardHeight = (size.height * 0.42).clamp(240.0, 360.0);

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Container(
            width: cardWidth,
            height: cardHeight,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: LevelPlayNativeAdView(
                        nativeAd: ad,
                        templateType: LevelPlayTemplateType.SMALL,
                        width: cardWidth,
                        height: cardHeight,
                        onPlatformViewCreated: _loadOnce,
                      ),
                    ),
                  ),
                  if (!_loaded)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Sponsored',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF2E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
