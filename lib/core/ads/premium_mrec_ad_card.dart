// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Premium MREC Ad Card (Unity LevelPlay 300×250)
// ═════════════════════════════════════════════════════════════════════════════
//
// Premium ad container for MREC 300×250 ads.
// Graceful failure handling - collapses if ad fails to load.
// Never blocks UI or leaves blank spaces.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import '../theme/app_colors.dart';
import 'mrec_ad_manager.dart';
import 'levelplay_config.dart';

/// Premium MREC Ad Card widget with graceful failure handling
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
  Timer? _loadTimer;

  String? get _unitId {
    // Use banner home unit for all MREC placements
    // LevelPlay resolves the correct format based on ad size
    return LevelPlayConfig.unitIdFor(LevelPlayPlacement.bannerHome);
  }

  @override
  void initState() {
    super.initState();
    MRECAdManager.instance.loadMREC(widget.placement);

    // Timeout after 10 seconds - collapse if ad doesn't load
    _loadTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && !_isVisible && !_hasFailed) {
        setState(() {
          _hasFailed = true;
        });
        MRECAdManager.instance.markFailed('timeout');
        widget.onFailure?.call();
      }
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _bannerKey.currentState?.destroy();
    MRECAdManager.instance.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unitId = _unitId;
    if (unitId == null || _hasFailed) {
      // Collapse completely - no blank space
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _isVisible ? MRECConfig.mrecHeight.toDouble() : 0,
      child: _isVisible
          ? Container(
              width: MRECConfig.mrecWidth.toDouble(),
              height: MRECConfig.mrecHeight.toDouble(),
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
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
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
            )
          : null,
    );
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    if (mounted) {
      _loadTimer?.cancel();
      setState(() {
        _isVisible = true;
        _hasFailed = false;
      });
      MRECAdManager.instance.markLoaded();
      widget.onLoad?.call();
    }
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    debugPrint('[MREC Card] Load failed: $error');
    if (mounted) {
      _loadTimer?.cancel();
      setState(() {
        _hasFailed = true;
        _isVisible = false;
      });
      MRECAdManager.instance.markFailed(error.toString());
      widget.onFailure?.call();
    }
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    MRECAdManager.instance.markDisplayed();
  }

  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {
    debugPrint('[MREC Card] Display failed: $error');
    if (mounted) {
      setState(() {
        _hasFailed = true;
        _isVisible = false;
      });
    }
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
