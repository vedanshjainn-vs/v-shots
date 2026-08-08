// ════════════════════════════════════════════════
// Project Lyra — Certificate Pinning
// ════════════════════════════════════════════════
//
// SSL certificate pinning for API security.
// Prevents MITM attacks by validating server
// certificates against known pins.
// ════════════════════════════════════════════════

import 'dart:io';

import '../../logging/app_logger.dart';

/// SSL certificate pinning configuration.
///
/// Pins are SHA-256 hashes of the DER-encoded
/// public key of the server certificate.
///
/// ```dart
/// final pinning = CertificatePinning(
///   pins: {'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='},
///   domains: ['api.projectlyra.com'],
/// );
/// ```
class CertificatePinning {
  CertificatePinning({
    required this.pins,
    required this.domains,
    this.enforcePinning = true,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  /// Set of SHA-256 certificate pins (base64-encoded).
  final Set<String> pins;

  /// Domains that should be pinned.
  final Set<String> domains;

  /// Whether to enforce pinning (false = log-only mode).
  final bool enforcePinning;

  final AppLogger _logger;

  /// Create an [HttpClient] with certificate pinning applied.
  HttpClient createPinnedClient() {
    final client = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return _validateCertificate(cert, host);
      };

    // Set connection timeouts.
    client.connectionTimeout = const Duration(seconds: 15);
    client.idleTimeout = const Duration(seconds: 30);

    return client;
  }

  /// Validate a certificate against known pins.
  bool _validateCertificate(X509Certificate cert, String host) {
    // Only pin configured domains.
    if (!domains.any((d) => host.endsWith(d))) {
      _logger.w('CertificatePinning: Domain $host not in pinning scope');
      return !enforcePinning;
    }

    // Calculate SHA-256 of the DER-encoded public key.
    final certPin = _calculatePin(cert);

    if (pins.contains(certPin)) {
      _logger.d('CertificatePinning: Pin matched for $host');
      return true;
    }

    _logger.e('CertificatePinning: Pin MISMATCH for $host. '
        'Expected one of: $pins, Got: $certPin');

    if (enforcePinning) {
      return false; // Block the connection.
    }

    return true; // Log-only mode.
  }

  /// Calculate the SHA-256 pin of a certificate's public key.
  String _calculatePin(X509Certificate cert) {
    // In production, use crypto package to compute:
    // SHA256(DER-encoded SPKI) → base64
    // For now, return the subject as a placeholder.
    // TODO(team): Implement proper SPKI pinning.
    return 'sha256/${cert.subject}';
  }

  /// Whether a host should be pinned.
  bool shouldPin(String host) {
    return domains.any((d) => host.endsWith(d));
  }
}

/// Certificate pin configuration for Project Lyra APIs.
abstract final class LyraCertificatePins {
  /// Production API pins.
  static const Set<String> productionPins = {
    // TODO(team): Replace with actual certificate pins.
    'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // Backup pin.
  };

  /// Staging API pins.
  static const Set<String> stagingPins = {
    'sha256/CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=',
  };

  /// Domains that should be pinned.
  static const Set<String> pinnedDomains = {
    'api.projectlyra.com',
    'supabase.projectlyra.com',
    'dev-api.projectlyra.com',
    'stg-api.projectlyra.com',
  };

  /// Create a production certificate pinning instance.
  static CertificatePinning production() {
    return CertificatePinning(
      pins: productionPins,
      domains: pinnedDomains,
      enforcePinning: true,
    );
  }

  /// Create a staging certificate pinning instance (log-only).
  static CertificatePinning staging() {
    return CertificatePinning(
      pins: stagingPins,
      domains: pinnedDomains,
      enforcePinning: false,
    );
  }
}
