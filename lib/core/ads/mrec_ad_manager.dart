// V Shots — Centralized Unity LevelPlay MREC 300×250 manager

import 'package:flutter/foundation.dart';

import '../ads/ad_analytics.dart';

/// MREC placement locations.
enum MRECPlacement {
  home,
  discoverFeed,
  discoverDwell,
  search,
  playlist,
  library,
}

/// All MREC UX/frequency values live here so monetization can be tuned later
/// without scattering constants through individual screens.
class MRECConfig {
  MRECConfig._();

  static const bool enabled = true;
  static const int mrecWidth = 300;
  static const int mrecHeight = 250;

  static const int homeFirstMRECAfter = 6;
  static const int homeMRECInterval = 8;
  static const int discoverFirstMRECAfter = 4;
  static const int discoverMRECInterval = 6;
  static const int searchFirstMRECAfter = 4;
  static const int searchMRECInterval = 6;

  /// Minimum time between impressions across the whole app.
  static const int mrecCooldownSeconds = 120;

  /// Maximum time to keep a visible loading slot before collapsing it.
  static const Duration loadTimeout = Duration(seconds: 10);

  /// Discover dwell opportunity. Playback is never paused by this timer.
  static const Duration discoverDwellTime = Duration(seconds: 30);

  static const int maxVisibleMRECs = 1;
}

/// One global policy/telemetry coordinator for all MREC cards.
///
/// The actual LevelPlay platform view belongs to the screen widget; this
/// manager owns the cross-screen slot, cooldown and analytics state.
class MRECAdManager extends ChangeNotifier {
  MRECAdManager._();
  static final MRECAdManager instance = MRECAdManager._();

  bool _isLoaded = false;
  bool _isLoading = false;
  DateTime? _lastShownAt;
  MRECPlacement? _currentPlacement;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  MRECPlacement? get currentPlacement => _currentPlacement;

  bool get isCoolingDown {
    final shown = _lastShownAt;
    if (shown == null) return false;
    return DateTime.now().difference(shown).inSeconds <
        MRECConfig.mrecCooldownSeconds;
  }

  bool get canRequest => MRECConfig.enabled && !_isLoading && !_isLoaded && !isCoolingDown;

  /// Claims the single MREC slot for a screen and records a load attempt.
  Future<bool> loadMREC(MRECPlacement placement) async {
    if (!canRequest) {
      debugPrint('[MREC] request denied: enabled/cooldown/active policy');
      return false;
    }

    _isLoading = true;
    _currentPlacement = placement;
    notifyListeners();
    AdAnalytics.log('mrec_load_attempt', placement: placement.name);
    return true;
  }

  void markLoaded() {
    _isLoaded = true;
    _isLoading = false;
    AdAnalytics.log('mrec_loaded', placement: _currentPlacement?.name);
    notifyListeners();
  }

  void markDisplayed() {
    _lastShownAt = DateTime.now();
    _isLoaded = false;
    _isLoading = false;
    AdAnalytics.log('mrec_impression', placement: _currentPlacement?.name);
    notifyListeners();
  }

  void markClicked() {
    AdAnalytics.log('mrec_click', placement: _currentPlacement?.name);
  }

  void markFailed(String error) {
    final placement = _currentPlacement?.name;
    _isLoaded = false;
    _isLoading = false;
    AdAnalytics.log('mrec_load_failed', placement: placement, detail: error);
    notifyListeners();
  }

  void release(MRECPlacement placement) {
    if (_currentPlacement != placement) return;
    _isLoaded = false;
    _isLoading = false;
    _currentPlacement = null;
    notifyListeners();
  }

  void reset() {
    _isLoaded = false;
    _isLoading = false;
    _currentPlacement = null;
    notifyListeners();
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
