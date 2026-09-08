import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import 'ad_analytics.dart';
import 'ad_policy.dart';
import 'levelplay_config.dart';
import 'levelplay_service.dart';

/// Real embeddable LevelPlay swipeable ad card for the Discovery feed.
/// TikTok/Reels style in-feed card: user can swipe past it at ANY time.
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
    with LevelPlayBannerAdViewListener {
  final GlobalKey<LevelPlayBannerAdViewState> _bannerKey =
      GlobalKey<LevelPlayBannerAdViewState>();

  bool _isLoaded = false;
  bool _loadInFlight = false;

  String? get _unitId =>
      LevelPlayConfig.unitIdFor(LevelPlayPlacement.bannerHome);

  @override
  void initState() {
    super.initState();
    if (!AdPolicy.instance.adsAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onUnavailable?.call();
      });
    }
  }

  @override
  void dispose() {
    _bannerKey.currentState?.destroy();
    super.dispose();
  }

  void _loadAd() {
    if (!mounted || _loadInFlight || _isLoaded) return;
    _loadInFlight = true;
    _bannerKey.currentState?.loadAd();
  }

  @override
  Widget build(BuildContext context) {
    final unitId = _unitId;
    if (unitId == null || !AdPolicy.instance.adsAvailable) {
      return const SizedBox.expand();
    }

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sponsored Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFFFF2E93),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Sponsored',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // 300x250 Real LevelPlay Card
              Container(
                width: 300,
                height: 250,
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
                    children: [
                      Positioned.fill(
                        child: LevelPlayBannerAdView(
                          key: _bannerKey,
                          adUnitId: unitId,
                          adSize: LevelPlayAdSize.MEDIUM_RECTANGLE,
                          listener: this,
                          onPlatformViewCreated: _loadAd,
                        ),
                      ),
                      if (!_isLoaded)
                        const IgnorePointer(
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFF2E93),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Swipe Up To Continue Hint
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white54,
                    size: 22,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Swipe up to continue',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    if (!mounted) return;
    setState(() => _isLoaded = true);
    VShotsLevelPlay.instance.noteFill('mrec_discovery', adInfo.adNetwork);
    AdAnalytics.log('mrec_loaded', placement: 'discovery_swipe');
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    VShotsLevelPlay.instance.noteActivity(
      'discovery_swipe',
      'LOAD FAILED — $error',
    );
    AdAnalytics.log(
      'mrec_load_failed',
      placement: 'discovery_swipe',
      detail: '$error',
    );
    widget.onUnavailable?.call();
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    AdAnalytics.log('mrec_displayed', placement: 'discovery_swipe');
  }

  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {}

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  @override
  void onAdExpanded(LevelPlayAdInfo adInfo) {}

  @override
  void onAdCollapsed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdLeftApplication(LevelPlayAdInfo adInfo) {}
}
