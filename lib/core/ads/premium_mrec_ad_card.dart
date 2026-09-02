import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../theme/app_colors.dart';
import 'ad_policy.dart';
import 'levelplay_config.dart';
import 'levelplay_service.dart';
import 'mrec_ad_manager.dart';

/// Production Unity LevelPlay MREC. MEDIUM_RECTANGLE is the real 300x250
/// LevelPlay format; this is not a Flutter placeholder or a fake ad card.
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
  final GlobalKey<LevelPlayBannerAdViewState> _key =
      GlobalKey<LevelPlayBannerAdViewState>();

  String? _viewId;
  bool _loaded = false;
  bool _failed = false;
  bool _creating = false;
  Timer? _loadTimer;

  String? get _unitId =>
      LevelPlayConfig.unitIdFor(LevelPlayPlacement.bannerHome);

  @override
  void initState() {
    super.initState();
    VShotsLevelPlay.instance.readyNotifier.addListener(_onLevelPlayReady);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryCreate());
  }

  void _onLevelPlayReady() => _tryCreate();

  void _tryCreate() {
    if (!mounted || _creating || _viewId != null || _failed) return;
    if (!AdPolicy.instance.adsAvailable ||
        !VShotsLevelPlay.instance.initSucceeded ||
        _unitId == null) {
      return;
    }
    final id = MRECAdManager.instance.acquire(widget.placement);
    if (id == null) return;
    _creating = true;
    setState(() {
      _viewId = id;
      _creating = false;
    });
    // Bounded load guard: if LevelPlay never reports loaded/displayed (no
    // fill, offline, no inventory) collapse the slot after the timeout so we
    // never leave an infinite spinner or a permanent 300x250 hole.
    _loadTimer?.cancel();
    _loadTimer = Timer(
      const Duration(seconds: MRECConfig.loadTimeoutSeconds),
      () => _collapse(error: 'load timeout (no fill)'),
    );
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _loadTimer = null;
    VShotsLevelPlay.instance.readyNotifier.removeListener(_onLevelPlayReady);
    _key.currentState?.destroy();
    final id = _viewId;
    if (id != null) {
      MRECAdManager.instance.hideMREC(
        viewId: id,
        placement: widget.placement,
      );
    }
    super.dispose();
  }

  void _collapse({String? error}) {
    if (_failed) return;
    _loadTimer?.cancel();
    _loadTimer = null;
    if (!mounted) return;
    final id = _viewId;
    if (id != null) {
      MRECAdManager.instance.onAdLoadFailed(
        viewId: id,
        placement: widget.placement,
        error: error ?? 'display failed',
      );
    }
    setState(() => _failed = true);
    widget.onFailure?.call();
  }

  @override
  Widget build(BuildContext context) {
    final id = _viewId;
    final unitId = _unitId;
    if (id == null || unitId == null || _failed) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: MRECConfig.width,
        height: MRECConfig.height,
        margin: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LevelPlayBannerAdView(
              key: _key,
              adUnitId: unitId,
              adSize: LevelPlayAdSize.MEDIUM_RECTANGLE,
              listener: this,
              placementName: _placementName(widget.placement),
              onPlatformViewCreated: () {
                _key.currentState?.loadAd();
              },
            ),
            if (!_loaded)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (_loaded)
              Positioned(
                top: 7,
                right: 7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    child: Text(
                      'Ad',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _placementName(MRECPlacement placement) => switch (placement) {
        MRECPlacement.home => 'HOME_MREC',
        MRECPlacement.discoverFeed => 'DISCOVER_FEED_MREC',
        MRECPlacement.discoverDwell => 'DISCOVER_DWELL_MREC',
        MRECPlacement.search => 'SEARCH_MREC',
        MRECPlacement.playlist => 'PLAYLIST_MREC',
        MRECPlacement.library => 'LIBRARY_MREC',
      };

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    final id = _viewId;
    if (id == null) return;
    _loadTimer?.cancel();
    _loadTimer = null;
    setState(() => _loaded = true);
    VShotsLevelPlay.instance.noteFill('mrec', adInfo.adNetwork);
    VShotsLevelPlay.instance.noteActivity(
      'mrec',
      'LOADED (network: ${adInfo.adNetwork})',
    );
    MRECAdManager.instance.onAdLoaded(
      viewId: id,
      placement: widget.placement,
    );
    widget.onLoad?.call();
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    VShotsLevelPlay.instance.noteActivity('mrec', 'LOAD FAILED — $error');
    _collapse(error: error.toString());
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    final id = _viewId;
    if (id == null) return;
    _loadTimer?.cancel();
    _loadTimer = null;
    MRECAdManager.instance.markDisplayed(
      viewId: id,
      placement: widget.placement,
      network: adInfo.adNetwork,
      revenue: adInfo.revenue,
    );
    VShotsLevelPlay.instance.noteActivity(
      'mrec',
      'DISPLAYED (network: ${adInfo.adNetwork})',
    );
  }

  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {
    VShotsLevelPlay.instance.noteActivity('mrec', 'DISPLAY FAILED — $error');
    _collapse(error: error.toString());
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {
    MRECAdManager.instance.markClicked(placement: widget.placement);
  }

  @override
  void onAdExpanded(LevelPlayAdInfo adInfo) {}

  @override
  void onAdCollapsed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdLeftApplication(LevelPlayAdInfo adInfo) {}
}
