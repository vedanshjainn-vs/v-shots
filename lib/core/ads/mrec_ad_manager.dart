// ═════════════════════════════════════════════════════════════════════════
// V Shots — MREC Ad Manager (Unity LevelPlay 300x250)
//
// Centralized manager for MREC (Medium Rectangle) 300x250 ads.
// Handles loading, display, lifecycle, and frequency control per placement.
// ════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../ads/ad_analytics.dart';

/// MREC placement sources for analytics
enum MRECPlacement {
  home,
  discoverFeed,
  discoverDwell,
  search,
  playlist,
  library,
}

/// Centralized MREC configuration
class MRECConfig {
  MRECConfig._();

  static bool get mrecEnabled => true;

  // Higher, but still non-intrusive, in-feed cadence.
  static const int homeMRECInterval = 4;
  static const int discoverMRECInterval = 3;
  static const int searchMRECInterval = 3;

  // Keep enough breathing room between impressions when users move
  // quickly between Home / Discover / Search.
  static const int mrecCooldownSeconds = 60;

  // Discover dwell placement can appear after a short engaged session.
  static const int discoverDwellTime = 10;

  // Never stack two MRECs on screen at once.
  static const int maxVisibleMRECs = 1;
}

/// MREC Ad Manager - handles loading and lifecycle per placement
class MRECAdManager extends ChangeNotifier {
  MRECAdManager._();
  static final MRECAdManager instance = MRECAdManager._();

  final Map<MRECPlacement, DateTime> _lastShownByPlacement = {};
  final Set<MRECPlacement> _loadedPlacements = {};
  bool _legacyLoaded = false;
  MRECPlacement? _currentPlacement;

  bool get isLoaded => _loadedPlacements.isNotEmpty || _legacyLoaded;

  bool isPlacementLoaded(MRECPlacement placement) =>
      _loadedPlacements.contains(placement);

  /// Load MREC ad for a specific placement
  Future<void> loadMREC(MRECPlacement placement) async {
    if (!MRECConfig.mrecEnabled) return;
    _currentPlacement = placement;

    // Check per-placement cooldown so Home does not block Search/Playlist
    final lastShown = _lastShownByPlacement[placement];
    if (lastShown != null) {
      final cooldown = DateTime.now().difference(lastShown);
      if (cooldown.inSeconds < MRECConfig.mrecCooldownSeconds) {
        debugPrint(
          '[MREC] Cooldown active for ${placement.name}: '
          '${cooldown.inSeconds}s',
        );
        return;
      }
    }

    AdAnalytics.log('mrec_load_attempt', placement: placement.name);
  }

  /// Mark MREC as displayed
  void markDisplayed([MRECPlacement? placement]) {
    final p = placement ?? _currentPlacement;
    if (p != null) {
      _lastShownByPlacement[p] = DateTime.now();
      _loadedPlacements.remove(p);
      AdAnalytics.log('mrec_impression', placement: p.name);
    }
    _legacyLoaded = false;
    notifyListeners();
  }

  /// Mark MREC as clicked
  void markClicked([MRECPlacement? placement]) {
    final p = placement ?? _currentPlacement;
    AdAnalytics.log('mrec_click', placement: p?.name ?? '');
  }

  /// Hide/collapse MREC
  void hideMREC([MRECPlacement? placement]) {
    if (placement != null) {
      _loadedPlacements.remove(placement);
      AdAnalytics.log('mrec_hidden', placement: placement.name);
    } else {
      _loadedPlacements.clear();
      _legacyLoaded = false;
      AdAnalytics.log(
        'mrec_hidden',
        placement: _currentPlacement?.name ?? '',
      );
    }
    notifyListeners();
  }

  /// Check if MREC is ready to show
  bool isMRECReady([MRECPlacement? placement]) {
    if (placement != null) return _loadedPlacements.contains(placement);
    return isLoaded;
  }

  void onAdLoaded([MRECPlacement? placement]) {
    final p = placement ?? _currentPlacement;
    if (p != null) {
      _loadedPlacements.add(p);
      debugPrint('[MREC] Ad loaded for ${p.name}');
      AdAnalytics.log('mrec_loaded', placement: p.name);
    } else {
      debugPrint('[MREC] Ad loaded');
      AdAnalytics.log('mrec_loaded', placement: '');
    }
    _legacyLoaded = true;
    notifyListeners();
  }

  void onAdLoadFailed(String error, [MRECPlacement? placement]) {
    final p = placement ?? _currentPlacement;
    if (p != null) {
      _loadedPlacements.remove(p);
      debugPrint('[MREC] Load failed for ${p.name}: $error');
      AdAnalytics.log('mrec_load_failed', placement: p.name, detail: error);
    } else {
      debugPrint('[MREC] Load failed: $error');
      AdAnalytics.log('mrec_load_failed', placement: '', detail: error);
    }
    _legacyLoaded = false;
    notifyListeners();
  }

  @override
  void dispose() {
    hideMREC();
    super.dispose();
  }
}
