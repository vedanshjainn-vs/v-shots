// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad-Free / Premium Manager
//
// Single source of truth for "does this user get ads?".
//
// NOTE: V Shots has NO existing premium/subscription system (verified by
// audit of lib/ — 'premium' appears only as UI adjectives). This manager does
// NOT create a competing premium system; it is the ad-side gate that any
// future premium implementation can drive by setting [premiumKey]:
//   - permanent ad-free:  prefs['vshots_premium_ad_free'] = true   (future IAP)
//   - temporary pass:     prefs['vshots_ad_free_until_ms'] = <ms>   (rewarded)
//
// While ad-free, AdPolicy.adsAvailable is false for EVERY placement — the
// user simply sees the normal app with no ads (fail-safe = normal UI).
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdFreeManager {
  AdFreeManager._();

  static final AdFreeManager instance = AdFreeManager._();

  static const String _adFreeUntilKey = 'vshots_ad_free_until_ms';
  static const String _premiumKey = 'vshots_premium_ad_free';

  bool _ready = false;
  bool _permanent = false;
  DateTime? _adFreeUntil;

  bool get isReady => _ready;

  /// Loads the stored ad-free state. Safe to call multiple times.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _permanent = prefs.getBool(_premiumKey) ?? false;
      final until = prefs.getInt(_adFreeUntilKey);
      _adFreeUntil = until != null
          ? DateTime.fromMillisecondsSinceEpoch(until)
          : null;
    } catch (e) {
      // Fail-safe: unreadable prefs ⇒ NOT ad-free (normal behavior).
      debugPrint('[AdFree] init error: $e');
      _permanent = false;
      _adFreeUntil = null;
    }
    _ready = true;
  }

  /// True when the user must not receive any ads right now.
  bool get isAdFree {
    if (_permanent) return true;
    final until = _adFreeUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// Remaining ad-free time (UI copy), or null.
  Duration? get remaining {
    final until = _adFreeUntil;
    if (until == null) return null;
    final r = until.difference(DateTime.now());
    return r.isNegative ? null : r;
  }

  /// Grants a temporary ad-free pass (rewarded-ads flow).
  Future<void> grantTemporaryPass({
    Duration duration = const Duration(minutes: 60),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(duration);
    _adFreeUntil = until;
    await prefs.setInt(_adFreeUntilKey, until.millisecondsSinceEpoch);
    debugPrint('[AdFree] temporary pass until $until');
  }

  /// Future premium hook: permanent ad-free (e.g. after IAP verification).
  /// Not wired to any billing system today — left as the single entry point.
  Future<void> setPremiumAdFree(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _permanent = value;
    await prefs.setBool(_premiumKey, value);
  }

  /// Test helper.
  @visibleForTesting
  void debugSet({bool? permanent, DateTime? adFreeUntil}) {
    if (permanent != null) _permanent = permanent;
    _adFreeUntil = adFreeUntil;
    _ready = true;
  }
}
