// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Diagnostics Panel (DEBUG BUILDS ONLY, AppLovin MAX)
//
// Shown in Settings → Ads & Rewards. Reports HONEST states (Phase 10):
// "READY" only when the MAX SDK is genuinely initialized and serving is
// allowed; otherwise the exact blocking state (CONFIG_NOT_SET,
// SDK_NOT_READY, CONSENT_REQUIRED, AD_FREE, DISABLED, ...) with the last
// error and per-format readiness. Never claims "available" when the SDK
// cannot serve.
//
// kDebugMode-gated at the call site — NEVER visible in release builds.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import 'ad_analytics.dart';
import 'ad_free_manager.dart';
import 'ad_policy.dart';
import 'ad_state.dart';
import 'consent_manager.dart';
import 'max_config.dart';
import 'max_sdk_service.dart';
import '../remote_config/remote_feature_flags.dart';

class AdDiagnosticsPanel extends StatelessWidget {
  const AdDiagnosticsPanel({super.key});

  /// Bump on every ads-related rebuild so the owner can confirm which APK
  /// is installed straight from the Settings screen.
  static const String buildMarker = 'ads-v4-max-20260823';

  @override
  Widget build(BuildContext context) {
    final max = VShotsMax.instance;
    final state = max.systemState();
    final consent = ConsentManager.instance.status.name;
    final flag =
        RemoteFeatureFlags.instance.value('enable_ads', defaultValue: true);
    final unitCount = MaxConfig.configuredUnitCount();
    final sdkKeyMasked = MaxConfig.sdkKey == null
        ? 'not set'
        : 'set (${MaxConfig.sdkKey!.length} chars)';

    final recent = AdAnalytics.session.toList(growable: false);
    final recentLines = recent.isEmpty
        ? <String>['events: (none yet — no ad attempted)']
        : recent.reversed
            .take(4)
            .map((e) =>
                'event: ${e.kind}${e.placement != null ? ' @ ${e.placement}' : ''}'
                '${e.detail != null ? ' — ${e.detail}' : ''}')
            .toList(growable: false);

    Widget kv(String label, String value, {bool alert = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 148, child: Text(label, style: _labelStyle)),
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
            'AD DIAGNOSTICS — build: $buildMarker',
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
          kv('MAX SDK key', sdkKeyMasked),
          kv('MAX unit IDs',
              '$unitCount / ${MaxConfig.unitEnvKeys.length} configured'),
          kv(
            'MAX SDK init',
            max.initError != null
                ? 'FAILED — ${max.initError}'
                : (max.initSucceeded
                    ? 'initialized (testMode=${max.sdkTestMode})'
                    : (max.initStarted ? 'initializing…' : 'not started')),
            alert: max.initError != null,
          ),
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
          kv('Interstitial ready',
              max.interstitialReady ? 'YES (preloaded)' : 'no'),
          kv('Rewarded ready', max.rewardedReady ? 'YES (preloaded)' : 'no'),
          if (max.formatErrors.isNotEmpty)
            ...max.formatErrors.entries.map(
              (e) => kv('Last error: ${e.key}', e.value, alert: true),
            ),
          const SizedBox(height: 3),
          ...recentLines.map(
            (l) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(l, style: _detailStyle),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Debug: verbose logging + creative debugger ON '
            '(flip the screen twice on a fullscreen ad to open the debugger)',
            style: _detailStyle,
          ),
        ],
      ),
    );
  }
}

const TextStyle _labelStyle = TextStyle(color: Color(0xFF9AA3B2), fontSize: 11);
const TextStyle _detailStyle =
    TextStyle(color: Color(0xFF9AA3B2), fontSize: 10.5);
