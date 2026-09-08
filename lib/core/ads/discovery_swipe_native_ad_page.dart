import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import 'ad_analytics.dart';
import 'ad_policy.dart';
import 'levelplay_config.dart';
import 'levelplay_service.dart';

/// Real embeddable LevelPlay Native ad page for the Discovery PageView.
///
/// Interstitials are modal in the LevelPlay SDK and cannot be embedded as a
/// PageView child. Discovery therefore uses the existing Native ad format,
/// which can be rendered inline and swiped past like an ordinary feed page.
class DiscoverySwipeNativeAdPage extends StatefulWidget {
  const DiscoverySwipeNativeAdPage({
    super.key,
    this.onUnavailable,
  });

  final VoidCallback? onUnavailable;

  @override
  State<DiscoverySwipeNativeAdPage> createState() =>
      _DiscoverySwipeNativeAdPageState();
}

class _DiscoverySwipeNativeAdPageState
    extends State<DiscoverySwipeNativeAdPage>
    with LevelPlayNativeAdListener {
  LevelPlayNativeAd? _nativeAd;
  bool _platformViewCreated = false;
  bool _loaded = false;
  bool _failed = false;
  Timer? _timeout;
  VoidCallback? _readyListener;

  String get _placementName => LevelPlayPlacement.discoveryNative;

  @override
  void initState() {
    super.initState();
    if (!AdPolicy.instance.adsAvailable) {
      _failClosed();
      return;
    }
    if (VShotsLevelPlay.instance.initSucceeded) {
      _createAd();
    } else {
      _readyListener = _onLevelPlayReady;
      VShotsLevelPlay.instance.readyNotifier.addListener(_readyListener!);
      _timeout = Timer(const Duration(seconds: 4), _failClosed);
    }
  }

  void _onLevelPlayReady() {
    if (!mounted || _failed) return;
    if (!VShotsLevelPlay.instance.initSucceeded) return;
    final listener = _readyListener;
    if (listener != null) {
      VShotsLevelPlay.instance.readyNotifier.removeListener(listener);
      _readyListener = null;
    }
    _timeout?.cancel();
    _timeout = null;
    if (AdPolicy.instance.adsAvailable) {
      _createAd();
    } else {
      _failClosed();
    }
  }

  void _createAd() {
    if (!mounted || _failed || _nativeAd != null) return;
    _nativeAd = LevelPlayNativeAd.builder()
        .withPlacementName(_placementName)
        .withListener(this)
        .build();
    VShotsLevelPlay.instance.noteActivity(
      'native_discovery',
      'OBJECT CREATED',
    );
    AdAnalytics.log(
      'ad_request',
      placement: 'discovery_swipe',
      detail: 'native',
    );
    if (mounted) setState(() {});
  }

  void _loadNativeAd() {
    if (!mounted || _failed || _platformViewCreated) return;
    final ad = _nativeAd;
    if (ad == null) return;
    _platformViewCreated = true;
    VShotsLevelPlay.instance.noteActivity(
      'native_discovery',
      'LOAD REQUESTED',
    );
    ad.loadAd();
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 4), () {
      if (mounted && !_loaded) _failClosed();
    });
  }

  void _failClosed() {
    if (_failed) return;
    _failed = true;
    _timeout?.cancel();
    _timeout = null;
    final listener = _readyListener;
    if (listener != null) {
      VShotsLevelPlay.instance.readyNotifier.removeListener(listener);
      _readyListener = null;
    }
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onUnavailable?.call();
      });
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    final listener = _readyListener;
    if (listener != null) {
      VShotsLevelPlay.instance.readyNotifier.removeListener(listener);
    }
    _nativeAd?.destroyAd();
    _nativeAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _nativeAd;
    if (_failed || ad == null || !AdPolicy.instance.adsAvailable) {
      return const SizedBox.shrink();
    }

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: RepaintBoundary(
            child: LevelPlayNativeAdView(
              nativeAd: ad,
              templateType: LevelPlayTemplateType.SMALL,
              width: 350,
              height: 300,
              onPlatformViewCreated: _loadNativeAd,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void onAdLoaded(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    if (!mounted || _failed) return;
    _timeout?.cancel();
    _timeout = null;
    VShotsLevelPlay.instance.noteFill('native_discovery', adInfo.adNetwork);
    VShotsLevelPlay.instance.noteActivity(
      'native_discovery',
      'LOADED (network: ${adInfo.adNetwork})',
    );
    AdAnalytics.log(
      'native_rendered',
      placement: 'discovery_swipe',
      detail: adInfo.adNetwork ?? '-',
    );
    setState(() => _loaded = true);
  }

  @override
  void onAdImpression(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    VShotsLevelPlay.instance.noteActivity(
      'native_discovery',
      'DISPLAYED (network: ${adInfo.adNetwork})',
    );
    AdAnalytics.log(
      'ad_impression',
      placement: 'discovery_swipe',
      detail:
          'network=${adInfo.adNetwork ?? '-'} revenue=${adInfo.revenue ?? 0}',
    );
  }

  @override
  void onAdClicked(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    VShotsLevelPlay.instance.noteActivity('native_discovery', 'CLICKED');
  }

  @override
  void onAdLoadFailed(LevelPlayNativeAd nativeAd, dynamic error) {
    VShotsLevelPlay.instance.noteActivity(
      'native_discovery',
      'LOAD FAILED — $error',
    );
    AdAnalytics.log(
      'ad_load_failed',
      placement: 'discovery_swipe',
      detail: '$error',
    );
    _failClosed();
  }
}
