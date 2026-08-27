// ═════════════════════════════════════════════════════════════════════════
// V Shots — Google UMP Consent Manager
//
// Implements Google's User Messaging Platform consent flow for the EEA/UK.
// Handles gathering consent, exposing the current consent status, building
// personalized/non-personalized ad requests, and consent reset. We do NOT
// bypass consent.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ConsentManager {
  ConsentManager._();

  static final ConsentManager instance = ConsentManager._();

  ConsentStatus _status = ConsentStatus.unknown;
  ConsentStatus get status => _status;

  /// Fired whenever the consent status changes (any source). Registered by
  /// VShotsMax to push the decision into AppLovin MAX (Phase 9) — the UMP
  /// system stays the single consent source of truth.
  VoidCallback? onStatusChanged;

  void _set(ConsentStatus value) {
    if (value == _status) return;
    _status = value;
    onStatusChanged?.call();
  }

  /// @visibleForTesting — replace the live consent status.
  @visibleForTesting
  void debugSetStatus(ConsentStatus value) => _set(value);

  /// Whether personalized ads may be served. True only when the user granted
  /// consent; otherwise requests are sent as non-personalized.
  bool get canRequestPersonalizedAds => _status == ConsentStatus.obtained;

  /// Builds the AdRequest honoring the current consent decision.
  AdRequest buildAdRequest() => AdRequest(
    keywords: const ['music'],
    nonPersonalizedAds: !canRequestPersonalizedAds,
  );

  /// Resets consent (testing / user-initiated privacy options).
  Future<void> reset() async {
    await ConsentInformation.instance.reset();
    _status = await ConsentInformation.instance.getConsentStatus();
    debugPrint('[AdConsent] Reset. Status=$_status');
  }

  /// Requests consent info and, if required, loads + shows the consent form.
  Future<void> initialize() async {
    try {
      final params = ConsentRequestParameters(
        // Use the user's REAL region — no forced EEA debug geography.
        // (The previous forced-EEA + fake test-hash config could leave the
        // status stuck at `required` on non-EEA debug devices, silently
        // blocking EVERY ad placement. To test the EEA flow deliberately,
        // set debugGeography: DebugGeography.debugGeographyEea with your
        // own device hash in testIdentifiers.)
        consentDebugSettings: null,
      );
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          _set(await ConsentInformation.instance.getConsentStatus());
          debugPrint('[AdConsent] Status=$_status');
          // If a decision is still required, show the form automatically.
          if (_status == ConsentStatus.required) {
            await ConsentForm.loadAndShowConsentFormIfRequired((
              FormError? error,
            ) async {
              if (error != null) {
                // Form failed to load: per UMP guidance, proceed with
                // NON-PERSONALIZED ads instead of silently blocking all
                // ads (canRequestPersonalizedAds stays false because
                // status != obtained).
                _set(ConsentStatus.notRequired);
                debugPrint(
                  '[AdConsent] Form error: ${error.message} → non-personalized mode',
                );
                return;
              }
              _set(await ConsentInformation.instance.getConsentStatus());
              debugPrint('[AdConsent] Dismissed. Status=$_status');
            });
          }
        },
        (FormError error) {
          debugPrint('[AdConsent] Info update failed: ${error.message}');
          _set(ConsentStatus.unknown);
        },
      );
    } catch (e) {
      debugPrint('[AdConsent] initialize error: $e');
      _set(ConsentStatus.unknown);
    }
  }
}
