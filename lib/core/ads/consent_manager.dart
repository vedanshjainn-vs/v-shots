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

  /// @visibleForTesting — replace the live consent status.
  @visibleForTesting
  void debugSetStatus(ConsentStatus value) => _status = value;

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
        consentDebugSettings: kDebugMode
            ? ConsentDebugSettings(
                debugGeography: DebugGeography.debugGeographyEea,
                testIdentifiers: const ['TEST-DEVICE-HASH'],
              )
            : null,
      );
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          _status = await ConsentInformation.instance.getConsentStatus();
          debugPrint('[AdConsent] Status=$_status');
          // If a decision is still required, show the form automatically.
          if (_status == ConsentStatus.required) {
            await ConsentForm.loadAndShowConsentFormIfRequired((
              FormError? _,
            ) async {
              _status = await ConsentInformation.instance.getConsentStatus();
              debugPrint('[AdConsent] Dismissed. Status=$_status');
            });
          }
        },
        (FormError error) {
          debugPrint('[AdConsent] Info update failed: ${error.message}');
          _status = ConsentStatus.unknown;
        },
      );
    } catch (e) {
      debugPrint('[AdConsent] initialize error: $e');
      _status = ConsentStatus.unknown;
    }
  }
}
