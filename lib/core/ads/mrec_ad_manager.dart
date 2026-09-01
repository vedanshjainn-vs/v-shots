// ═════════════════════════════════════════════════════════════════════════
// V Shots — MREC Ad Manager (Unity LevelPlay 300×250)
//
// Centralized manager for MREC (Medium Rectangle) 300×250 ads.
// Handles loading, display, lifecycle, and frequency control.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../ads/ad_analytics.dart';

/// MREC placement sources for analytics
enum MRECPlacement {
  home,
  discoverFeed,
  discoverDwell,
  search,
}

/// Centralized MREC configuration
class MRECConfig {
  MRECConfig._();

  static bool get mrecEnabled => true;

  // Frequency intervals (number of content items between ads)
  static const int homeMRECInterval = 6;
  static const int discoverMRECInterval = 4;
  static const int searchMRECInterval = 4;

  // Cooldown between MREC displays (seconds)
  static const int mrecCooldownSeconds = 120;

  // Dwell time before showing MREC on Discover (seconds)
  static const int discoverDwellTime = 15;

  // Maximum MRECs visible at once
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
    AdAnalytics.log('mrec_impression', placement: _currentPlacement?.name ?? '');
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
    AdAnalytics.log('mrec_load_failed', placement: _currentPlacement?.name ?? '');
    notifyListeners();
  }

  @override
  void dispose() {
    hideMREC();
    super.dispose();
  }
}
