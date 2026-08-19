// ═════════════════════════════════════════════════════════════════════════════
// V Shots — VShotsContentBlocker (Forceful, Always-On Ad Blocking)
// ═════════════════════════════════════════════════════════════════════════════
//
// A DOMAIN-AGNOSTIC content blocker for the V Shots in-app browser.
// Now uses the centralized VShotsAdBlockEngine for all rules.
//
// DESIGN PRINCIPLES:
//   • ALWAYS ON — cannot be disabled by websites
//   • Network-level blocking (primary defense)
//   • URL pattern matching (catches ad paths/queries)
//   • Cosmetic DOM blocking (hides residual containers)
//   • Popup/redirect blocking
//   • YouTube compatibility preserved
//
// This is the Dart-side interface that bridges to the native WebView.
// The actual blocking happens in VShotsBrowserPlatformView.kt.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vshots_ad_block_engine.dart';

import 'vshots_ad_block_engine.dart';

/// What KIND of resource a rule targets.
enum AdBlockRuleType { network, script, image, iframe, stylesheet, tracking }

enum AdBlockAction { block, allow }

/// A single blocking rule. [pattern] is a bare host (domain-agnostic).
class AdBlockRule {
  const AdBlockRule({
    required this.pattern,
    this.type = AdBlockRuleType.network,
    this.action = AdBlockAction.block,
    this.enabled = true,
  });

  final String pattern;
  final AdBlockRuleType type;
  final AdBlockAction action;
  final bool enabled;
}

/// Content blocker that bridges to the centralized VShotsAdBlockEngine.
/// Every V Shots browser WebView MUST use this class.
class VShotsContentBlocker {
  VShotsContentBlocker({List<String> essentialHosts = const []})
      : _additionalEssentialHosts = essentialHosts;

  static const _kEnabled = 'v_shots.content_blocker.enabled.v1';
  static const _kUserAllow = 'v_shots.content_blocker.user_allow.v1';

  final List<String> _additionalEssentialHosts;
  SharedPreferences? _prefs;

  /// User-added allowlist (persisted).
  final Set<String> _userAllow = {};

  /// Statistics (mirrored from engine)
  int blockedAds = 0;
  int blockedTrackers = 0;

  /// Reference to the centralized engine
  VShotsAdBlockEngine get _engine => VShotsAdBlockEngine.instance;

  /// Enable/disable the blocker (persisted).
  Future<void> setEnabled(bool value) async {
    await _engine.setEnabled(value);
  }

  bool get enabled => _engine.enabled;

  /// Loads persisted state (enabled flag + user allowlist).
  Future<void> initialize() async {
    await _engine.initialize();
    try {
      _prefs = await SharedPreferences.getInstance();
      final allow = _prefs?.getString(_kUserAllow);
      if (allow != null && allow.isNotEmpty) {
        _userAllow.addAll(_normalizeHosts(allow.split(',')));
        for (final host in _userAllow) {
          await _engine.allowHost(host);
        }
      }
    } catch (e) {
      debugPrint('[ContentBlocker] init failed: $e');
    }
  }

  /// Adds a user allowlist host (persisted).
  Future<void> allowHost(String host) async {
    final h = _normalizeHost(host);
    if (h.isEmpty) return;
    _userAllow.add(h);
    await _prefs?.setString(_kUserAllow, _userAllow.join(','));
    await _engine.allowHost(host);
  }

  bool get isEnabled => _engine.enabled;

  /// Is [url] on the explicit allowlist (essential + user)?
  bool isAllowed(String url) {
    return _engine.isAllowed(url);
  }

  /// Should [url] be BLOCKED? Delegates to the centralized engine.
  bool shouldBlock(String url) {
    return _engine.shouldBlock(url);
  }

  /// Records a blocked resource for diagnostics (called from the native
  /// bridge). Classifies as ad vs tracker by rule type.
  void recordBlocked(String host) {
    _engine.recordBlocked(host);
    blockedAds = _engine.blockedAds;
    blockedTrackers = _engine.blockedTrackers;
  }

  /// Compiled blocklist + essential hosts + URL patterns sent to the native
  /// WebView (one cheap host-set lookup per request there — no regex).
  List<String> get blockedHosts => _engine.blockedHosts;

  List<String> get essentialHosts {
    final combined = <String>[
      ..._engine.essentialHostsList,
      ..._additionalEssentialHosts,
    ];
    return combined;
  }

  /// URL patterns for native WebView blocking.
  List<String> get adUrlPatterns => _engine.adUrlPatterns;

  // ── helpers (pure) ──────────────────────────────────────────────────────
  static String _normalizeHost(String host) {
    var h = host.trim().toLowerCase();
    if (h.startsWith('www.')) h = h.substring(4);
    return h;
  }

  static Set<String> _normalizeHosts(Iterable<String> hosts) =>
      hosts.map(_normalizeHost).where((h) => h.isNotEmpty).toSet();
}
