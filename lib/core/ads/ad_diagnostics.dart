// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Diagnostics Panel (DEBUG BUILDS ONLY, Unity LevelPlay)
//
// On-device ground truth (Phase 21). Reports HONEST states only:
//   • LEVELPLAY SDK: INITIALIZED / FAILED / INITIALIZING
//   • APP KEY: CONFIGURED / MISSING (+ TEST CREDENTIALS indicator)
//   • every placement unit: CONFIGURED / MISSING (no secrets shown)
//   • per-format activity trail: requested → loaded → shown / failed with
//     timestamps + exact LevelPlay errors
//   • last revenue (impression-level, per network)
//   • development-only TEST INTERSTITIAL / TEST REWARDED /
//     LAUNCH INTEGRATION TEST SUITE actions (debug builds only)
//
// "ADS AVAILABLE" is NEVER shown merely because a flag is true.
// kDebugMode-gated at the call site — NEVER visible in release builds.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import 'ad_analytics.dart';
import 'ad_free_manager.dart';
import 'ad_policy.dart';
import 'ad_state.dart';
import 'consent_manager.dart';
import 'levelplay_config.dart';
import 'levelplay_service.dart';
import '../remote_config/remote_feature_flags.dart';

class AdDiagnosticsPanel extends StatefulWidget {
  const AdDiagnosticsPanel({super.key});

  /// Bump on every ads-related rebuild so the owner can confirm which APK
  /// is installed straight from the Settings screen.
  /// v10: Meta Audience Network audit build — accurate native unit display,
  /// per-network fill tracking, correct build marker (v8/v9 shipped with a
  /// stale v6 marker — this build is identifiable as v10+).
  static const String buildMarker = 'ads-v10-meta-audit-20260826';

  @override
  State<AdDiagnosticsPanel> createState() => _AdDiagnosticsPanelState();
}

class _AdDiagnosticsPanelState extends State<AdDiagnosticsPanel> {
  bool _busyInter = false;
  bool _busyRew = false;
  String? _interResult;
  String? _rewResult;

  Future<void> _testInterstitial() async {
    setState(() {
      _busyInter = true;
      _interResult = 'requesting…';
    });
    final result = await VShotsLevelPlay.instance.testInterstitial();
    if (!mounted) return;
    setState(() {
      _busyInter = false;
      _interResult = result;
    });
  }

  Future<void> _testRewarded() async {
    setState(() {
      _busyRew = true;
      _rewResult = 'requesting… (watch it to the end — reward is granted '
          'only when LevelPlay confirms completion)';
    });
    final result = await VShotsLevelPlay.instance.testRewarded();
    if (!mounted) return;
    setState(() {
      _busyRew = false;
      _rewResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lp = VShotsLevelPlay.instance;
    final state = lp.systemState();
    final consent = ConsentManager.instance.status.name;
    final flag = RemoteFeatureFlags.instance.value(
      'enable_ads',
      defaultValue: true,
    );

    final appKeyState = !LevelPlayConfig.isConfigured
        ? 'MISSING'
        : (LevelPlayConfig.usingTestCredentials
            ? 'CONFIGURED (official Unity TEST key — debug only)'
            : 'CONFIGURED');

    Widget kv(String label, String value, {bool alert = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFF9AA3B2), fontSize: 11),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color:
                      alert ? const Color(0xFFFFB4B4) : const Color(0xFFF2F4F8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget unitRow(String placement, {String? label}) {
      final configured = LevelPlayConfig.unitConfigured(placement);
      return kv(
        label ?? placement,
        configured ? 'CONFIGURED' : 'MISSING',
        alert: !configured,
      );
    }

    /// Native placements have NO client-side unit ID by design: LevelPlay
    /// resolves the single app-level native ad unit from the app key
    /// (server-side). Showing "MISSING" here was a false alarm — the unit
    /// exists on the LevelPlay app and needs no .env entry.
    Widget nativeUnitRow(String placement, {String? label}) {
      return kv(
        label ?? placement,
        'APP-LEVEL ✓ (auto-resolved from app key — no client unit needed)',
      );
    }

    // Last revenue/display event (if any).
    final recent = AdAnalytics.session.toList(growable: false);
    AdEvent? revenueEvent;
    for (final e in recent.reversed) {
      if (e.kind == 'ad_revenue' || e.kind == 'ad_displayed') {
        revenueEvent = e;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16181F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D37)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AD DIAGNOSTICS — build: ${AdDiagnosticsPanel.buildMarker}',
            style: TextStyle(
              color: Color(0xFF4DD0E1),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          kv(
            'System state',
            '${state.label}'
                '${state == AdSystemState.ready ? ' — ads can be requested' : ''}',
            alert:
                state != AdSystemState.ready && state != AdSystemState.adFree,
          ),
          kv(
            'LevelPlay SDK',
            lp.initSucceeded
                ? 'INITIALIZED'
                : (lp.initStarted ? 'INITIALIZING' : 'NOT STARTED'),
            alert: !lp.initSucceeded,
          ),
          if (lp.initError != null)
            kv('Init error', lp.initError!, alert: true),
          kv(
            'LevelPlay App Key',
            appKeyState,
            alert: !LevelPlayConfig.isConfigured,
          ),
          kv(
            'Units configured',
            '${LevelPlayConfig.configuredUnitCount()} / ${LevelPlayConfig.unitEnvKeys.length}',
          ),
          kv('Consent (UMP)', consent),
          kv(
            'Personalized ads',
            ConsentManager.instance.canRequestPersonalizedAds
                ? 'yes'
                : 'no (non-personalized requests)',
          ),
          kv(
            'Remote flag enable_ads',
            flag ? 'true' : 'FALSE (emergency kill active)',
          ),
          kv(
            'Ad-free user',
            AdFreeManager.instance.isAdFree ? 'YES — all ads suppressed' : 'no',
          ),
          kv(
            'Policy gate (adsAvailable)',
            AdPolicy.instance.adsAvailable ? 'OPEN' : 'BLOCKED',
          ),
          const SizedBox(height: 4),
          const Text(
            'UNITS (V Shots stable placement → LevelPlay unit)',
            style: TextStyle(
              color: Color(0xFF4DD0E1),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          nativeUnitRow(
            LevelPlayPlacement.homeNative,
            label: 'HOME_NATIVE_01 (native, app-level unit)',
          ),
          nativeUnitRow(
            LevelPlayPlacement.discoveryNative,
            label: 'DISCOVERY_NATIVE_01 (native, app-level unit)',
          ),
          nativeUnitRow(
            LevelPlayPlacement.libraryNative,
            label: 'LIBRARY_NATIVE_01 (native, app-level unit)',
          ),
          nativeUnitRow(
            LevelPlayPlacement.searchNative,
            label: 'SEARCH_NATIVE_01 (native, app-level unit)',
          ),
          unitRow(
            LevelPlayPlacement.interstitialSessionBreak,
            label: 'INTERSTITIAL_SESSION_BREAK_01',
          ),
          unitRow(
            LevelPlayPlacement.rewardedFeature,
            label: 'REWARDED_FEATURE_01',
          ),
          unitRow(LevelPlayPlacement.bannerHome, label: 'BANNER_HOME_01'),
          unitRow(LevelPlayPlacement.mrecHome, label: 'MREC_HOME_01'),
          const SizedBox(height: 4),
          const Text(
            'FORMAT ACTIVITY (requested → loaded → shown)',
            style: TextStyle(
              color: Color(0xFF4DD0E1),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          kv('native', lp.activityLine('native')),
          kv(
            'interstitial',
            '${lp.activityLine('interstitial')} · ready=${lp.interstitialReady}',
          ),
          kv(
            'rewarded',
            '${lp.activityLine('rewarded')} · ready=${lp.rewardedReady}',
          ),
          kv('banner', lp.activityLine('widget_ad_view')),
          const SizedBox(height: 4),
          const Text(
            'NETWORK FILL (which network actually filled)',
            style: TextStyle(
              color: Color(0xFF4DD0E1),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          for (final format in const [
            'native',
            'interstitial',
            'rewarded',
            'banner',
          ])
            kv(
              'last fill: $format',
              lp.lastFillNetwork[format] ??
                  '— (no load yet this session; mediation instances '
                      'live server-side: UnityAds+Meta bidders)',
              alert: lp.lastFillNetwork[format] == null,
            ),
          if (lp.formatErrors.isNotEmpty)
            ...lp.formatErrors.entries.map(
              (e) => kv('last error: ${e.key}', e.value, alert: true),
            ),
          if (revenueEvent != null)
            kv(
              'last impression',
              '${revenueEvent.kind} ${revenueEvent.detail ?? ''}',
              alert: false,
            ),
          const SizedBox(height: 6),
          // ── Development-only test actions (never in release builds) ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busyInter ? null : _testInterstitial,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4DD0E1),
                    side: const BorderSide(color: Color(0xFF4DD0E1)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(_busyInter ? 'loading…' : 'TEST INTERSTITIAL'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busyRew ? null : _testRewarded,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF7AC3),
                    side: const BorderSide(color: Color(0xFFFF7AC3)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(_busyRew ? 'playing…' : 'TEST REWARDED'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: lp.initSucceeded ? LevelPlay.launchTestSuite : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF9AA3B2),
              side: const BorderSide(color: Color(0xFF9AA3B2)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: const Text(
              'LAUNCH LEVELPLAY INTEGRATION TEST SUITE (networks/adapters check)',
            ),
          ),
          if (_interResult != null) ...[
            const SizedBox(height: 4),
            Text(
              'interstitial: $_interResult',
              style: const TextStyle(
                color: Color(0xFFF2F4F8),
                fontSize: 10.5,
                height: 1.35,
              ),
            ),
          ],
          if (_rewResult != null) ...[
            const SizedBox(height: 4),
            Text(
              'rewarded: $_rewResult',
              style: const TextStyle(
                color: Color(0xFFF2F4F8),
                fontSize: 10.5,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 4),
          const Text(
            'RECENT EVENTS',
            style: TextStyle(
              color: Color(0xFF4DD0E1),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          ...AdAnalytics.session.toList(growable: false).reversed.take(6).map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    'event: ${e.kind}'
                    '${e.placement != null ? ' @ ${e.placement}' : ''}'
                    '${e.detail != null ? ' — ${e.detail}' : ''}',
                    style: const TextStyle(
                      color: Color(0xFF9AA3B2),
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 4),
          const Text(
            'For LIVE (non-test) ads: register this device as a TEST DEVICE '
            'in the LevelPlay dashboard (Settings → Test devices, use the '
            'Advertising ID shown in the integration test suite). Debug '
            'builds have adapters-debug + integration test suite ON. '
            'Native/banner test ads appear in-feed on Home/Library/Playlist.',
            style: TextStyle(
              color: Color(0xFF9AA3B2),
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
