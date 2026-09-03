// V Shots — Premium Unity LevelPlay MREC 300×250
// Reusable, non-interruptive ad card for feed surfaces.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../theme/app_colors.dart';
import 'ad_analytics.dart';
import 'levelplay_config.dart';
import 'mrec_ad_manager.dart';

/// Premium 300×250 MREC container.
///
/// The LevelPlay platform view is mounted during loading. This is important:
/// waiting for onAdLoaded before mounting the platform view creates a deadlock
/// where the SDK can never deliver the loaded callback. On a real failure or
/// timeout the entire card collapses, so no permanent blank ad space remains.
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

  Timer? _loadTimer;
  bool _isLoaded = false;
  bool _hasFailed = false;
  bool _loadStarted = false;
  bool _impressionSent = false;

  String? get _unitId =>
      LevelPlayConfig.unitIdFor(LevelPlayPlacement.bannerHome);

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  Future<void> _startLoad() async {
    final unitId = _unitId;
    if (unitId == null) {
      _collapse('mrec unit not configured');
      return;
    }

    final started = await MRECAdManager.instance.loadMREC(widget.placement);
    if (!mounted) return;
    if (!started) {
      _collapse('mrec slot unavailable');
      return;
    }

    setState(() => _loadStarted = true);
    _loadTimer = Timer(MRECConfig.loadTimeout, () {
      if (mounted && !_isLoaded && !_hasFailed) {
        _collapse('timeout');
      }
    });
  }

  void _collapse(String reason) {
    if (!mounted || _hasFailed) return;
    _loadTimer?.cancel();
    setState(() {
      _hasFailed = true;
      _isLoaded = false;
    });
    debugPrint('[MREC] collapsed: $reason');
    MRECAdManager.instance.markFailed(reason);
    widget.onFailure?.call();
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    if (_isLoaded) {
      AdAnalytics.log('mrec_hidden', placement: widget.placement.name);
    }
    _bannerKey.currentState?.destroy();
    MRECAdManager.instance.release(widget.placement);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unitId = _unitId;
    if (unitId == null || _hasFailed) return const SizedBox.shrink();

    return RepaintBoundary(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Container(
              width: MRECConfig.mrecWidth.toDouble(),
              height: MRECConfig.mrecHeight.toDouble(),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Keep the platform view mounted from the start so
                  // LevelPlay can create and load the MREC normally.
                  Opacity(
                    opacity: _isLoaded ? 1 : 0.01,
                    child: LevelPlayBannerAdView(
                      key: _bannerKey,
                      adUnitId: unitId,
                      adSize: LevelPlayAdSize.MEDIUM_RECTANGLE,
                      listener: this,
                      placementName: widget.placement.name,
                      onPlatformViewCreated: () {
                        if (_loadStarted) {
                          _bannerKey.currentState?.loadAd();
                        }
                      },
                    ),
                  ),
                  if (!_isLoaded)
                    Container(
                      color: AppColors.surface.withValues(alpha: 0.96),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          'Ad',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    if (!mounted) return;
    _loadTimer?.cancel();
    setState(() => _isLoaded = true);
    MRECAdManager.instance.markLoaded();
    widget.onLoad?.call();
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    debugPrint('[MREC] load failed: $error');
    _collapse(error.toString());
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    if (_impressionSent) return;
    _impressionSent = true;
    MRECAdManager.instance.markDisplayed();
  }

  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {
    debugPrint('[MREC] display failed: $error');
    _collapse(error.toString());
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {
    MRECAdManager.instance.markClicked();
  }

  @override
  void onAdExpanded(LevelPlayAdInfo adInfo) {}

  @override
  void onAdCollapsed(LevelPlayAdInfo adInfo) {
    AdAnalytics.log('mrec_hidden', placement: widget.placement.name);
  }

  @override
  void onAdLeftApplication(LevelPlayAdInfo adInfo) {}
}
