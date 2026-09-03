// ═════════════════════════════════════════════════════════════════════════
// V Shots — Premium MREC Ad Card (Unity LevelPlay 300×250)
//
// Premium ad container for MREC 300×250 ads.
// Designed to integrate naturally with V Shots' premium music/video experience.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import '../theme/app_colors.dart';
import 'ad_policy.dart';
import 'levelplay_service.dart';
import 'mrec_ad_manager.dart';
import 'levelplay_config.dart';

/// Premium MREC Ad Card widget
class PremiumMRECAdCard extends StatefulWidget {
  const PremiumMRECAdCard({
    super.key,
    required this.placement,
    this.onLoad,
    this.onFailure,
  });

  final MRECPlacement placement;
  final VoidCallback? onLoad;
  final VoidCallback? onFailure;

  @override
  State<PremiumMRECAdCard> createState() => _PremiumMRECAdCardState();
}

class _PremiumMRECAdCardState extends State<PremiumMRECAdCard>
    with LevelPlayBannerAdViewListener {
  final GlobalKey<LevelPlayBannerAdViewState> _bannerKey =
      GlobalKey<LevelPlayBannerAdViewState>();
  bool _isVisible = false;
  bool _hasFailed = false;

  String? get _unitId =>
      LevelPlayConfig.unitIdFor(LevelPlayPlacement.bannerHome);

  @override
  void initState() {
    super.initState();
    if (AdPolicy.instance.adsAvailable) {
      MRECAdManager.instance.loadMREC(widget.placement);
    }
  }

  @override
  void dispose() {
    _bannerKey.currentState?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unitId = _unitId;
    if (unitId == null) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _hasFailed ? 0 : 250,
      child: _hasFailed
          ? const SizedBox.shrink()
          : Container(
              width: 300,
              height: 250,
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Ad content
                    Positioned.fill(
                      child: LevelPlayBannerAdView(
                        key: _bannerKey,
                        adUnitId: unitId,
                        adSize: LevelPlayAdSize.MEDIUM_RECTANGLE,
                        listener: this,
                        placementName: widget.placement.name,
                        onPlatformViewCreated: () {
                          _bannerKey.currentState?.loadAd();
                        },
                      ),
                    ),

                    // Loading indicator
                    if (!_isVisible && !_hasFailed)
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Loading...',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Ad label
                    if (_isVisible)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Ad',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    setState(() {
      _isVisible = true;
      _hasFailed = false;
    });
    MRECAdManager.instance.onAdLoaded();
    widget.onLoad?.call();
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    debugPrint('[MREC Card] Load failed: $error');
    setState(() {
      _hasFailed = true;
    });
    MRECAdManager.instance.onAdLoadFailed(error.toString());
    widget.onFailure?.call();
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    MRECAdManager.instance.markDisplayed();
  }

  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {
    debugPrint('[MREC Card] Display failed: $error');
    setState(() {
      _hasFailed = true;
    });
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {
    MRECAdManager.instance.markClicked();
  }

  @override
  void onAdExpanded(LevelPlayAdInfo adInfo) {}

  @override
  void onAdCollapsed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdLeftApplication(LevelPlayAdInfo adInfo) {}
}
