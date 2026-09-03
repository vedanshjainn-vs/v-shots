// ═════════════════════════════════════════════════════════════════════════
// V Shots — Premium MREC Ad Card (Unity LevelPlay 300×250)
//
// Premium ad container for MREC 300×250 ads.
//
// Lifecycle:
//   • LevelPlayBannerAdView stays mounted while loading — unmounting kills
//     the in-flight request and creates a circular dependency.
//   • On failure the card collapses (zero height) without a rebuild loop.
//   • View rendered at full size behind a loading overlay until onAdLoaded.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../theme/app_colors.dart';
import 'ad_policy.dart';
import 'levelplay_config.dart';
import 'levelplay_service.dart';
import 'mrec_ad_manager.dart';

/// Premium MREC Ad Card — Unity LevelPlay 300×250.
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
  bool _loadAttempted = false;

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

  void _requestLoad() {
    if (_loadAttempted) return;
    _loadAttempted = true;
    final state = _bannerKey.currentState;
    if (state != null) {
      try {
        state.loadAd();
        if (kDebugMode) {
          debugPrint('[MREC] loadAd() for ${widget.placement.name}');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[MREC] loadAd error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitId = _unitId;
    if (unitId == null ||
        !AdPolicy.instance.adsAvailable ||
        !VShotsLevelPlay.instance.initSucceeded) {
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
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !_isVisible,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                          opacity: _isVisible ? 1 : 0,
                          child: LevelPlayBannerAdView(
                            key: _bannerKey,
                            adUnitId: unitId,
                            adSize: LevelPlayAdSize.MEDIUM_RECTANGLE,
                            listener: this,
                            placementName:
                                'MREC_${widget.placement.name.toUpperCase()}',
                            onPlatformViewCreated: (_) => _requestLoad(),
                          ),
                        ),
                      ),
                    ),
                    if (!_isVisible && !_hasFailed)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Sponsored',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_isVisible)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppColors.hotPink.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Ad · Sponsored',
                            style: TextStyle(
                              color: AppColors.hotPink,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
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
    if (kDebugMode) {
      debugPrint(
        '[MREC] Loaded: network=${adInfo.adNetwork} '
        'placement=${widget.placement.name}',
      );
    }
    if (mounted) {
      setState(() {
        _isVisible = true;
        _hasFailed = false;
      });
    }
    MRECAdManager.instance.onAdLoaded();
    widget.onLoad?.call();
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    if (kDebugMode) {
      debugPrint(
        '[MREC] Load failed: $error placement=${widget.placement.name}',
      );
    }
    if (mounted) {
      setState(() => _hasFailed = true);
    }
    MRECAdManager.instance.onAdLoadFailed(error.toString());
    widget.onFailure?.call();
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    MRECAdManager.instance.markDisplayed();
  }

  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {
    if (kDebugMode) debugPrint('[MREC] Display failed: $error');
    if (mounted) setState(() => _hasFailed = true);
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
