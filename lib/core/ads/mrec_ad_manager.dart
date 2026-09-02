// ═════════════════════════════════════════════════════════════════════════════
// V Shots — LevelPlay MREC Ad Manager
// ═════════════════════════════════════════════════════════════════════════════
//
// Centralized manager for Unity LevelPlay MREC 300×250 ads.
// Handles loading, display, lifecycle, frequency capping, and analytics.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../ads/ad_analytics.dart';

/// MREC placement locations
enum MRECPlacement {
  home,
  discoverFeed,
  search,
  playlist,
  library,
}

/// Centralized MREC configuration
class MRECConfig {
  MRECConfig._();

  static const int mrecWidth = 300;
  static const int mrecHeight = 250;

  /// Minimum content items before first MREC
  static const int homeFirstMRECAfter = 6;
  static const int discoverFirstMRECAfter = 4;
  static const int searchFirstMRECAfter = 4;

  /// Minimum content items between MRECs
  static const int homeMRECInterval = 8;
  static const int discoverMRECInterval = 6;
  static const int searchMRECInterval = 6;

  /// Cooldown between MREC displays (seconds)
  static const int mrecCooldownSeconds = 120;

  /// Maximum MRECs visible at once
  static const int maxVisibleMRECs = 1;
}

/// MREC Ad Manager - handles loading, lifecycle, and frequency capping
class MRECAdManager extends ChangeNotifier {
  MRECAdManager._();
  static final MRECAdManager instance = MRECAdManager._();

  bool _isLoaded = false;
  bool _isLoading = false;
  DateTime? _lastShownAt;
  MRECPlacement? _currentPlacement;
  String? _error;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String? get error => _error;
  MRECPlacement? get currentPlacement => _currentPlacement;

  /// Load MREC ad for a specific placement
  Future<void> loadMREC(MRECPlacement placement) async {
    if (_isLoading || _isLoaded) return;

    // Check cooldown
    if (_lastShownAt != null) {
      final cooldown = DateTime.now().difference(_lastShownAt!);
      if (cooldown.inSeconds < MRECConfig.mrecCooldownSeconds) {
        debugPrint('[MREC] Cooldown active: ${cooldown.inSeconds}s remaining');
        return;
      }
    }

    _isLoading = true;
    _currentPlacement = placement;
    _error = null;

    try {
      AdAnalytics.log('mrec_load_attempt', placement: placement.name);
      // MREC loading is handled by the widget via LevelPlay SDK
      // This method manages state and cooldown
    } catch (e) {
      debugPrint('[MREC] Load failed: $e');
      _error = e.toString();
      AdAnalytics.log('mrec_load_failed', placement: placement.name);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark MREC as loaded successfully
  void markLoaded() {
    _isLoaded = true;
    _isLoading = false;
    _error = null;
    AdAnalytics.log('mrec_loaded', placement: _currentPlacement?.name ?? '');
    notifyListeners();
  }

  /// Mark MREC as displayed/impression
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

  /// Mark MREC as failed to load
  void markFailed(String error) {
    _isLoaded = false;
    _isLoading = false;
    _error = error;
    AdAnalytics.log('mrec_load_failed', placement: _currentPlacement?.name ?? '');
    notifyListeners();
  }

  /// Reset state for cleanup
  void reset() {
    _isLoaded = false;
    _isLoading = false;
    _error = null;
    _currentPlacement = null;
    notifyListeners();
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
