// ═════════════════════════════════════════════════════════════════════════
// V Shots — Player Sponsored Ad Policy + Placement Manager
//
// Pure-Dart decision layer for the premium native sponsored card on the
// For You player screen (see player_sponsored_card.dart for presentation).
//
// Eligibility (per spec):
//   • A song NEVER shows an ad immediately — the user must genuinely
//     listen for ~10–15 s (threshold randomized per song).
//   • Only LISTENING time counts: pausing freezes the accumulator.
//   • Skipping away before the threshold ⇒ no ad, and (before the preload
//     lead) not even an ad request.
//
// Frequency (anti-excess, layered on top of mediation/network caps):
//   • minimum interval between sponsored-card reveals: 75 s
//   • minimum song starts between reveals: 3 (no ad on consecutive songs)
//   • hard cap per app session: 6
//   • an in-feed ad PAGE (Discovery cadence) resets the interval clock, so
//     the sponsored card and the ad page never crowd each other
//
// No refresh loop: after a reveal the card is latched for that song — a
// new creative can only arrive with a later song, through these rules.
//
// Pure Dart, no SDK calls — fully unit-testable.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:math';

import 'package:flutter/foundation.dart';

/// The three premium presentation layouts. Exactly ONE is ever shown per
/// reveal (chosen by [PlayerSponsoredPlacementManager]).
enum PlayerSponsoredVariant {
  /// Glassmorphism floating card straddling the lower edge of the cover art.
  glassCard,

  /// Compact sponsored row fully below the artwork (needs vertical room).
  compactRow,

  /// Small premium creative tucked into the cover art's lower-left corner.
  cornerCreative,
}

/// Decision engine for the player sponsored card. One shared instance for
/// the whole app session (frequency rules are session-wide).
class PlayerSponsoredAdPolicy {
  /// Shared app-session instance (frequency rules are session-wide).
  static final PlayerSponsoredAdPolicy instance = PlayerSponsoredAdPolicy();

  PlayerSponsoredAdPolicy({
    this.minEligibleAfter = const Duration(seconds: 10),
    this.maxEligibleAfter = const Duration(seconds: 15),
    this.preloadLead = const Duration(milliseconds: 2500),
    this.minRevealInterval = const Duration(seconds: 75),
    this.minSongsBetweenReveals = 3,
    this.maxRevealsPerSession = 6,
    Random? random,
  }) : _random = random ?? Random();

  /// Earliest eligibility point of the randomized per-song window.
  final Duration minEligibleAfter;

  /// Latest eligibility point of the randomized per-song window.
  final Duration maxEligibleAfter;

  /// How long BEFORE the eligibility point the ad starts preloading (so the
  /// reveal is instant when the song qualifies). Loading still requires a
  /// mounted ad view; see player_sponsored_card.dart.
  final Duration preloadLead;

  /// Minimum wall-clock time between two sponsored-card reveals.
  final Duration minRevealInterval;

  /// Minimum song STARTS after a reveal before the next reveal is allowed
  /// (3 ⇒ one ad song, two ad-free songs, then eligible again).
  final int minSongsBetweenReveals;

  /// Hard session cap (process lifetime).
  final int maxRevealsPerSession;

  final Random _random;

  // ── Per-song state (reset by onSongStarted) ────────────────────────────
  Duration _listened = Duration.zero;
  late Duration _threshold = _rollThreshold();
  bool _revealedThisSong = false;
  bool _preloadMarkedThisSong = false;

  // ── Cross-song / session state ────────────────────────────────────────
  /// Null until the first reveal of the session.
  int? _songsStartedSinceReveal;
  int _revealsThisSession = 0;
  DateTime? _lastRevealAt;

  /// Last time an EXTERNAL ad was shown in the same feed (the Discovery ad
  /// page). The sponsored card keeps the same minimum distance from it.
  DateTime? _lastExternalAdAt;

  Duration _rollThreshold() {
    final spanUs = (maxEligibleAfter - minEligibleAfter).inMicroseconds;
    final extra = spanUs <= 0 ? 0 : _random.nextInt(spanUs + 1);
    return minEligibleAfter + Duration(microseconds: extra);
  }

  // ── Per-song lifecycle ─────────────────────────────────────────────────

  /// A new song became the active card. Resets the per-song accumulator and
  /// re-rolls the eligibility threshold.
  void onSongStarted() {
    _listened = Duration.zero;
    _threshold = _rollThreshold();
    _revealedThisSong = false;
    _preloadMarkedThisSong = false;
    final songs = _songsStartedSinceReveal;
    if (songs != null) _songsStartedSinceReveal = songs + 1;
  }

  /// 1 Hz heartbeat from the player card. Only ticks while this card's song
  /// is the one actually playing — pausing freezes (never resets) the count.
  void tick({required bool isPlaying}) {
    if (_revealedThisSong) return; // latched: no refresh loop
    if (isPlaying) _listened += const Duration(seconds: 1);
  }

  /// Listening time accumulated this song.
  Duration get listened => _listened;

  /// The (already rolled) eligibility threshold for this song.
  Duration get threshold => _threshold;

  /// True once the user has genuinely listened past the threshold.
  bool get isEligible => _listened >= _threshold;

  /// True when the ad should START preloading (a little before eligibility
  /// so the reveal is seamless). Call [markPreloaded] once the request is
  /// issued to prevent duplicate requests.
  bool get shouldPreload =>
      !_preloadMarkedThisSong &&
      !_revealedThisSong &&
      _listened + preloadLead >= _threshold;

  /// Marks this song's preload as issued (one ad request per song mount).
  void markPreloaded() => _preloadMarkedThisSong = true;

  // ── Frequency rules ────────────────────────────────────────────────────

  /// Whether frequency rules allow a reveal RIGHT NOW. Does not consume any
  /// budget — call [reveal] when the ad is actually presented.
  bool frequencyAllows({DateTime? now}) {
    final t = now ?? DateTime.now();
    if (_revealsThisSession >= maxRevealsPerSession) return false;
    final lastAd = _laterOf(_lastRevealAt, _lastExternalAdAt);
    if (lastAd != null && t.difference(lastAd) < minRevealInterval) {
      return false;
    }
    final songs = _songsStartedSinceReveal;
    if (songs != null && songs < minSongsBetweenReveals) return false;
    return true;
  }

  /// Full reveal condition: eligible this song AND frequency rules pass.
  bool get mayReveal => isEligible && !_revealedThisSong && frequencyAllows();

  /// Records that the sponsored card was actually presented.
  void reveal({DateTime? now}) {
    if (_revealedThisSong) return;
    _revealedThisSong = true;
    _revealsThisSession++;
    _lastRevealAt = now ?? DateTime.now();
    _songsStartedSinceReveal = 0;
  }

  /// Notifies that an external ad (the Discovery in-feed ad PAGE) was just
  /// shown — the sponsored card keeps [minRevealInterval] distance from it.
  void noteExternalAdShown({DateTime? now}) {
    _lastExternalAdAt = now ?? DateTime.now();
  }

  /// Reveals shown this app session (diagnostics).
  int get revealsThisSession => _revealsThisSession;

  DateTime? _laterOf(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  /// Test/diagnostics helper: clears all counters.
  @visibleForTesting
  void reset() {
    _listened = Duration.zero;
    _threshold = _rollThreshold();
    _revealedThisSong = false;
    _preloadMarkedThisSong = false;
    _songsStartedSinceReveal = null;
    _revealsThisSession = 0;
    _lastRevealAt = null;
    _lastExternalAdAt = null;
  }
}

/// Chooses the most suitable premium layout variant for a reveal — never
/// the same variant twice in a row, never a variant that does not fit the
/// available vertical space. Exactly ONE variant is ever rendered.
class PlayerSponsoredPlacementManager {
  /// Shared app-session instance (variety memory is session-wide).
  static final PlayerSponsoredPlacementManager instance =
      PlayerSponsoredPlacementManager();

  PlayerSponsoredPlacementManager({Random? random})
      : _random = random ?? Random();

  final Random _random;
  PlayerSponsoredVariant? _lastVariant;

  /// Minimum free vertical gap (px, between the cover art's lower edge and
  /// the reserved metadata/controls strip) each variant needs below the
  /// artwork to be considered.
  static const double glassCardMinGap = 32; // straddles the artwork edge
  static const double compactRowMinGap = 96; // fully below the artwork
  static const double cornerCreativeMinGap = 8; // tucked into the corner

  /// Picks the variant for this reveal given the available vertical gap and
  /// the cover side (for proportional sizing). Falls back to
  /// [PlayerSponsoredVariant.cornerCreative] when nothing else fits — it
  /// overlaps only the artwork's own corner, so it always fits.
  PlayerSponsoredVariant choose({
    required double availableGap,
    required double coverSide,
    Random? random,
  }) {
    final candidates = <PlayerSponsoredVariant>[
      if (availableGap >= glassCardMinGap && coverSide >= 180)
        PlayerSponsoredVariant.glassCard,
      if (availableGap >= compactRowMinGap && coverSide >= 150)
        PlayerSponsoredVariant.compactRow,
      if (availableGap >= cornerCreativeMinGap && coverSide >= 120)
        PlayerSponsoredVariant.cornerCreative,
    ];
    if (candidates.isEmpty) return PlayerSponsoredVariant.cornerCreative;
    // Variety without repetition: never the same layout back-to-back when
    // an alternative fits.
    if (candidates.length > 1 && _lastVariant != null) {
      candidates.remove(_lastVariant);
    }
    final pick = candidates[(random ?? _random).nextInt(candidates.length)];
    _lastVariant = pick;
    return pick;
  }

  /// Test/diagnostics helper.
  @visibleForTesting
  void reset() {
    _lastVariant = null;
  }
}
