// ═════════════════════════════════════════════════════════════════════════════
// V Shots — VShotsContentBlocker (general-purpose ad/tracker blocking)
// ═════════════════════════════════════════════════════════════════════════════
//
// A DOMAIN-AGNOSTIC content blocker for the V Shots in-app browser. It blocks
// well-known advertising/tracking HOSTS — never website-specific selectors,
// never page-specific DOM manipulation, and never first-party resources.
//
// DESIGN PRINCIPLES (conservative — when uncertain, ALLOW):
//   • Match by HOST only (suffix-exact, e.g. "doubleclick.net" also matches
//     "ad.doubleclick.net"), never by suspicious substrings like "ads"/"cdn".
//   • An explicit ALLOWLIST wins over the blocklist (first-party safety +
//     user exceptions + player-essential media hosts).
//   • Pure Dart with compiled sets — no per-request regex, no list reloads.
//   • Independent from playback: it never touches VShotsPlaybackManager, the
//     background service, tap-to-unmute, queue, or auto-advance. The player
//     layer supplies its own essentialHosts so media is never blocked.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class VShotsContentBlocker {
  VShotsContentBlocker({List<String> essentialHosts = const []})
      : _essentialHosts = _normalizeHosts(essentialHosts);

  static const _kEnabled = 'v_shots.content_blocker.enabled.v1';
  static const _kUserAllow = 'v_shots.content_blocker.user_allow.v1';

  final Set<String> _essentialHosts;
  bool _enabled = true;
  SharedPreferences? _prefs;

  /// User-added allowlist (persisted).
  final Set<String> _userAllow = {};

  int blockedAds = 0;
  int blockedTrackers = 0;

  // ── Compiled blocklist: well-known ad/tracker hosts (general purpose) ────
  static const List<String> _defaultBlocked = [
    // Ad serving / exchanges / SSPs
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adservice.google.com',
    'adnxs.com',
    'rubiconproject.com',
    'pubmatic.com',
    'openx.net',
    'casalemedia.com',
    'criteo.com',
    'smartadserver.com',
    'adform.net',
    'sovrn.com',
    'sharethrough.com',
    'teads.tv',
    'yieldmo.com',
    'amazon-adsystem.com',
    'taboola.com',
    'outbrain.com',
    'mgid.com',
    'revcontent.com',
    'exoclick.com',
    'popads.net',
    'adsterra.com',
    'propellerads.com',
    // Analytics / telemetry / tracking
    'google-analytics.com',
    'googletagmanager.com',
    'scorecardresearch.com',
    'quantserve.com',
    'chartbeat.com',
    'hotjar.com',
    'mixpanel.com',
    'segment.io',
    'segment.com',
    'amplitude.com',
    'mouseflow.com',
    'fullstory.com',
    'clarity.ms',
    'facebook.net', // tracking pixel network
    'analytics.tiktok.com',
    'branch.io',
    'appsflyer.com',
    'adjust.com',
    'kochava.com',
    'matomo.cloud',
    'newrelic.com',
    'datadoghq.com',
    'sentry.io',
    // More ad networks / exchanges
    'yieldlab.net',
    'advertising.com',
    'adsrvr.org',
    'bidswitch.net',
    'indexww.com',
    'onetag-sys.com',
    '33across.com',
    'adroll.com',
    'criteo.net',
    'lijit.com',
    'zergnet.com',
    'popcash.net',
    'ad-maven.com',
    'adcash.com',
    'popads.net',
    'media.net',
    'adlightning.com',
    'springserve.com',
    'kargo.com',
    'sonobi.com',
    'undertone.com',
    'vidoomy.com',
    'pixel.popads.net',
    'adnxs-simple.com',
    'amazon-adsystem.com',
    'aaxads.com',
    'googleadservices.com',
    'googleads.g.doubleclick.net',
  ];

  static final Set<String> _compiledBlocked = _normalizeHosts(_defaultBlocked);

  /// Enable/disable the blocker (persisted). Disabling never interrupts
  /// playback or recreates the WebView — the native layer re-checks on the
  /// NEXT request only.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _prefs?.setBool(_kEnabled, value);
  }

  bool get enabled => _enabled;

  /// Loads persisted state (enabled flag + user allowlist).
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _enabled = _prefs?.getBool(_kEnabled) ?? true;
      final allow = _prefs?.getString(_kUserAllow);
      if (allow != null && allow.isNotEmpty) {
        _userAllow.addAll(_normalizeHosts(allow.split(',')));
      }
    } catch (e) {
      debugPrint('[ContentBlocker] init failed: $e');
    }
  }

  /// Adds a user allowlist host (persisted). First-party safety net.
  Future<void> allowHost(String host) async {
    final h = _normalizeHost(host);
    if (h.isEmpty) return;
    _userAllow.add(h);
    await _prefs?.setString(_kUserAllow, _userAllow.join(','));
  }

  bool get isEnabled => _enabled;

  /// Is [url] on the explicit allowlist (essential + user)?
  bool isAllowed(String url) {
    final host = _normalizeHost(_hostOf(url));
    if (host.isEmpty) return false;
    return _matchesAny(host, _essentialHosts) || _matchesAny(host, _userAllow);
  }

  /// Should [url] be BLOCKED? Conservative: disabled → false; allowlist →
  /// false; unknown host → false. Only explicit blocklist hosts are blocked.
  bool shouldBlock(String url) {
    if (!_enabled) return false;
    final host = _normalizeHost(_hostOf(url));
    if (host.isEmpty) return false;
    if (_matchesAny(host, _essentialHosts)) return false;
    if (_matchesAny(host, _userAllow)) return false;
    return _matchesAny(host, _compiledBlocked);
  }

  /// Records a blocked resource for diagnostics (called from the native
  /// bridge). Classifies as ad vs tracker by rule type.
  void recordBlocked(String host) {
    final isTracker = _isTrackerHost(_normalizeHost(host));
    if (isTracker) {
      blockedTrackers++;
    } else {
      blockedAds++;
    }
  }

  /// Compiled blocklist + essential hosts sent to the native WebView (one
  /// cheap host-set lookup per request there — no regex).
  List<String> get blockedHosts => List.unmodifiable(_compiledBlocked);
  List<String> get essentialHosts => List.unmodifiable(_essentialHosts);

  static bool _isTrackerHost(String host) {
    const trackers = {
      'google-analytics.com',
      'googletagmanager.com',
      'scorecardresearch.com',
      'quantserve.com',
      'chartbeat.com',
      'hotjar.com',
      'mixpanel.com',
      'segment.io',
      'segment.com',
      'amplitude.com',
      'mouseflow.com',
      'fullstory.com',
      'clarity.ms',
      'facebook.net',
      'branch.io',
      'appsflyer.com',
      'adjust.com',
      'kochava.com',
      'matomo.cloud',
      'newrelic.com',
      'datadoghq.com',
      'sentry.io',
      'analytics.tiktok.com',
    };
    return _matchesAny(host, trackers);
  }

  // ── helpers (pure) ──────────────────────────────────────────────────────
  static String _hostOf(String url) {
    try {
      return Uri.tryParse(url)?.host ?? '';
    } catch (_) {
      return '';
    }
  }

  static String _normalizeHost(String host) {
    var h = host.trim().toLowerCase();
    if (h.startsWith('www.')) h = h.substring(4);
    return h;
  }

  static Set<String> _normalizeHosts(Iterable<String> hosts) =>
      hosts.map(_normalizeHost).where((h) => h.isNotEmpty).toSet();

  static bool _matchesAny(String host, Set<String> rules) {
    for (final r in rules) {
      if (host == r || host.endsWith('.$r')) return true;
    }
    return false;
  }
}
