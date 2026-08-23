// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Diagnostics Panel (DEBUG BUILDS ONLY, AppLovin MAX)
//
// On-device ground truth (Phases 2/8/9/12). Reports HONEST states only:
//   • system state (CONFIG_NOT_SET / SDK_INITIALIZING / SDK_NOT_READY /
//     CONSENT_REQUIRED / AD_FREE / DISABLED / READY)
//   • SDK key + every placement unit: CONFIGURED / MISSING (no secrets shown)
//   • per-format activity trail: requested → loaded → shown / failed,
//     with timestamps and exact MAX error codes
//   • recent analytics events (REQUESTED / LOADED / SHOWN / IMPRESSION)
//   • development-only TEST INTERSTITIAL / TEST REWARDED actions (bypass the
//     production frequency rules on purpose; production rules unchanged)
//
// kDebugMode-gated at the call site — NEVER visible in release builds.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import 'ad_analytics.dart';
import 'ad_free_manager.dart';
import 'ad_policy.dart';
import 'ad_service.dart';
import 'ad_state.dart';
import 'consent_manager.dart';
import 'max_config.dart';
import 'max_sdk_service.dart';
import '../remote_config/remote_feature_flags.dart';

class AdDiagnosticsPanel extends StatefulWidget {
  const AdDiagnosticsPanel({super.key});

  /// Bump on every ads-related rebuild so the owner can confirm which APK
  /// is installed straight from the Settings screen.
  static const String buildMarker = 'ads-v5-device-20260823';

  @override
  State<AdDiagnosticsPanel> createState() => _AdDiagnosticsPanelState();
}

class _AdDiagnosticsPanelState extends State<AdDiagnosticsPanel> {
  bool _testingInter = false;
  bool _testingRew = false;
  String? _interResult;
  String? _rewResult;

  Future<void> _testInterstitial() async {
    setState(() {
      _testingInter = true;
      _interResult = 'requesting…';
    });
    final result = await VShotsMax.instance.testInterstitial();
    if (!mounted) return;
    setState(() {
      _testingInter = false;
      _interResult = result;
    });
  }

  Future<void> _testRewarded() async {
    setState(() {
      _testingRew = true;
      _rewResult = 'requesting… (watch it to the end — reward is granted '
          'only when MAX confirms completion)';
    });
    bool rewardConfirmed = false;
    final outcome = await VShotsAds.instance.showRewarded(
      purpose: 'diag_test',
      onRewardGranted: () => rewardConfirmed = true,
    );
    if (!mounted) return;
    setState(() {
      _testingRew = false;
      _rewResult = switch (outcome) {
        RewardOutcome.completed => rewardConfirmed
            ? 'COMPLETED — reward callback fired (MAX-confirmed) ✓'
            : 'COMPLETED (reward callback did not fire — inspect)',
        RewardOutcome.canceled => 'closed without completion — no reward '
            '(correct behaviour)',
        RewardOutcome.failed =>
          'FAILED to load/show — check unit/network/test device in MAX '
              'dashboard (exact error is in the events below)',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final max = VShotsMax.instance;
    final state = max.systemState();
    final consent = ConsentManager.instance.status.name;
    final flag =
        RemoteFeatureFlags.instance.value('enable_ads', defaultValue: true);
    final sdkKeyMasked = MaxConfig.sdkKey == null
        ? 'MISSING'
        : 'CONFIGURED (${MaxConfig.sdkKey!.length} chars)';

    Widget kv(String label, String value, {bool alert = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(label,
                  style:
                      const TextStyle(color: Color(0xFF9AA3B2), fontSize: 11)),
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

    Widget unitRow(String placement) {
      final configured = MaxConfig.unitConfigured(placement);
      return kv(
        placement,
        configured ? 'CONFIGURED' : 'MISSING',
        alert: !configured,
      );
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
          kv('MAX SDK key', sdkKeyMasked, alert: MaxConfig.sdkKey == null),
          kv('MAX session',
              max.initSucceeded ? 'INITIALIZED' : 'NOT INITIALIZED',
              alert: !max.initSucceeded),
          if (max.sdkTestMode != null)
            kv('MAX test mode', max.sdkTestMode! ? 'ON (test ads)' : 'off'),
          kv('Consent (UMP)', consent),
          kv(
              'Personalized ads',
              ConsentManager.instance.canRequestPersonalizedAds
                  ? 'yes'
                  : 'no (non-personalized requests)'),
          kv('Remote flag enable_ads',
              flag ? 'true' : 'FALSE (emergency kill active)'),
          kv(
              'Ad-free user',
              AdFreeManager.instance.isAdFree
                  ? 'YES — all ads suppressed'
                  : 'no'),
          kv('Policy gate (adsAvailable)',
              AdPolicy.instance.adsAvailable ? 'OPEN' : 'BLOCKED'),
          const SizedBox(height: 4),
          const Text('UNITS',
              style: TextStyle(
                  color: Color(0xFF4DD0E1),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
          unitRow(MaxPlacement.homeNative),
          unitRow(MaxPlacement.discoveryNative),
          unitRow(MaxPlacement.playerNative),
          unitRow(MaxPlacement.libraryNative),
          unitRow(MaxPlacement.searchNative),
          unitRow(MaxPlacement.interstitialSessionBreak),
          unitRow(MaxPlacement.rewardedFeature),
          unitRow(MaxPlacement.bannerHome),
          const SizedBox(height: 4),
          const Text('FORMAT ACTIVITY (requested → loaded → shown)',
              style: TextStyle(
                  color: Color(0xFF4DD0E1),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
          kv('native', max.activityLine('native')),
          kv('interstitial',
              '${max.activityLine('interstitial')} · ready=${max.interstitialReady}'),
          kv('rewarded',
              '${max.activityLine('rewarded')} · ready=${max.rewardedReady}'),
          kv('banner', max.activityLine('widget_ad_view')),
          if (max.formatErrors.isNotEmpty)
            ...max.formatErrors.entries.map(
              (e) => kv('last error: ${e.key}', e.value, alert: true),
            ),
          const SizedBox(height: 6),
          // ── Development-only test actions (never in release builds) ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testingInter ? null : _testInterstitial,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4DD0E1),
                    side: const BorderSide(color: Color(0xFF4DD0E1)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                  child: Text(_testingInter ? 'loading…' : 'TEST INTERSTITIAL'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _testingRew ? null : _testRewarded,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF7AC3),
                    side: const BorderSide(color: Color(0xFFFF7AC3)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                  child: Text(_testingRew ? 'playing…' : 'TEST REWARDED'),
                ),
              ),
            ],
          ),
          if (_interResult != null) ...[
            const SizedBox(height: 4),
            Text('interstitial: $_interResult',
                style: const TextStyle(
                    color: Color(0xFFF2F4F8), fontSize: 10.5, height: 1.35)),
          ],
          if (_rewResult != null) ...[
            const SizedBox(height: 4),
            Text('rewarded: $_rewResult',
                style: const TextStyle(
                    color: Color(0xFFF2F4F8), fontSize: 10.5, height: 1.35)),
          ],
          const SizedBox(height: 4),
          const Text('RECENT EVENTS',
              style: TextStyle(
                  color: Color(0xFF4DD0E1),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
          ...AdAnalytics.session.toList(growable: false).reversed.take(6).map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    'event: ${e.kind}'
                    '${e.placement != null ? ' @ ${e.placement}' : ''}'
                    '${e.detail != null ? ' — ${e.detail}' : ''}',
                    style: const TextStyle(
                        color: Color(0xFF9AA3B2), fontSize: 10.5),
                  ),
                ),
              ),
          const SizedBox(height: 4),
          const Text(
            'Test ads require this device to be a registered TEST DEVICE in '
            'the MAX dashboard (the device ID appears in the MAX log once '
            'verbose logging runs). Debug builds have verbose logging + the '
            'creative debugger ON (flip the screen twice on a fullscreen ad).',
            style:
                TextStyle(color: Color(0xFF9AA3B2), fontSize: 10, height: 1.35),
          ),
        ],
      ),
    );
  }
}
