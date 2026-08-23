// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Diagnostics Panel (DEBUG BUILDS ONLY)
//
// Shown in Settings → Ads & Rewards. Lets the owner see, on-device,
// EXACTLY which ad gate is failing and which build is installed:
//
//   • Build marker  — proves which APK is running
//   • Master switch — adsEnabled (test-mode / injected IDs)
//   • Consent       — UMP status
//   • Remote flag   — enable_ads emergency switch
//   • Ad-free       — premium / rewarded pass
//   • SDK init      — MobileAds adapter states (Play Services errors show here)
//   • Recent events — last ad analytics events (loads, failures + reasons)
//
// kDebugMode-gated at the call site — NEVER visible in release builds.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../remote_config/remote_feature_flags.dart';
import 'ad_analytics.dart';
import 'ad_config.dart';
import 'ad_free_manager.dart';
import 'ad_manager.dart';
import 'ad_policy.dart';
import 'consent_manager.dart';

class AdDiagnosticsPanel extends StatelessWidget {
  const AdDiagnosticsPanel({super.key});

  /// Bump on every ads-related rebuild so the owner can confirm which APK
  /// is installed straight from the Settings screen.
  static const String buildMarker = 'ads-v3-20260823';

  @override
  Widget build(BuildContext context) {
    final policy = AdPolicy.instance;
    final init = AdManager.instance.initStatus;
    final String sdkLine;
    if (init == null) {
      sdkLine = AdManager.instance.isInitialized
          ? 'SDK init: not needed (ads disabled at startup)'
          : 'SDK init: not run yet';
    } else {
      final entries = init.adapterStatuses.entries.toList();
      sdkLine = entries.isEmpty
          ? 'SDK init: no adapters reported'
          : entries
              .map((e) => '${e.key} = ${e.value.state.name}'
                  '${e.value.description.isNotEmpty ? ' — ${e.value.description}' : ''}')
              .join(' | ');
    }
    final recent = AdAnalytics.session.toList(growable: false);
    final recentLines = recent.isEmpty
        ? <String>['events: (none yet — no ad attempted)']
        : recent.reversed
            .take(4)
            .map((e) =>
                'event: ${e.kind}${e.placement != null ? ' @ ${e.placement}' : ''}'
                '${e.detail != null ? ' — ${e.detail}' : ''}')
            .toList(growable: false);

    Widget kv(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 132, child: Text(label, style: _labelStyle)),
            Expanded(child: Text(value, style: _valueStyle)),
          ],
        ),
      );
    }

    return AdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AD DIAGNOSTICS — build: $buildMarker',
            style: TextStyle(
              color: AdPanelColors.accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          kv('Master (adsEnabled)', AdConfig.adsEnabled ? 'ON' : 'OFF'),
          kv(
            'Ad mode',
            AdConfig.isTestMode
                ? 'TEST (Google test IDs)'
                : (AdConfig.adsEnabled ? 'PROD (injected IDs)' : 'n/a'),
          ),
          kv('Consent (UMP)', ConsentManager.instance.status.name),
          kv(
            'Remote flag enable_ads',
            RemoteFeatureFlags.instance.value('enable_ads', defaultValue: true)
                ? 'true'
                : 'FALSE (emergency kill active)',
          ),
          kv(
            'Ad-free user',
            AdFreeManager.instance.isAdFree ? 'YES — all ads suppressed' : 'no',
          ),
          kv(
            'Policy result',
            policy.adsAvailable
                ? 'ADS AVAILABLE — should show at placements'
                : 'BLOCKED — check the lines above for which gate',
          ),
          const SizedBox(height: 3),
          ...recentLines.map(
            (l) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(l, style: _detailStyle),
            ),
          ),
          const SizedBox(height: 3),
          Text(sdkLine, style: _detailStyle),
        ],
      ),
    );
  }
}

const TextStyle _labelStyle = TextStyle(color: Color(0xFF9AA3B2), fontSize: 11);
const TextStyle _valueStyle = TextStyle(
  color: Color(0xFFF2F4F8),
  fontSize: 11,
  fontWeight: FontWeight.w600,
);
const TextStyle _detailStyle =
    TextStyle(color: Color(0xFF9AA3B2), fontSize: 10.5);

// Small local shims so this file imports no theme (keeps the ads module
// self-contained; the panel is debug-only and visually neutral).
class AdCard extends StatelessWidget {
  const AdCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdPanelColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdPanelColors.border),
      ),
      child: child,
    );
  }
}

abstract class AdPanelColors {
  static const Color card = Color(0xFF16181F);
  static const Color border = Color(0xFF2A2D37);
  static const Color accent = Color(0xFF4DD0E1);
}
