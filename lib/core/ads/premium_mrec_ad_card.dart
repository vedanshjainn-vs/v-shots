// ═════════════════════════════════════════════════════════════════════════
// V Shots — Premium MREC Ad Card (Unity LevelPlay 300x250)
//
// A real LevelPlay MEDIUM_RECTANGLE (300x250) in-flow ad. The widget waits
// for the asynchronous LevelPlay initialization, loads only after the SDK is
// ready, and keeps retrying failed loads while the slot remains mounted.
// No fake ad state is ever rendered.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../theme/app_colors.dart';
import 'ad_analytics.dart';
import 'ad_policy.dart';
import 'levelplay_config.dart';
import 'levelplay_service.dart';
import 'mrec_ad_manager.dart';

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

  Timer? _retryTimer;
  Timer? _loadingWatchdog;
  bool _isLoaded = false;
  bool _loadInFlight = false;
  int _retryAttempt = 0;

  String? get _unitId =>
      LevelPlayConfig.unitIdFor(LevelPlayPlacement.bannerHome);

  @override
  void initState() {
    super.initState();
    MRECAdManager.instance.loadMREC(widget.placement);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _loadingWatchdog?.cancel();
    _bannerKey.currentState?.destroy();
    MRECAdManager.instance.hideMREC();
    super.dispose();
  }

  void _loadFromPlatformView() {
    if (!mounted || _loadInFlight || _isLoaded) return;
    if (!AdPolicy.instance.canShowMREC(widget.placement)) return;
    if (!VShotsLevelPlay.instance.initSucceeded) return;

    _loadInFlight = true;
    _loadingWatchdog?.cancel();
    MRECAdManager.instance.loadMREC(widget.placement);
    try {
      _bannerKey.currentState?.loadAd();
      // Some mediation adapters can leave a platform view waiting without
      // emitting a callback. Never leave the user staring at a spinner.
      _loadingWatchdog = Timer(const Duration(seconds: 12), () {
        if (!mounted || !_loadInFlight || _isLoaded) return;
        _loadInFlight = false;
        _scheduleRetry('load watchdog timeout');
        if (mounted) setState(() {});
      });
    } catch (e) {
      _loadInFlight = false;
      _scheduleRetry('loadAd exception: $e');
    }
  }

  void _scheduleRetry(String reason) {
    _retryTimer?.cancel();
    if (!mounted) return;
    _retryAttempt = (_retryAttempt + 1).clamp(1, 8);
    // Keep trying while the slot is alive. This maximises fill after a
    // transient mediation/no-fill response without creating a request loop.
    final seconds = [15, 30, 45, 60, 90, 120, 180, 180][_retryAttempt - 1];
    debugPrint('[MREC] retry in ${seconds}s ($reason)');
    _retryTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      _loadInFlight = false;
      _loadFromPlatformView();
    });
  }

  Widget _buildCard() {
    final unitId = _unitId;
    if (unitId == null ||
        !AdPolicy.instance.canShowMREC(widget.placement) ||
        !VShotsLevelPlay.instance.initSucceeded) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 300,
      height: 250,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: LevelPlayBannerAdView(
                key: _bannerKey,
                adUnitId: unitId,
                adSize: LevelPlayAdSize.MEDIUM_RECTANGLE,
                listener: this,
                placementName: 'MREC_Android',
                onPlatformViewCreated: _loadFromPlatformView,
              ),
            ),
            if (!_isLoaded)
              const IgnorePointer(
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            if (_isLoaded)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: VShotsLevelPlay.instance.readyNotifier,
      builder: (context, _, __) => _buildCard(),
    );
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    if (!mounted) return;
    _loadingWatchdog?.cancel();
    _retryTimer?.cancel();
    _retryAttempt = 0;
    _loadInFlight = false;
    setState(() => _isLoaded = true);
    MRECAdManager.instance.onAdLoaded();
    VShotsLevelPlay.instance.noteFill('mrec', adInfo.adNetwork);
    VShotsLevelPlay.instance.noteActivity(
      'mrec',
      'LOADED (network: ${adInfo.adNetwork})',
    );
    AdAnalytics.log(
      'mrec_loaded',
      placement: widget.placement.name,
      detail: adInfo.adNetwork,
    );
    widget.onLoad?.call();
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    _loadingWatchdog?.cancel();
    _loadInFlight = false;
    if (mounted) setState(() => _isLoaded = false);
    MRECAdManager.instance.onAdLoadFailed(error.toString());
    VShotsLevelPlay.instance.noteActivity('mrec', 'LOAD FAILED — $error');
    AdAnalytics.log(
      'mrec_load_failed',
      placement: widget.placement.name,
      detail: error.toString(),
    );
    widget.onFailure?.call();
    _scheduleRetry(error.toString());
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    MRECAdManager.instance.markDisplayed();
    AdAnalytics.log(
      'mrec_displayed',
      placement: widget.placement.name,
      detail: 'network=${adInfo.adNetwork} revenue=${adInfo.revenue}',
    );
  }

  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {
    _loadingWatchdog?.cancel();
    _loadInFlight = false;
    if (mounted) setState(() => _isLoaded = false);
    MRECAdManager.instance.onAdLoadFailed(error.toString());
    AdAnalytics.log(
      'mrec_display_failed',
      placement: widget.placement.name,
      detail: error.toString(),
    );
    _scheduleRetry('display failed: $error');
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
