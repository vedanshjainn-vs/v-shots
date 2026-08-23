// ═════════════════════════════════════════════════════════════════════════
// V Shots — Honest Ad System States (Phase 10)
//
// "ADS AVAILABLE" must mean the system can genuinely serve — not merely
// adsEnabled=true. Diagnostics report these states verbatim.
// ═════════════════════════════════════════════════════════════════════════

enum AdSystemState {
  /// Master gate off (remote enable_ads=false kill switch, etc.).
  disabled('DISABLED'),

  /// This build has no MAX SDK key / unit IDs configured.
  maxNotConfigured('CONFIG_NOT_SET'),

  /// MAX SDK initialization in flight.
  maxInitializing('SDK_INITIALIZING'),

  /// MAX SDK initialization failed (details in VShotsMax.initError).
  maxNotReady('SDK_NOT_READY'),

  /// UMP consent decision still pending.
  consentPending('CONSENT_REQUIRED'),

  /// User is ad-free (premium / rewarded pass) — intentionally no ads.
  adFree('AD_FREE'),

  /// SDK initialized, consent settled, config present — ads can be requested.
  ready('READY'),

  /// System ready but the specific format failed to load / no fill.
  adLoadFailed('AD_LOAD_FAILED'),

  /// System ready, format requested but no ad available (no fill).
  noFill('NO_FILL');

  const AdSystemState(this.label);

  /// User-facing label shown in the diagnostics panel.
  final String label;
}
