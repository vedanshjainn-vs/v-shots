// ═════════════════════════════════════════════════════════════════════════
// V Shots — MREC Ad Manager (Unity LevelPlay 300x250)
//
// Centralized manager for MREC (Medium Rectangle) 300x250 ads.
// Handles loading, display, lifecycle, and frequency control.
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

/// MREC Ad Manager - handles loading and lifecycle
class MRECAdManager extends ChangeNotifier {
  MRECAdManager._();
  static final MRECAdManager instance = MRECAdManager._();

  bool _isLoaded = false;
  DateTime? _lastShownAt;
  MRECPlacement? _currentPlacement;

  bool get isLoaded => _isLoaded;

  /// Load MREC ad for a specific placement
  Future<void> loadMREC(MRECPlacement placement) async {
    if (!MRECConfig.mrecEnabled) return;
    if (_isLoaded) return;

    // Check cooldown
    if (_lastShownAt != null) {
      final cooldown = DateTime.now().difference(_lastShownAt!);
      if (cooldown.inSeconds < MRECConfig.mrecCooldownSeconds) {
        debugPrint('[MREC] Cooldown active: ${cooldown.inSeconds}s');
        return;
      }
    }

    _currentPlacement = placement;
    AdAnalytics.log('mrec_load_attempt', placement: placement.name);
  }

  /// Mark MREC as displayed
  void markDisplayed() {
    _lastShownAt = DateTime.now();
    _isLoaded = false;
    AdAnalytics.log('mrec_impression',
        placement: _currentPlacement?.name ?? '');
    notifyListeners();
  }

  /// Mark MREC as clicked
  void markClicked() {
    AdAnalytics.log('mrec_click', placement: _currentPlacement?.name ?? '');
  }

  /// Hide/collapse MREC
  void hideMREC() {
    _isLoaded = false;
    AdAnalytics.log('mrec_hidden', placement: _currentPlacement?.name ?? '');
    notifyListeners();
  }

  /// Check if MREC is ready to show
  bool isMRECReady() => _isLoaded;

  void onAdLoaded() {
    debugPrint('[MREC] Ad loaded');
    _isLoaded = true;
    AdAnalytics.log('mrec_loaded', placement: _currentPlacement?.name ?? '');
    notifyListeners();
  }

  void onAdLoadFailed(String error) {
    debugPrint('[MREC] Load failed: $error');
    _isLoaded = false;
    AdAnalytics.log('mrec_load_failed',
        placement: _currentPlacement?.name ?? '');
    notifyListeners();
  }

  @override
  void dispose() {
    hideMREC();
    super.dispose();
  }
}
