// ═════════════════════════════════════════════════════════════════════════════
// V Shots — YouTube Ad Blocker (Specialized for YouTube)
// ═════════════════════════════════════════════════════════════════════════════
//
// Specialized ad blocking for YouTube that distinguishes between:
//   - Normal YouTube content (ALLOWED)
//   - YouTube advertisements (BLOCKED)
//
// YouTube serves ads from the same domains as content, so we need:
//   1. URL pattern matching for ad-specific endpoints
//   2. CSS/DOM manipulation to hide/remove ad containers
//   3. JavaScript injection to skip ads where possible
//
// IMPORTANT LIMITATION:
// YouTube's ad delivery is sophisticated and evolves frequently.
// This implementation blocks ads that can be reliably identified.
// Some ads may slip through if YouTube changes its delivery mechanism.
// ═════════════════════════════════════════════════════════════════════════════

/// Specialized YouTube ad blocking logic.
/// Works alongside VShotsAdBlockEngine for comprehensive coverage.
class VShotsYouTubeAdBlocker {
  VShotsYouTubeAdBlocker._();
  static final VShotsYouTubeAdBlocker instance = VShotsYouTubeAdBlocker._();

  // ══════════════════════════════════════════════════════════════════════════
  // YOUTUBE AD URL PATTERNS
  // ══════════════════════════════════════════════════════════════════════════

  /// YouTube ad-specific URL patterns that should be BLOCKED.
  /// These are paths/queries that indicate ad resources, NOT normal content.
  static const List<String> _youtubeAdPatterns = [
    // Google Ad endpoints on YouTube domains
    '/pagead/',
    '/pagead2.googlesyndication.com',
    '/pcs/',
    '/google_ads/',
    '/googleads',
    '/adservice/',
    '/ads/',
    '/ad/',
    '/ad_break',
    '/adunit/',
    '/adview',
    '/adslot/',
    '/admanager/',
    '/dfp/',
    '/gpt/',
    '/googletag/',
    '/googletagmanager/',

    // YouTube-specific ad endpoints
    '/api/stats/ads',
    '/api/stats/atr',
    '/get_video_info&adformat=',
    '/get_video_info?adformat=',
    '&adformat=',
    '&ad_type=',
    '&ad_module=',
    '&ad_break_type=',
    '&ad_break_length=',
    '&ad_break_position=',
    '&ad_break_start=',
    '&ad_break_end=',
    '&ad_preroll=',
    '&ad_midroll=',
    '&ad_postroll=',
    '&ad_pod=',
    '&ad_sequence=',
    '&ad_creative=',
    '&ad_media=',
    '&ad_video=',
    '&ad_audio=',
    '&ad_companion=',
    '&ad_overlay=',
    '&ad_banner=',
    '&ad_interstitial=',
    '&ad_rewarded=',
    '&ad_native=',
    '&ad_display=',
    '&ad_instream=',
    '&ad_outstream=',
    '&ad_overlay=',
    '&ad_companion=',
    '&ad_linear=',
    '&ad_nonlinear=',
    '&ad_skippable=',
    '&ad_nonskippable=',
    '&ad_preroll_duration=',
    '&ad_midroll_duration=',
    '&ad_postroll_duration=',
    '&ad_pod_id=',
    '&ad_pod_index=',
    '&ad_pod_count=',
    '&ad_pod_duration=',
    '&ad_pod_position=',
    '&ad_pod_sequence=',
    '&ad_pod_creative=',
    '&ad_pod_media=',
    '&ad_pod_video=',
    '&ad_pod_audio=',
    '&ad_pod_companion=',
    '&ad_pod_overlay=',
    '&ad_pod_banner=',
    '&ad_pod_interstitial=',
    '&ad_pod_rewarded=',
    '&ad_pod_native=',
    '&ad_pod_display=',
    '&ad_pod_instream=',
    '&ad_pod_outstream=',
    '&ad_pod_overlay=',
    '&ad_pod_companion=',
    '&ad_pod_linear=',
    '&ad_pod_nonlinear=',
    '&ad_pod_skippable=',
    '&ad_pod_nonskippable=',

    // YouTube ad tracking/measurement
    '/api/stats/watchtime&ad=',
    '/api/stats/watchtime?ad=',
    '/api/stats/qoe&ad=',
    '/api/stats/qoe?ad=',
    '/api/stats/playback&ad=',
    '/api/stats/playback?ad=',
    '/api/stats/atr&ad=',
    '/api/stats/atr?ad=',
    '/api/stats/ads&ad=',
    '/api/stats/ads?ad=',
    '/api/stats/ads?',
    '/api/stats/atr?',

    // YouTube ad rendering/creative
    '/ad_creative',
    '/ad_creative/',
    '/ad_render',
    '/ad_render/',
    '/ad_display',
    '/ad_display/',
    '/ad_overlay',
    '/ad_overlay/',
    '/ad_companion',
    '/ad_companion/',
    '/ad_banner',
    '/ad_banner/',
    '/ad_interstitial',
    '/ad_interstitial/',
    '/ad_rewarded',
    '/ad_rewarded/',
    '/ad_native',
    '/ad_native/',
    '/ad_instream',
    '/ad_instream/',
    '/ad_outstream',
    '/ad_outstream/',
    '/ad_linear',
    '/ad_linear/',
    '/ad_nonlinear',
    '/ad_nonlinear/',
    '/ad_skippable',
    '/ad_skippable/',
    '/ad_nonskippable',
    '/ad_nonskippable/',
  ];

  /// Domains that are YouTube ad-specific (block completely).
  /// These are NOT used for normal YouTube content.
  static const List<String> _youtubeAdDomains = [
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
  ];

  /// Check if a YouTube URL should be blocked as an ad.
  /// Returns true if the request is an ad that should be blocked.
  ///
  /// IMPORTANT: This only blocks ad-specific patterns on YouTube domains.
  /// Normal YouTube content (videos, pages, search) is NEVER blocked.
  static bool shouldBlockYouTubeAd(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final query = uri.query.toLowerCase();
    final fullUrl = url.toLowerCase();

    // Check if it's a YouTube ad-specific domain
    for (final adDomain in _youtubeAdDomains) {
      if (host == adDomain || host.endsWith('.$adDomain')) {
        return true;
      }
    }

    // Only check patterns on YouTube domains
    if (!_isYouTubeDomain(host)) return false;

    // Check URL patterns
    for (final pattern in _youtubeAdPatterns) {
      final lowerPattern = pattern.toLowerCase();
      if (path.contains(lowerPattern) || fullUrl.contains(lowerPattern)) {
        return true;
      }
    }

    // Check for ad-related query parameters
    if (_containsAdQueryParams(query)) {
      return true;
    }

    return false;
  }

  /// Check if host is a YouTube domain.
  static bool _isYouTubeDomain(String host) {
    const youtubeDomains = [
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'youtube-nocookie.com',
      'youtu.be',
      'ytimg.com',
      'yt3.ggpht.com',
      'yt3.googleusercontent.com',
      'youtube-ui.l.google.com',
      'youtubeembedded-pa.googleapis.com',
      'youtube.googleapis.com',
      's.youtube.com',
      'googlevideo.com',
    ];

    for (final domain in youtubeDomains) {
      if (host == domain || host.endsWith('.$domain')) {
        return true;
      }
    }
    return false;
  }

  /// Check if query string contains ad-related parameters.
  static bool _containsAdQueryParams(String query) {
    if (query.isEmpty) return false;

    const adParams = [
      'adformat=',
      'ad_type=',
      'ad_module=',
      'ad_break',
      'ad_pod',
      'ad_creative',
      'ad_media',
      'ad_video',
      'ad_audio',
      'ad_companion',
      'ad_overlay',
      'ad_banner',
      'ad_interstitial',
      'ad_rewarded',
      'ad_native',
      'ad_display',
      'ad_instream',
      'ad_outstream',
      'ad_linear',
      'ad_nonlinear',
      'ad_skippable',
      'ad_nonskippable',
      'ad_preroll',
      'ad_midroll',
      'ad_postroll',
    ];

    for (final param in adParams) {
      if (query.contains(param)) {
        return true;
      }
    }

    return false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // YOUTUBE AD CSS SELECTORS (for cosmetic blocking)
  // ══════════════════════════════════════════════════════════════════════════

  /// CSS selectors to hide YouTube ad elements.
  /// These target ad containers WITHOUT breaking normal video playback.
  static const String _youtubeAdCss = '''
    /* YouTube Ad Containers - Hide but don't remove */
    .ytp-ad-overlay-container,
    .ytp-ad-text-overlay,
    .ytp-ad-image-overlay,
    .ytp-ad-button-overlay,
    .ytp-ad-player-overlay,
    .ytp-ad-player-overlay-instream-info,
    .ytp-ad-player-overlay-instream-info-stat,
    .ytp-ad-player-overlay-instream-info-stat-container,
    .ytp-ad-player-overlay-instream-info-stat-text,
    .ytp-ad-player-overlay-instream-info-stat-value,
    .ytp-ad-player-overlay-instream-info-stat-label,
    .ytp-ad-player-overlay-instream-info-stat-icon,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-path,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-circle,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-rect,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-line,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-polygon,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-polyline,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-ellipse,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-text,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-use,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-image,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-switch,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-symbol,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-marker,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-pattern,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-clipPath,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-mask,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-filter,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feBlend,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feColorMatrix,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feComponentTransfer,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feComposite,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feConvolveMatrix,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feDiffuseLighting,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feDisplacementMap,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feDistantLight,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feDropShadow,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feFlood,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feFuncA,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feFuncB,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feFuncG,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feFuncR,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feGaussianBlur,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feImage,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feMerge,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feMergeNode,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feMorphology,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feOffset,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-fePointLight,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feSpecularLighting,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feSpotLight,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feTile,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-feTurbulence,
    .ytp-ad-player-overlay-instream-info-stat-icon-svg-foreignObject,

    /* YouTube Ad Overlays */
    .ytp-ad-overlay-slot,
    .ytp-ad-overlay-slot-area,
    .ytp-ad-overlay-slot-area-image,
    .ytp-ad-overlay-slot-area-image-link,
    .ytp-ad-overlay-slot-area-image-link-image,
    .ytp-ad-overlay-slot-area-image-link-image-img,
    .ytp-ad-overlay-slot-area-image-link-image-img-src,
    .ytp-ad-overlay-slot-area-image-link-image-img-alt,
    .ytp-ad-overlay-slot-area-image-link-image-img-title,
    .ytp-ad-overlay-slot-area-image-link-image-img-width,
    .ytp-ad-overlay-slot-area-image-link-image-img-height,
    .ytp-ad-overlay-slot-area-image-link-image-img-class,
    .ytp-ad-overlay-slot-area-image-link-image-img-id,
    .ytp-ad-overlay-slot-area-image-link-image-img-style,
    .ytp-ad-overlay-slot-area-image-link-image-img-data,
    .ytp-ad-overlay-slot-area-image-link-image-img-aria,
    .ytp-ad-overlay-slot-area-image-link-image-img-role,
    .ytp-ad-overlay-slot-area-image-link-image-img-tabindex,
    .ytp-ad-overlay-slot-area-image-link-image-img-onclick,
    .ytp-ad-overlay-slot-area-image-link-image-img-onload,
    .ytp-ad-overlay-slot-area-image-link-image-img-onerror,

    /* YouTube Ad Text */
    .ytp-ad-text,
    .ytp-ad-text-overlay,
    .ytp-ad-text-overlay-container,
    .ytp-ad-text-overlay-container-span,
    .ytp-ad-text-overlay-container-span-a,
    .ytp-ad-text-overlay-container-span-a-href,
    .ytp-ad-text-overlay-container-span-a-text,
    .ytp-ad-text-overlay-container-span-a-target,
    .ytp-ad-text-overlay-container-span-a-rel,
    .ytp-ad-text-overlay-container-span-a-class,
    .ytp-ad-text-overlay-container-span-a-id,
    .ytp-ad-text-overlay-container-span-a-style,
    .ytp-ad-text-overlay-container-span-a-data,
    .ytp-ad-text-overlay-container-span-a-aria,
    .ytp-ad-text-overlay-container-span-a-role,
    .ytp-ad-text-overlay-container-span-a-tabindex,
    .ytp-ad-text-overlay-container-span-a-onclick,
    .ytp-ad-text-overlay-container-span-a-onload,
    .ytp-ad-text-overlay-container-span-a-onerror,

    /* YouTube Ad Buttons */
    .ytp-ad-button,
    .ytp-ad-button-overlay,
    .ytp-ad-button-overlay-container,
    .ytp-ad-button-overlay-container-button,
    .ytp-ad-button-overlay-container-button-a,
    .ytp-ad-button-overlay-container-button-a-href,
    .ytp-ad-button-overlay-container-button-a-text,
    .ytp-ad-button-overlay-container-button-a-target,
    .ytp-ad-button-overlay-container-button-a-rel,
    .ytp-ad-button-overlay-container-button-a-class,
    .ytp-ad-button-overlay-container-button-a-id,
    .ytp-ad-button-overlay-container-button-a-style,
    .ytp-ad-button-overlay-container-button-a-data,
    .ytp-ad-button-overlay-container-button-a-aria,
    .ytp-ad-button-overlay-container-button-a-role,
    .ytp-ad-button-overlay-container-button-a-tabindex,
    .ytp-ad-button-overlay-container-button-a-onclick,
    .ytp-ad-button-overlay-container-button-a-onload,
    .ytp-ad-button-overlay-container-button-a-onerror,

    /* YouTube Ad Player */
    .ytp-ad-player,
    .ytp-ad-player-overlay,
    .ytp-ad-player-overlay-container,
    .ytp-ad-player-overlay-container-video,
    .ytp-ad-player-overlay-container-video-src,
    .ytp-ad-player-overlay-container-video-poster,
    .ytp-ad-player-overlay-container-video-controls,
    .ytp-ad-player-overlay-container-video-autoplay,
    .ytp-ad-player-overlay-container-video-muted,
    .ytp-ad-player-overlay-container-video-loop,
    .ytp-ad-player-overlay-container-video-preload,
    .ytp-ad-player-overlay-container-video-width,
    .ytp-ad-player-overlay-container-video-height,
    .ytp-ad-player-overlay-container-video-class,
    .ytp-ad-player-overlay-container-video-id,
    .ytp-ad-player-overlay-container-video-style,
    .ytp-ad-player-overlay-container-video-data,
    .ytp-ad-player-overlay-container-video-aria,
    .ytp-ad-player-overlay-container-video-role,
    .ytp-ad-player-overlay-container-video-tabindex,

    /* YouTube Ad Skip Button */
    .ytp-ad-skip-button,
    .ytp-ad-skip-button-modern,
    .ytp-ad-skip-button-slot,
    .ytp-ad-skip-button-slot-button,
    .ytp-ad-skip-button-slot-button-button,
    .ytp-ad-skip-button-slot-button-button-class,
    .ytp-ad-skip-button-slot-button-button-id,
    .ytp-ad-skip-button-slot-button-button-style,
    .ytp-ad-skip-button-slot-button-button-data,
    .ytp-ad-skip-button-slot-button-button-aria,
    .ytp-ad-skip-button-slot-button-button-role,
    .ytp-ad-skip-button-slot-button-button-tabindex,
    .ytp-ad-skip-button-slot-button-button-onclick,

    /* YouTube Ad Progress */
    .ytp-ad-progress,
    .ytp-ad-progress-bar,
    .ytp-ad-progress-bar-container,
    .ytp-ad-progress-bar-container-div,
    .ytp-ad-progress-bar-container-div-class,
    .ytp-ad-progress-bar-container-div-id,
    .ytp-ad-progress-bar-container-div-style,
    .ytp-ad-progress-bar-container-div-data,
    .ytp-ad-progress-bar-container-div-aria,
    .ytp-ad-progress-bar-container-div-role,
    .ytp-ad-progress-bar-container-div-tabindex,

    /* YouTube Ad Countdown */
    .ytp-ad-countdown,
    .ytp-ad-countdown-overlay,
    .ytp-ad-countdown-overlay-container,
    .ytp-ad-countdown-overlay-container-span,
    .ytp-ad-countdown-overlay-container-span-class,
    .ytp-ad-countdown-overlay-container-span-id,
    .ytp-ad-countdown-overlay-container-span-style,
    .ytp-ad-countdown-overlay-container-span-data,
    .ytp-ad-countdown-overlay-container-span-aria,
    .ytp-ad-countdown-overlay-container-span-role,
    .ytp-ad-countdown-overlay-container-span-tabindex,

    /* YouTube Display Ads */
    .ytd-display-ad-renderer,
    .ytd-statement-banner-renderer,
    .ytd-ad-slot-renderer,
    .ytd-in-feed-ad-layout-renderer,
    .ytd-banner-promo-renderer,
    .ytd-video-masthead-ad-v3-renderer,
    .ytd-engagement-panel-section-list-renderer[target-id="engagement-panel-ads"],
    .ytd-engagement-panel-section-list-renderer[target-id="engagement-panel-sponsored"],

    /* YouTube Ad Badges */
    .ytp-ad-badge,
    .ytp-ad-badge-container,
    .ytp-ad-badge-container-span,
    .ytp-ad-badge-container-span-class,
    .ytp-ad-badge-container-span-id,
    .ytp-ad-badge-container-span-style,
    .ytp-ad-badge-container-span-data,
    .ytp-ad-badge-container-span-aria,
    .ytp-ad-badge-container-span-role,
    .ytp-ad-badge-container-span-tabindex,

    /* YouTube Sponsored Content */
    .ytd-promoted-sparkles-web-renderer,
    .ytd-promoted-video-renderer,
    .ytd-primetime-promo-renderer,
    .ytd-brand-video-singleton-renderer,
    .ytd-brand-video-shelf-renderer,
    .ytd-merch-shelf-renderer,
    .ytd-carousel-ad-renderer,

    /* YouTube Ad Attribution */
    .ytp-ad-visit-advertiser-button,
    .ytp-ad-visit-advertiser-button-renderer,
    .ytp-ad-visit-advertiser-button-renderer-button,
    .ytp-ad-visit-advertiser-button-renderer-button-a,
    .ytp-ad-visit-advertiser-button-renderer-button-a-href,
    .ytp-ad-visit-advertiser-button-renderer-button-a-text,
    .ytp-ad-visit-advertiser-button-renderer-button-a-target,
    .ytp-ad-visit-advertiser-button-renderer-button-a-rel,
    .ytp-ad-visit-advertiser-button-renderer-button-a-class,
    .ytp-ad-visit-advertiser-button-renderer-button-a-id,
    .ytp-ad-visit-advertiser-button-renderer-button-a-style,
    .ytp-ad-visit-advertiser-button-renderer-button-a-data,
    .ytp-ad-visit-advertiser-button-renderer-button-a-aria,
    .ytp-ad-visit-advertiser-button-renderer-button-a-role,
    .ytp-ad-visit-advertiser-button-renderer-button-a-tabindex,
    .ytp-ad-visit-advertiser-button-renderer-button-a-onclick,
  {
    display: none !important;
    visibility: hidden !important;
    opacity: 0 !important;
    height: 0 !important;
    min-height: 0 !important;
    max-height: 0 !important;
    width: 0 !important;
    min-width: 0 !important;
    max-width: 0 !important;
    overflow: hidden !important;
    position: absolute !important;
    left: -9999px !important;
    top: -9999px !important;
    pointer-events: none !important;
    z-index: -1 !important;
  }
  ''';

  // ══════════════════════════════════════════════════════════════════════════
  // YOUTUBE AD SKIP JAVASCRIPT
  // ══════════════════════════════════════════════════════════════════════════

  /// JavaScript to skip YouTube ads where possible.
  /// This attempts to click "Skip Ad" buttons and close ad overlays.
  static const String _youtubeAdSkipJs = '''
    (function() {
      try {
        // Skip video ads by clicking skip button
        function skipVideoAd() {
          // Find and click skip button
          var skipButtons = document.querySelectorAll(
            '.ytp-ad-skip-button, .ytp-ad-skip-button-modern, ' +
            '.ytp-ad-skip-button-slot button, ' +
            '[class*="skip"] button, [class*="Skip"] button'
          );
          for (var i = 0; i < skipButtons.length; i++) {
            var btn = skipButtons[i];
            if (btn.offsetParent !== null) { // Check if visible
              btn.click();
              return true;
            }
          }

          // Try to find skip button by text
          var allButtons = document.querySelectorAll('button');
          for (var j = 0; j < allButtons.length; j++) {
            var b = allButtons[j];
            var text = (b.textContent || '').toLowerCase();
            var ariaLabel = (b.getAttribute('aria-label') || '').toLowerCase();
            if (text.indexOf('skip') >= 0 || text.indexOf('skip ad') >= 0 ||
                ariaLabel.indexOf('skip') >= 0 || ariaLabel.indexOf('skip ad') >= 0) {
              if (b.offsetParent !== null) {
                b.click();
                return true;
              }
            }
          }

          return false;
        }

        // Close ad overlays
        function closeAdOverlays() {
          var overlays = document.querySelectorAll(
            '.ytp-ad-overlay-container, .ytp-ad-text-overlay, ' +
            '.ytp-ad-image-overlay, .ytp-ad-button-overlay'
          );
          for (var i = 0; i < overlays.length; i++) {
            var overlay = overlays[i];
            if (overlay.offsetParent !== null) {
              overlay.style.display = 'none';
              overlay.style.visibility = 'hidden';
              overlay.style.opacity = '0';
              overlay.style.height = '0';
              overlay.style.overflow = 'hidden';
            }
          }
        }

        // Remove ad containers from DOM
        function removeAdContainers() {
          var adSelectors = [
            '.ytp-ad-overlay-container',
            '.ytp-ad-text-overlay',
            '.ytp-ad-image-overlay',
            '.ytp-ad-button-overlay',
            '.ytp-ad-player-overlay',
            '.ytp-ad-player-overlay-instream-info',
            '.ytd-display-ad-renderer',
            '.ytd-statement-banner-renderer',
            '.ytd-ad-slot-renderer',
            '.ytd-in-feed-ad-layout-renderer',
            '.ytd-banner-promo-renderer',
            '.ytd-video-masthead-ad-v3-renderer',
            '.ytd-promoted-sparkles-web-renderer',
            '.ytd-promoted-video-renderer',
            '.ytd-primetime-promo-renderer',
            '.ytd-brand-video-singleton-renderer',
            '.ytd-brand-video-shelf-renderer',
            '.ytd-merch-shelf-renderer',
            '.ytd-carousel-ad-renderer',
            '[id^="player_ads"]',
            '[id^="ad_"]',
            '[class*="ad-"]',
            '[class*="ads-"]',
            '[data-ad]',
            '[data-ad-slot]',
            '[data-ad-unit]',
          ];

          for (var i = 0; i < adSelectors.length; i++) {
            var elements = document.querySelectorAll(adSelectors[i]);
            for (var j = 0; j < elements.length; j++) {
              var el = elements[j];
              // Don't remove video player or essential elements
              if (el.tagName === 'VIDEO' || el.tagName === 'AUDIO') continue;
              if (el.querySelector('video') || el.querySelector('audio')) continue;
              if (el.closest('#movie_player') && !el.closest('[class*="ad"]')) continue;
              el.remove();
            }
          }
        }

        // Auto-skip ads after short delay
        function autoSkipAd() {
          var video = document.querySelector('video');
          if (video && video.closest('[class*="ad"]')) {
            // This is an ad video - try to skip it
            video.currentTime = video.duration || 0;
            video.playbackRate = 16; // Speed through ad
          }
        }

        // Run all ad-blocking functions
        skipVideoAd();
        closeAdOverlays();
        removeAdContainers();
        autoSkipAd();

        // Set up observer for dynamically loaded ads
        var observer = new MutationObserver(function(mutations) {
          skipVideoAd();
          closeAdOverlays();
        });

        var player = document.querySelector('#movie_player');
        if (player) {
          observer.observe(player, { childList: true, subtree: true });
        }

      } catch(e) {}
    })()
  ''';

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ══════════════════════════════════════════════════════════════════════════

  /// Check if URL should be blocked as a YouTube ad.
  static bool shouldBlock(String url) {
    return shouldBlockYouTubeAd(url);
  }

  /// Get CSS to hide YouTube ad elements.
  static String get cosmeticCss => _youtubeAdCss;

  /// Get JavaScript to skip YouTube ads.
  static String get adSkipJs => _youtubeAdSkipJs;

  /// Get list of YouTube ad-specific domains.
  static List<String> get adDomains => _youtubeAdDomains;

  /// Get list of YouTube ad URL patterns.
  static List<String> get adPatterns => _youtubeAdPatterns;
}
