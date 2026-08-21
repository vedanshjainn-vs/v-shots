// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Ad Block Engine (Forceful, Always-On, Production-Grade)
// ═════════════════════════════════════════════════════════════════════════════
//
// CENTRALIZED ad-blocking engine for ALL V Shots browser instances.
// This is the SINGLE SOURCE OF TRUTH for ad-blocking rules.
//
// DESIGN:
//   • Network-level blocking (primary defense)
//   • URL pattern matching (catches ad paths/queries)
//   • Host-based blocking (catches ad domains)
//   • Cosmetic DOM blocking (hides residual ad containers)
//   • Popup/redirect blocking
//   • Video ad blocking (VAST/VPAID)
//
// YOUTUBE COMPATIBILITY:
//   • YouTube normal content is ALWAYS allowed
//   • Only YouTube ad-specific endpoints are blocked
//   • Video playback, comments, search, login all work normally
//
// PERFORMANCE:
//   • Compiled host sets (O(1) lookup)
//   • Compiled URL patterns (minimal regex)
//   • Cached decisions where possible
//   • No per-request file I/O
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vshots_youtube_ad_blocker.dart';

/// Centralized ad-blocking engine.
/// Every V Shots browser WebView MUST use this engine.
class VShotsAdBlockEngine {
  VShotsAdBlockEngine._();
  static final VShotsAdBlockEngine instance = VShotsAdBlockEngine._();

  static const _kEnabled = 'v_shots.adblock.enabled.v1';
  static const _kUserAllow = 'v_shots.adblock.user_allow.v1';

  bool _enabled = true;
  bool _initialized = false;
  SharedPreferences? _prefs;

  /// User-added allowlist (persisted).
  final Set<String> _userAllow = {};

  /// Statistics
  int blockedAds = 0;
  int blockedTrackers = 0;
  int blockedPopups = 0;
  int blockedVideoAds = 0;

  bool get enabled => _enabled;
  bool get isInitialized => _initialized;

  // ══════════════════════════════════════════════════════════════════════════
  // ESSENTIAL HOSTS (NEVER BLOCKED — required for YouTube/websites)
  // ══════════════════════════════════════════════════════════════════════════

  /// Hosts that are ESSENTIAL for YouTube/websites to function.
  /// These are NEVER blocked, even if they appear in a blocklist.
  static final Set<String> essentialHosts = _normalizeHosts([
    // YouTube core
    'youtube.com',
    'youtu.be',
    'youtube-nocookie.com',
    'youtube-ui.l.google.com',
    'youtubeembedded-pa.googleapis.com',
    'youtube.googleapis.com',
    's.youtube.com',
    'm.youtube.com',
    'www.youtube.com',
    // YouTube video/media
    'googlevideo.com',
    'ytimg.com',
    'yt3.ggpht.com',
    'yt3.googleusercontent.com',
    // Google core (required for YouTube auth, APIs)
    'google.com',
    'googleapis.com',
    'gstatic.com',
    'ggpht.com',
    'googleusercontent.com',
    'accounts.google.com',
    'play.google.com',
    // Google video/media
    'googleusercontent.com',
    'lh3.googleusercontent.com',
    'lh4.googleusercontent.com',
    'lh5.googleusercontent.com',
    'lh6.googleusercontent.com',
    // Essential CDN/infrastructure
    'cloudflare.com',
    'cloudflare-dns.com',
    'cdnjs.cloudflare.com',
    // Supabase (V Shots backend)
    'supabase.co',
    'supabase.in',
    'supabase.io',
    // JioSaavn official domains (webpage playback — never block)
    'jiosaavn.com',
    'www.jiosaavn.com',
    'saavn.com',
    'www.saavn.com',
    'static.saavncdn.com',
    'c.saavncdn.com',
  ]);

  // ══════════════════════════════════════════════════════════════════════════
  // BLOCKED AD DOMAINS (comprehensive, production-grade)
  // ══════════════════════════════════════════════════════════════════════════

  /// Comprehensive list of known ad-serving, tracking, and ad-network domains.
  /// Host-suffix matching: "doubleclick.net" also blocks "ad.doubleclick.net".
  static const List<String> _blockedDomains = [
    // ── Google Ad Network ──────────────────────────────────────────────────
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adservice.google.com',
    'pagead2.googlesyndication.com',
    'tpc.googlesyndication.com',
    'googleads.g.doubleclick.net',
    'ad.doubleclick.net',
    'static.doubleclick.net',
    'm.doubleclick.net',
    'adx.g.doubleclick.net',
    'feedads.g.doubleclick.net',
    'googleadservices.com',
    'www.googleadservices.com',
    'pagead.googlesyndication.com',
    'adservice.google.com',
    'adservice.google.co.uk',
    'adservice.google.co.in',

    // ── Major Ad Exchanges / SSPs ──────────────────────────────────────────
    'adnxs.com',
    'adnxs-simple.com',
    'rubiconproject.com',
    'pubmatic.com',
    'openx.net',
    'openx.com',
    'casalemedia.com',
    'criteo.com',
    'criteo.net',
    'smartadserver.com',
    'adform.net',
    'sovrn.com',
    'sharethrough.com',
    'teads.tv',
    'teads.com',
    'yieldmo.com',
    'amazon-adsystem.com',
    'aaxads.com',
    'aax.amazon-adsystem.com',
    'taboola.com',
    'taboola.com',
    'outbrain.com',
    'mgid.com',
    'revcontent.com',
    'exoclick.com',
    'popads.net',
    'adsterra.com',
    'propellerads.com',
    'yieldlab.net',
    'advertising.com',
    'adsrvr.org',
    'bidswitch.net',
    'indexww.com',
    'onetag-sys.com',
    '33across.com',
    'adroll.com',
    'lijit.com',
    'zergnet.com',
    'popcash.net',
    'ad-maven.com',
    'adcash.com',
    'media.net',
    'adlightning.com',
    'springserve.com',
    'kargo.com',
    'sonobi.com',
    'undertone.com',
    'vidoomy.com',
    'pixel.popads.net',

    // ── Video Ad Networks (VAST/VPAID) ────────────────────────────────────
    'innovid.com',
    'serving-sys.com',
    'flashtalking.com',
    'eyewonder.com',
    'pointroll.com',
    'eyewonder.com',
    'adaptv.advertising.com',
    'spotxchange.com',
    'spotx.tv',
    'tremorhub.com',
    'tremorvideo.com',
    'freewheel.com',
    'freewheel.tv',
    'stickyadstv.com',
    'spongecell.com',
    'videologygroup.com',
    'videology.com',
    'yumenetworks.com',
    'dynamicyield.com',
    'innity.com',
    'brealtime.com',
    'emxdgt.com',
    'contextweb.com',
    'pulsepoint.com',
    'districtm.io',
    'rhythmone.com',
    'unrulymedia.com',
    'teads.tv',
    'teads.com',
    'vidible.tv',
    'stickyadstv.com',

    // ── Facebook/Meta Ads ─────────────────────────────────────────────────
    'facebook.com',
    'fbcdn.net',
    'facebook.net',
    'facebook.com/tr',
    'connect.facebook.net',
    'graph.facebook.com',
    'pixel.facebook.com',
    'analytics.facebook.com',

    // ── TikTok Ads ────────────────────────────────────────────────────────
    'analytics.tiktok.com',
    'ads.tiktok.com',
    'business.tiktok.com',

    // ── Twitter/X Ads ─────────────────────────────────────────────────────
    'ads.twitter.com',
    'analytics.twitter.com',
    't.co',

    // ── LinkedIn Ads ──────────────────────────────────────────────────────
    'ads.linkedin.com',
    'snap.licdn.com',
    'linkedin.com/px',

    // ── Pinterest Ads ─────────────────────────────────────────────────────
    'ads.pinterest.com',
    'ct.pinterest.com',
    'analytics.pinterest.com',

    // ── Snapchat Ads ──────────────────────────────────────────────────────
    'tr.snapchat.com',
    'sc-static.net',
    'snapads.com',

    // ── Amazon Ads ────────────────────────────────────────────────────────
    'amazon-adsystem.com',
    'aaxads.com',
    'aax.amazon-adsystem.com',
    'fls-na.amazon.com',
    'advertising.amazon.com',

    // ── Microsoft/Bing Ads ────────────────────────────────────────────────
    'bat.bing.com',
    'clarity.ms',
    'ads.microsoft.com',
    'adnxs.com',

    // ── Yahoo Ads ─────────────────────────────────────────────────────────
    'advertising.com',
    'ads.yahoo.com',
    'adtech.yahoo.com',
    'gemini.yahoo.com',

    // ── Verizon Media Ads ─────────────────────────────────────────────────
    'advertising.com',
    'adtech.yahoo.com',
    'one.impact-ad.jp',

    // ── Analytics / Telemetry / Tracking ──────────────────────────────────
    'google-analytics.com',
    'www.google-analytics.com',
    'ssl.google-analytics.com',
    'googletagmanager.com',
    'www.googletagmanager.com',
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
    'branch.io',
    'appsflyer.com',
    'adjust.com',
    'kochava.com',
    'matomo.cloud',
    'newrelic.com',
    'datadoghq.com',
    'sentry.io',
    'analytics.tiktok.com',
    'heapanalytics.com',
    'inspectlet.com',
    'luckyorange.com',
    'crazyegg.com',
    'clicktale.com',
    'usabilla.com',
    'optimizely.com',
    'vwo.com',
    'abtasty.com',
    'convert.com',
    'kissmetrics.com',
    'keen.io',
    'segment.io',
    'segment.com',
    'rudderstack.com',
    'snowplowanalytics.com',
    'mParticle.com',

    // ── Adware / Malware / Scam ───────────────────────────────────────────
    'adware.com',
    'malwarebytes.com',
    'scamadviser.com',
    'forter.com',
    'riskified.com',

    // ── Popup / Redirect Networks ─────────────────────────────────────────
    'popads.net',
    'popcash.net',
    'propellerads.com',
    'adsterra.com',
    'exoclick.com',
    'trafficjunky.com',
    'juicyads.com',
    'hilltopads.com',
    'clickadu.com',
    'popmyads.com',
    'popunder.net',
    'popunder.com',
    'popunder.org',
    'popunder.net',
    'popunder.com',
    'popunder.org',

    // ── Native Ad Networks ────────────────────────────────────────────────
    'taboola.com',
    'outbrain.com',
    'mgid.com',
    'revcontent.com',
    'adyoulike.com',
    'nativo.com',
    'sharethrough.com',
    'triplelift.com',
    'polar.me',
    'insticator.com',
    'vidoomy.com',

    // ── Affiliate / Referral Tracking ─────────────────────────────────────
    'shareasale.com',
    'cj.com',
    'commission-junction.com',
    'linksynergy.com',
    'click.linksynergy.com',
    'rakuten.com',
    'impact.com',
    'impactradius.com',
    'tkqlhce.com',
    'dpbolvw.net',
    'anrdoezrs.net',
    'jdoqocy.com',
    'kqzyfj.com',
    'qlnk.net',
    'emjcd.com',
    'afcyhf.com',
    'yceml.net',

    // ── China/Asia Ad Networks ────────────────────────────────────────────
    'tanx.com',
    'taobao.com',
    'alimama.com',
    'mmstat.com',
    'atanx.alicdn.com',
    'beacon.sina.com.cn',
    'pos.baidu.com',
    'cpro.baidu.com',
    'drmcmm.baidu.com',
    'hm.baidu.com',
    'hmcdn.baidu.com',
    'nsclick.baidu.com',
    'entry.baidu.com',
    'baidustatic.com',
    'bdimg.com',
    'bdstatic.com',
    'share.baidu.com',

    // ── European Ad Networks ──────────────────────────────────────────────
    'adform.net',
    'smartadserver.com',
    'yieldlab.net',
    'sascdn.com',
    'serving-sys.com',
    'emediate.eu',
    'adtech.de',
    'adtech.com',
    'interactive-circle.de',
    'mbr-target.de',
    'nuggad.net',
    'visualwebsiteoptimizer.com',

    // ── Video Ad Specific ─────────────────────────────────────────────────
    'innovid.com',
    'serving-sys.com',
    'flashtalking.com',
    'eyewonder.com',
    'pointroll.com',
    'adaptv.advertising.com',
    'spotxchange.com',
    'spotx.tv',
    'tremorhub.com',
    'tremorvideo.com',
    'freewheel.com',
    'freewheel.tv',
    'stickyadstv.com',
    'spongecell.com',
    'videologygroup.com',
    'videology.com',
    'yumenetworks.com',
    'dynamicyield.com',
    'innity.com',
    'brealtime.com',
    'emxdgt.com',
    'contextweb.com',
    'pulsepoint.com',
    'districtm.io',
    'rhythmone.com',
    'unrulymedia.com',
    'teads.tv',
    'teads.com',
    'vidible.tv',
    'stickyadstv.com',

    // ── Cookie Consent / CMP (sometimes used for ad tracking) ─────────────
    'consentmanager.mgr.consensu.org',
    'consent.google.com',
    'cdn.consentmanager.mgr.consensu.org',

    // ── Fingerprinting / Device Tracking ──────────────────────────────────
    'fingerprintjs.com',
    'fpjs.io',
    'ipify.org',
    'ipinfo.io',
    'ipapi.com',
    'ip-api.com',
    'maxmind.com',
    'geoip-db.com',

    // ── Push Notification Ad Networks ─────────────────────────────────────
    'pushwoosh.com',
    'pushengage.com',
    'onesignal.com',
    'pushcrew.com',
    'pushassist.com',
    'pushnami.com',
    'pushprofit.net',
    'pushprofit.com',

    // ── In-App Ad SDKs ────────────────────────────────────────────────────
    'applovin.com',
    'applovin.com',
    'adcolony.com',
    'vungle.com',
    'unity3d.com/ads',
    'unityads.unity3d.com',
    'chartboost.com',
    'mopub.com',
    'inmobi.com',
    'tapjoy.com',
    'ironsrc.com',
    'fyber.com',
    'smaato.com',
    'startapp.com',
    'mintegral.com',
    'pangle.io',
    'pangolin-sdk-toutiao.com',
  ];

  static final Set<String> _compiledBlocked = _normalizeHosts(_blockedDomains);

  // ══════════════════════════════════════════════════════════════════════════
  // URL PATTERNS (catches ad paths, queries, VAST/VPAID)
  // ══════════════════════════════════════════════════════════════════════════

  /// URL path/query patterns that indicate ad resources.
  /// These are checked AFTER host matching (host must not be essential).
  static const List<String> _adUrlPatterns = [
    // Google/YouTube ad-specific paths
    '/pagead/',
    '/pcs/',
    '/ads/',
    '/ad/',
    '/adservice/',
    '/pagead2.googlesyndication.com',
    '/get_video_info',
    '/api/stats/',
    '/api/ads/',
    '/api/ad/',
    '/ad_break',
    '/adunit/',
    '/adview',
    '/adslot/',
    '/admanager/',
    '/dfp/',
    '/gpt/',
    '/googletag/',
    '/googletagmanager/',
    '/google_ads',
    '/googleads',
    '/adrequest',
    '/adresponse',
    '/adrender',
    '/adclick',
    '/adimpression',
    '/adtrack',
    '/adbeacon',
    '/adpixel',
    '/adlog',
    '/adserver',
    '/adxml',
    '/adjson',
    '/adjs',
    '/adscript',
    '/adstyle',
    '/adcss',
    '/adimage',
    '/advideo',
    '/admedia',
    '/adcreative',
    '/adunit',
    '/adslot',
    '/adzone',
    '/adspace',
    '/adplacement',
    '/adposition',
    '/adformat',
    '/adtype',
    '/adsize',
    '/addimension',
    '/adresolution',
    '/adquality',
    '/adbid',
    '/adtarget',
    '/adaudience',
    '/adsegment',
    '/addemographic',
    '/adcontext',
    '/adpage',
    '/adsite',
    '/adnetwork',
    '/adexchange',
    '/adssp',
    '/addsp',
    '/adrtb',
    '/adprebid',
    '/adheader',
    '/adfooter',
    '/adsidebar',
    '/adinterstitial',
    '/adrewarded',
    '/adnative',
    '/adbanner',
    '/adoverlay',
    '/adpopup',
    '/adpopunder',
    '/adredirect',
    '/adtrack',
    '/adbeacon',
    '/adpixel',
    '/adlog',
    '/adserver',

    // VAST/VMAP/VPAID video ad protocols
    '/vast',
    '/vmap',
    '/vpaid',
    '/vast.xml',
    '/vmap.xml',
    '/vpaid.xml',
    '/vast?',
    '/vmap?',
    '/vpaid?',
    '/vast_url',
    '/vmap_url',
    '/vpaid_url',
    '/ad_tag',
    '/ad_tag_url',
    '/adtag',
    '/adtagurl',
    '/ad_url',
    '/adurl',
    '/adlink',
    '/adclick',
    '/adtrack',
    '/adbeacon',
    '/adpixel',
    '/adlog',
    '/adserver',

    // Common ad query parameters
    '?ad_unit',
    '?ad_unit_id',
    '?ad_unit_code',
    '?ad_slot',
    '?ad_zone',
    '?ad_network',
    '?ad_exchange',
    '?ad_ssp',
    '?ad_dsp',
    '?ad_rtb',
    '?ad_prebid',
    '?ad_header',
    '?ad_footer',
    '?ad_sidebar',
    '?ad_interstitial',
    '?ad_rewarded',
    '?ad_native',
    '?ad_banner',
    '?ad_overlay',
    '?ad_popup',
    '?ad_popunder',
    '?ad_redirect',
    '?ad_track',
    '?ad_beacon',
    '?ad_pixel',
    '?ad_log',
    '?ad_server',

    // Pre/mid/post-roll video ad markers
    '&ad_break',
    '&ad_pod',
    '&ad_sequence',
    '&ad_position',
    '&ad_offset',
    '&ad_duration',
    '&ad_creative',
    '&ad_media',
    '&ad_video',
    '&ad_audio',
    '&ad_companion',
    '&ad_overlay',
    '&ad_banner',
    '&ad_interstitial',
    '&ad_rewarded',
    '&ad_native',

    // YouTube-specific ad endpoints (while preserving normal YouTube)
    '&adformat=',
    '&ad_type=',
    '&ad_module=',
    '&ad_break_type=',
    '&ad_break_length=',
    '&ad_break_position=',
    '/api/stats/watchtime',
    '/api/stats/qoe',
    '/api/stats/playback',
    '/api/stats/atr',
    '/api/stats/ads',
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // TRACKING DOMAINS (separate from ads — for stats classification)
  // ══════════════════════════════════════════════════════════════════════════

  static final Set<String> _trackerHosts = _normalizeHosts([
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
    'heapanalytics.com',
    'inspectlet.com',
    'luckyorange.com',
    'crazyegg.com',
    'clicktale.com',
    'usabilla.com',
    'optimizely.com',
    'vwo.com',
    'abtasty.com',
    'convert.com',
    'kissmetrics.com',
    'keen.io',
    'rudderstack.com',
    'snowplowanalytics.com',
    'mParticle.com',
    'fingerprintjs.com',
    'fpjs.io',
    'ipify.org',
    'ipinfo.io',
    'ipapi.com',
    'ip-api.com',
    'maxmind.com',
    'geoip-db.com',
  ]);

  // ══════════════════════════════════════════════════════════════════════════
  // CORE API
  // ══════════════════════════════════════════════════════════════════════════

  /// Initialize the engine (load persisted state).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _prefs = await SharedPreferences.getInstance();
      _enabled = _prefs?.getBool(_kEnabled) ?? true;
      final allow = _prefs?.getString(_kUserAllow);
      if (allow != null && allow.isNotEmpty) {
        _userAllow.addAll(_normalizeHosts(allow.split(',')));
      }
      debugPrint(
        '[AdBlock] Engine initialized: enabled=$_enabled, '
        '${_compiledBlocked.length} blocked hosts, '
        '${essentialHosts.length} essential hosts',
      );
    } catch (e) {
      debugPrint('[AdBlock] Init failed: $e');
    }
  }

  /// Enable/disable the blocker (persisted).
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _prefs?.setBool(_kEnabled, value);
  }

  /// Adds a user allowlist host (persisted).
  Future<void> allowHost(String host) async {
    final h = _normalizeHost(host);
    if (h.isEmpty) return;
    _userAllow.add(h);
    await _prefs?.setString(_kUserAllow, _userAllow.join(','));
  }

  /// Is [url] on the explicit allowlist (essential + user)?
  bool isAllowed(String url) {
    final host = _normalizeHost(_hostOf(url));
    if (host.isEmpty) return false;
    return essentialHosts.contains(host) || _userAllow.contains(host);
  }

  /// Should [url] be BLOCKED?
  /// Returns true if the request should be intercepted and blocked.
  ///
  /// Order of checks:
  /// 1. If blocker disabled → ALLOW
  /// 2. If essential host → ALLOW (except YouTube ads)
  /// 3. If user allowlisted → ALLOW
  /// 4. If YouTube ad → BLOCK
  /// 5. If host in blocklist → BLOCK
  /// 6. If URL matches ad pattern → BLOCK
  /// 7. Otherwise → ALLOW (conservative)
  bool shouldBlock(String url) {
    if (!_enabled) return false;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final host = _normalizeHost(uri.host);
    if (host.isEmpty) return false;

    // User allowlist wins (but NOT for YouTube ads)
    if (_userAllow.contains(host) && !_isYouTubeDomain(host)) return false;

    // YouTube-specific ad blocking (even on essential hosts)
    if (VShotsYouTubeAdBlocker.shouldBlock(url)) {
      blockedVideoAds++;
      return true;
    }

    // Essential hosts are NEVER blocked (except YouTube ads handled above)
    if (essentialHosts.contains(host)) return false;

    // Host-based blocking
    if (_matchesAnyHost(host, _compiledBlocked)) return true;

    // URL pattern blocking (only for non-essential hosts)
    if (_matchesAdPattern(url, uri)) return true;

    return false;
  }

  /// Check if host is a YouTube domain.
  static bool _isYouTubeDomain(String host) {
    const youtubeDomains = [
      'youtube.com',
      'youtu.be',
      'youtube-nocookie.com',
      'googlevideo.com',
      'ytimg.com',
      'yt3.ggpht.com',
      'yt3.googleusercontent.com',
      'youtube-ui.l.google.com',
      'youtubeembedded-pa.googleapis.com',
      'youtube.googleapis.com',
      's.youtube.com',
    ];

    for (final domain in youtubeDomains) {
      if (host == domain || host.endsWith('.$domain')) {
        return true;
      }
    }
    return false;
  }

  /// Records a blocked resource for diagnostics.
  void recordBlocked(String host) {
    final h = _normalizeHost(host);
    if (_trackerHosts.contains(h)) {
      blockedTrackers++;
    } else {
      blockedAds++;
    }
  }

  void recordBlockedPopup() => blockedPopups++;
  void recordBlockedVideoAd() => blockedVideoAds++;

  /// Reset statistics.
  void resetStats() {
    blockedAds = 0;
    blockedTrackers = 0;
    blockedPopups = 0;
    blockedVideoAds = 0;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NATIVE BRIDGE DATA (sent to Android WebView)
  // ══════════════════════════════════════════════════════════════════════════

  /// Compiled blocklist hosts for native WebView.
  List<String> get blockedHosts => List.unmodifiable(_compiledBlocked);

  /// Essential hosts for native WebView.
  List<String> get essentialHostsList => List.unmodifiable(essentialHosts);

  /// URL patterns for native WebView (sent as strings for matching).
  List<String> get adUrlPatterns => List.unmodifiable(_adUrlPatterns);

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

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
    // Remove trailing dot
    if (h.endsWith('.')) h = h.substring(0, h.length - 1);
    return h;
  }

  static Set<String> _normalizeHosts(Iterable<String> hosts) =>
      hosts.map(_normalizeHost).where((h) => h.isNotEmpty).toSet();

  /// Host == rule or endsWith ".rule" (e.g. "doubleclick.net" matches
  /// "ad.doubleclick.net").
  static bool _matchesAnyHost(String host, Set<String> rules) {
    for (final rule in rules) {
      if (host == rule || host.endsWith('.$rule')) return true;
    }
    return false;
  }

  /// Check if URL matches known ad patterns (paths, queries, VAST/VPAID).
  static bool _matchesAdPattern(String url, Uri uri) {
    final lowerUrl = url.toLowerCase();
    final path = uri.path.toLowerCase();
    final query = uri.query.toLowerCase();

    for (final pattern in _adUrlPatterns) {
      final lowerPattern = pattern.toLowerCase();
      // Check path
      if (path.contains(lowerPattern)) return true;
      // Check full URL (for query params)
      if (lowerUrl.contains(lowerPattern)) return true;
    }

    // VAST/VMAP/VPAID specific checks
    if (path.contains('/vast') ||
        path.contains('/vmap') ||
        path.contains('/vpaid') ||
        query.contains('vast') ||
        query.contains('vmap') ||
        query.contains('vpaid')) {
      // Only block if NOT on essential host (YouTube uses /vast internally)
      final host = _normalizeHost(uri.host);
      if (!essentialHosts.contains(host)) {
        return true;
      }
    }

    return false;
  }
}
