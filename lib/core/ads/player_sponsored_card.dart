// ═════════════════════════════════════════════════════════════════════════
// V Shots — Player Sponsored Card (Unity LevelPlay native, premium)
//
// The premium, non-intrusive native ad experience for the For You player
// screen. Mounted ONLY on the ACTIVE song card (so it swipes naturally
// with the song page and there is never more than one ad at a time).
//
// Lifecycle (see player_sponsored_ad_policy.dart for the decision rules):
//   song starts ── no ad. A 1 Hz heartbeat accumulates LISTENING time only
//   (read-only observation of VShotsPlaybackManager — nothing in the
//   playback stack is ever touched, paused, seeked or reloaded).
//   ~2.5 s before the randomized 10–15 s eligibility point ── the native ad
//   view mounts hidden and starts loading (asynchronous preload; never a
//   placeholder). If the user swipes away first, the card disposes and no
//   ad is ever shown (and usually not even requested).
//   eligible + loaded ── the card smoothly fades/rises in, in exactly ONE
//   of three premium layouts chosen by the placement manager:
//     A) glassCard      — glassmorphism card straddling the cover art's
//                         lower edge (backdrop blur over the artwork)
//     B) compactRow     — compact sponsored row fully below the artwork
//     C) cornerCreative — small creative tucked into the cover's
//                         lower-left corner (the play badge is lower-RIGHT)
//
// Fail-safes: unconfigured / policy-blocked / consent pending / SDK not
// ready / load failed ⇒ nothing is ever shown — the normal premium player
// UI remains, with no empty card and no layout shift.
//
// Cleanup: one ad object per card mount, destroyed on dispose; the 1 Hz
// timer is cancelled; no listeners are registered on the playback manager
// (pure polling — zero coupling, zero leaks).
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../playback/vshots_playback_manager.dart';
import '../theme/app_colors.dart';
import 'ad_analytics.dart';
import 'ad_policy.dart';
import 'levelplay_config.dart';
import 'levelplay_service.dart';
import 'player_sponsored_ad_policy.dart';

/// Premium sponsored card for the For You player. Mount inside the player
/// card's Stack wrapped in a `Positioned.fill`, and only while that card
/// is the active one.
class PlayerSponsoredCard extends StatefulWidget {
  const PlayerSponsoredCard({
    super.key,
    required this.trackId,
    required this.coverSide,
    this.policy,
    this.placement,
  });

  /// Id of the song this card is mounted on (eligibility resets per song).
  final String trackId;

  /// Side length of the square cover art on this card (matches the player
  /// card's own computation) — used for proportional placement.
  final double coverSide;

  /// Policy override (tests). Defaults to the shared session instance.
  final PlayerSponsoredAdPolicy? policy;

  /// Placement manager override (tests).
  final PlayerSponsoredPlacementManager? placement;

  @override
  State<PlayerSponsoredCard> createState() => _PlayerSponsoredCardState();
}

class _PlayerSponsoredCardState extends State<PlayerSponsoredCard>
    with LevelPlayNativeAdListener {
  late final PlayerSponsoredAdPolicy _policy =
      widget.policy ?? PlayerSponsoredAdPolicy.instance;
  late final PlayerSponsoredPlacementManager _placement =
      widget.placement ?? PlayerSponsoredPlacementManager.instance;

  Timer? _ticker;
  LevelPlayNativeAd? _nativeAd;
  PlayerSponsoredVariant? _variant;

  bool _adCreated = false;
  bool _loadFailed = false;
  bool _loaded = false;
  bool _revealed = false;

  /// Last laid-out card size + safe-area insets (geometry for the placement
  /// manager, which runs outside build).
  Size? _lastSize;
  double _lastSafeTop = 0;
  double _lastSafeBottom = 0;

  @override
  void initState() {
    super.initState();
    _policy.onSongStarted();
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  @override
  void didUpdateWidget(covariant PlayerSponsoredCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId ||
        oldWidget.coverSide != widget.coverSide) {
      // The card state was recycled for a different song — full reset.
      _resetForNewSong();
    }
  }

  void _resetForNewSong() {
    _ticker?.cancel();
    _nativeAd?.destroyAd();
    _nativeAd = null;
    _variant = null;
    _adCreated = false;
    _loadFailed = false;
    _loaded = false;
    _revealed = false;
    _policy.onSongStarted();
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _nativeAd?.destroyAd();
    _nativeAd = null;
    super.dispose();
  }

  // ── Heartbeat ──────────────────────────────────────────────────────────

  void _onTick(Timer timer) {
    if (!mounted) return;
    _policy.tick(isPlaying: _isCardSongPlaying());
    _maybeCreateAd();
    _maybeReveal();
  }

  /// READ-ONLY playback observation: true only while THIS card's song is
  /// the session's current track AND the page reports it as actually
  /// playing. Fails closed (no ad) on any unknown state. The playback
  /// manager/browser are never modified — only read.
  bool _isCardSongPlaying() {
    final browser = VShotsPlaybackManager.instance.browser;
    final currentId = browser.track?['id'] as String?;
    if (currentId == null || currentId != widget.trackId) return false;
    return browser.pagePlaying == true;
  }

  // ── Ad lifecycle ───────────────────────────────────────────────────────

  void _maybeCreateAd() {
    if (_adCreated || _loadFailed || _revealed) return;
    if (!_policy.shouldPreload) return;
    // Request only when a reveal would actually be allowed — no wasted ad
    // requests while frequency rules say "not yet" (re-checked next tick).
    if (!_policy.frequencyAllows()) return;
    if (!AdPolicy.instance.canShowNative(AdPlacement.player)) return;
    if (!VShotsLevelPlay.instance.initSucceeded) return; // retried next tick
    _createAd();
  }

  void _createAd() {
    _adCreated = true;
    _policy.markPreloaded();

    // Choose the layout now — the hidden preload mounts in its final
    // geometry so the reveal is a pure fade/rise with no layout shift.
    final size = _lastSize;
    _variant = size == null
        ? PlayerSponsoredVariant.glassCard
        : _placement.choose(
            availableGap: _availableGap(size),
            coverSide: widget.coverSide,
          );

    AdAnalytics.log(
      'ad_request',
      placement: AdPlacement.player.key,
      detail: 'native (variant: ${_variant?.name})',
    );
    _nativeAd = LevelPlayNativeAd.builder()
        .withPlacementName(LevelPlayPlacement.playerNative)
        .withListener(this)
        .build();
    if (mounted) setState(() {});
  }

  void _maybeReveal() {
    if (_revealed || !_loaded || _loadFailed) return;
    if (!_policy.mayReveal) return;
    _reveal();
  }

  void _reveal() {
    _revealed = true;
    _policy.reveal();
    AdAnalytics.log(
      'ad_displayed',
      placement: AdPlacement.player.key,
      detail: 'player sponsored card (variant: ${_variant?.name})',
    );
    VShotsLevelPlay.instance.noteActivity(
      'player_native',
      'SPONSORED CARD REVEALED (variant: ${_variant?.name})',
    );
    if (mounted) setState(() {});
  }

  // ── LevelPlayNativeAdListener ──────────────────────────────────────────

  @override
  void onAdLoaded(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    VShotsLevelPlay.instance.noteFill('native', adInfo.adNetwork);
    VShotsLevelPlay.instance.noteActivity(
      'player_native',
      'LOADED (network: ${adInfo.adNetwork})',
    );
    AdAnalytics.log(
      'ad_loaded',
      placement: AdPlacement.player.key,
      detail: adInfo.adNetwork ?? '-',
    );
    _loaded = true;
    // Late-load case: reveal immediately if the song already qualified.
    if (_policy.mayReveal) {
      _reveal();
    }
  }

  @override
  void onAdLoadFailed(LevelPlayNativeAd nativeAd, IronSourceError error) {
    // Silent fail-safe: normal UI stays, no retry loop within this song.
    _loadFailed = true;
    AdAnalytics.log(
      'ad_load_failed',
      placement: AdPlacement.player.key,
      detail: '$error',
    );
    VShotsLevelPlay.instance.noteActivity(
      'player_native',
      'LOAD FAILED — $error',
    );
  }

  @override
  void onAdImpression(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    AdAnalytics.log(
      'ad_impression',
      placement: AdPlacement.player.key,
      detail:
          'network=${adInfo.adNetwork ?? '-'} revenue=${adInfo.revenue ?? 0}',
    );
  }

  @override
  void onAdClicked(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    VShotsLevelPlay.instance.noteActivity('player_native', 'CLICKED');
  }

  // ── Geometry (mirrors the player card's own cover placement math) ──────

  /// The cover art sits at Alignment(0, -0.12) inside a bottom-safe-area
  /// guard — its center lands at 44% of the safe height. This reproduces
  /// that math to know where the artwork's lower edge is.
  double _availableGap(Size cardSize) {
    final coverCenterY = _lastSafeTop + (cardSize.height - _lastSafeTop) * 0.44;
    final coverBottom = coverCenterY + widget.coverSide / 2;
    // Conservative reserve for the bottom metadata + controls strip
    // (title up to 2 lines, chips, 64 px controls row, safe area).
    return (cardSize.height - 250 - _lastSafeBottom) - coverBottom;
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_adCreated || _nativeAd == null) {
      // Nothing requested yet (or blocked): zero footprint, zero shift.
      return const SizedBox.shrink();
    }
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mq = MediaQuery.of(context);
          _lastSize = Size(constraints.maxWidth, constraints.maxHeight);
          _lastSafeTop = mq.padding.top;
          _lastSafeBottom = mq.padding.bottom;

          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final coverCenterY = mq.padding.top + (h - mq.padding.top) * 0.44;
          final coverBottom = coverCenterY + widget.coverSide / 2;
          final coverLeft = (w - widget.coverSide) / 2;

          final revealed = _revealed && _loaded;
          return Stack(
            children: [
              _buildVariantCard(
                coverBottom: coverBottom,
                coverLeft: coverLeft,
                cardWidth: w,
                revealed: revealed,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds the chosen variant's card at its final position. Exactly ONE
  /// variant is ever built, wrapped in the reveal animation (inert to
  /// input and semantics while hidden).
  Widget _buildVariantCard({
    required double coverBottom,
    required double coverLeft,
    required double cardWidth,
    required bool revealed,
  }) {
    final ad = _nativeAd;
    if (ad == null) return const SizedBox.shrink();

    Widget reveal(Widget child) => AnimatedOpacity(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      opacity: revealed ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        offset: revealed ? Offset.zero : const Offset(0, 0.06),
        child: ExcludeSemantics(
          excluding: !revealed,
          child: IgnorePointer(ignoring: !revealed, child: child),
        ),
      ),
    );

    switch (_variant) {
      case PlayerSponsoredVariant.glassCard:
        // A) Frosted-glass card straddling the artwork's lower edge.
        // Width stays clear of the cover's play-affordance corner.
        final cw = (widget.coverSide - 72).clamp(150.0, cardWidth - 40);
        const ch = 118.0;
        return Positioned(
          left: (cardWidth - cw) / 2,
          top: coverBottom - ch / 2 + 4,
          child: reveal(_GlassSponsoredCard(width: cw, height: ch, ad: ad)),
        );
      case PlayerSponsoredVariant.compactRow:
        // B) Compact sponsored row fully below the artwork.
        final cw = (widget.coverSide + 8).clamp(160.0, cardWidth - 40);
        const ch = 108.0;
        return Positioned(
          left: (cardWidth - cw) / 2,
          top: coverBottom + 6,
          child: reveal(_CompactSponsoredCard(width: cw, height: ch, ad: ad)),
        );
      case PlayerSponsoredVariant.cornerCreative:
      case null:
        // C) Small premium creative tucked into the cover's lower-LEFT
        // corner (the play badge lives lower-RIGHT — never covered).
        final cw = (widget.coverSide * 0.58).clamp(130.0, cardWidth - 60);
        const ch = 80.0;
        return Positioned(
          left: coverLeft + 10,
          top: coverBottom - 46,
          child: reveal(
            _CompactSponsoredCard(
              width: cw,
              height: ch,
              ad: ad,
              cornerStyle: true,
            ),
          ),
        );
    }
  }
}

// ── Variant A: glassmorphism card ──────────────────────────────────────────

/// Frosted-glass sponsored card that straddles the lower edge of the cover
/// art — the artwork blurs through the card (premium, integrated, clearly
/// labeled "Ad · Sponsored").
class _GlassSponsoredCard extends StatelessWidget {
  const _GlassSponsoredCard({
    required this.width,
    required this.height,
    required this.ad,
  });

  final double width;
  final double height;
  final LevelPlayNativeAd ad;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _SponsoredContent(
              ad: ad,
              labelColor: AppColors.hotPink,
              adHeight: 82,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Variants B & C: compact cards ──────────────────────────────────────────

/// Compact sponsored card: solid premium surface (B, below artwork) or the
/// smaller corner creative (C). Same clearly-labeled content.
class _CompactSponsoredCard extends StatelessWidget {
  const _CompactSponsoredCard({
    required this.width,
    required this.height,
    required this.ad,
    this.cornerStyle = false,
  });

  final double width;
  final double height;
  final LevelPlayNativeAd ad;
  final bool cornerStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xF20E1420),
          borderRadius: BorderRadius.circular(cornerStyle ? 14 : 16),
          border: Border.all(
            color: cornerStyle
                ? Colors.white.withValues(alpha: 0.14)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _SponsoredContent(
          ad: ad,
          labelColor: AppColors.hotPink,
          dense: cornerStyle,
          adHeight: cornerStyle ? 54 : 72,
        ),
      ),
    );
  }
}

// ── Shared content: label + LevelPlay native template ──────────────────────

/// The sponsored content: an unmissable "Ad · Sponsored" label above the
/// LevelPlay native ad template (which carries the SDK's own AdChoices
/// element). The template is styled to V Shots' dark premium palette.
class _SponsoredContent extends StatelessWidget {
  const _SponsoredContent({
    required this.ad,
    required this.labelColor,
    required this.adHeight,
    this.dense = false,
  });

  final LevelPlayNativeAd ad;
  final Color labelColor;
  final double adHeight;
  final bool dense;

  /// V Shots premium styling for the LevelPlay native template —
  /// transparent background (the container provides it), white title/body,
  /// cyan advertiser, violet CTA pill.
  LevelPlayNativeAdTemplateStyle _buildTemplateStyle() =>
      LevelPlayNativeAdTemplateStyle(
        mainBackgroundColor: const Color(0x00000000),
        titleStyle: LevelPlayNativeAdElementStyle(
          textColor: Colors.white,
          textSize: dense ? 11 : 12,
          fontStyle: LevelPlayNativeTemplateFontStyle.bold,
        ),
        bodyStyle: LevelPlayNativeAdElementStyle(
          textColor: const Color(0xCCFFFFFF),
          textSize: dense ? 9 : 10,
        ),
        advertiserStyle: LevelPlayNativeAdElementStyle(
          textColor: AppColors.accent,
          textSize: dense ? 8 : 9,
        ),
        callToActionStyle: LevelPlayNativeAdElementStyle(
          backgroundColor: AppColors.primary,
          textColor: Colors.white,
          cornerRadius: 14,
          textSize: dense ? 10 : 11,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        dense ? 6 : 8,
        dense ? 4 : 6,
        dense ? 6 : 8,
        dense ? 4 : 6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clearly-labeled sponsor tag — never mistaken for music content.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: labelColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Ad · Sponsored',
              style: TextStyle(
                color: labelColor,
                fontSize: dense ? 8.5 : 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          SizedBox(height: dense ? 3 : 5),
          RepaintBoundary(
            child: LevelPlayNativeAdView(
              nativeAd: ad,
              templateType: LevelPlayTemplateType.SMALL,
              templateStyle: _buildTemplateStyle(),
              width: double.infinity,
              height: adHeight,
              onPlatformViewCreated: ad.loadAd,
            ),
          ),
        ],
      ),
    );
  }
}
