import 'package:flutter/foundation.dart';

import 'ad_analytics.dart';

enum MRECPlacement {
  home,
  discoverFeed,
  discoverDwell,
  search,
  playlist,
  library,
}

class MRECConfig {
  MRECConfig._();

  static const bool enabled = true;
  static const int homeInterval = 4;
  static const int discoverInterval = 5;
  static const int searchAfterResults = 3;
  static const int cooldownSeconds = 60;
  static const int maxVisible = 1;
  static const int discoverDwellSeconds = 15;
  static const double width = 300;
  static const double height = 250;

  /// Maximum time (seconds) a MREC place may spend in its loading state
  /// before it is treated as a no-fill/timeout and the slot is collapsed.
  /// This guarantees an ad can NEVER show an indefinite spinner or leave a
  /// permanent 300x250 hole when LevelPlay returns no callback, is offline,
  /// or has no inventory. Requirement #7 (no infinite loading / no blank box).
  static const int loadTimeoutSeconds = 12;
}

class MRECAdManager extends ChangeNotifier {
  MRECAdManager._();
  static final MRECAdManager instance = MRECAdManager._();

  DateTime? _lastShownAt;
  MRECPlacement? _placement;
  String? _activeViewId;
  int _nextViewId = 0;
  bool _loaded = false;
  bool _inFlight = false;

  bool get isLoaded => _loaded;
  bool get isMRECReady => _loaded;

  String _placementName(MRECPlacement placement) => switch (placement) {
        MRECPlacement.home => 'HOME',
        MRECPlacement.discoverFeed => 'DISCOVER_FEED',
        MRECPlacement.discoverDwell => 'DISCOVER_DWELL',
        MRECPlacement.search => 'SEARCH',
        MRECPlacement.playlist => 'PLAYLIST',
        MRECPlacement.library => 'LIBRARY',
      };

  bool cooldownOpen() {
    final last = _lastShownAt;
    if (last == null) return true;
    return DateTime.now().difference(last).inSeconds >=
        MRECConfig.cooldownSeconds;
  }

  String? acquire(MRECPlacement placement) {
    if (!MRECConfig.enabled || !cooldownOpen()) return null;
    if (_activeViewId != null || _inFlight) return null;
    _inFlight = true;
    _placement = placement;
    final id = '${placement.name}-${_nextViewId++}';
    _activeViewId = id;
    AdAnalytics.log('mrec_screen', placement: _placementName(placement));
    AdAnalytics.log('mrec_load_attempt', placement: _placementName(placement));
    return id;
  }

  String? loadMREC(MRECPlacement placement) => acquire(placement);

  void showMREC({
    required String viewId,
    required MRECPlacement placement,
    String? network,
    double? revenue,
  }) {
    markDisplayed(
      viewId: viewId,
      placement: placement,
      network: network,
      revenue: revenue,
    );
  }

  void onAdLoaded({required String viewId, required MRECPlacement placement}) {
    if (_activeViewId != viewId) return;
    _inFlight = false;
    _loaded = true;
    _placement = placement;
    AdAnalytics.log('mrec_loaded', placement: _placementName(placement));
    notifyListeners();
  }

  void onAdLoadFailed({
    required String viewId,
    required MRECPlacement placement,
    required String error,
  }) {
    if (_activeViewId != viewId) return;
    _inFlight = false;
    _loaded = false;
    AdAnalytics.log(
      'mrec_load_failed',
      placement: _placementName(placement),
      detail: error,
    );
    _release(viewId);
  }

  void markDisplayed({
    required String viewId,
    required MRECPlacement placement,
    String? network,
    double? revenue,
  }) {
    if (_activeViewId != viewId) return;
    _lastShownAt = DateTime.now();
    _loaded = true;
    _inFlight = false;
    _placement = placement;
    AdAnalytics.log(
      'mrec_impression',
      placement: _placementName(placement),
      detail: 'network=${network ?? '-'} revenue=${revenue ?? 0}',
    );
    notifyListeners();
  }

  void markClicked({required MRECPlacement placement}) {
    AdAnalytics.log('mrec_click', placement: _placementName(placement));
  }

  void hideMREC({String? viewId, MRECPlacement? placement}) {
    if (viewId != null && _activeViewId != viewId) return;
    final p = placement ?? _placement;
    if (p != null) {
      AdAnalytics.log('mrec_hidden', placement: _placementName(p));
    }
    if (viewId != null) {
      _release(viewId);
    } else {
      _activeViewId = null;
      _loaded = false;
      _inFlight = false;
      notifyListeners();
    }
  }

  void destroyMREC({String? viewId, MRECPlacement? placement}) {
    hideMREC(viewId: viewId, placement: placement);
  }

  void _release(String viewId) {
    if (_activeViewId != viewId) return;
    _activeViewId = null;
    _loaded = false;
    _inFlight = false;
    notifyListeners();
  }

  bool owns(String viewId) => _activeViewId == viewId;

  @visibleForTesting
  void resetForTesting() {
    _lastShownAt = null;
    _placement = null;
    _activeViewId = null;
    _loaded = false;
    _inFlight = false;
  }
}
