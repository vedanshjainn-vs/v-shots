import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight regional context for music discovery.
///
/// Device locale is only the immediate fallback. On startup we resolve the
/// public network country so a phone whose UI locale is `en-US` but is
/// physically/network-connected in India does not get labelled as United
/// States. No GPS permission is requested and no precise location is stored.
class MusicRegionProfile {
  const MusicRegionProfile({
    required this.countryCode,
    required this.countryName,
    required this.primaryQueries,
  });

  final String countryCode;
  final String countryName;
  final List<String> primaryQueries;

  static const String _storedCountryKey = 'vshots.music_region.country.v2';
  static String? _resolvedCountryCode;
  static bool _initializing = false;
  static bool _initialized = false;
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Starts a short, best-effort public-IP country lookup. It never blocks
  /// app startup and falls back to the device locale if the lookup fails.
  static Future<void> initialize() async {
    if (_initialized || _initializing) return;
    _initializing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = _normalizeCountry(prefs.getString(_storedCountryKey));
      if (cached != null) {
        _resolvedCountryCode = cached;
        revision.value++;
      }

      try {
        final response = await http
            .get(
              Uri.parse('https://ipapi.co/country/'),
              headers: const {'Accept': 'text/plain'},
            )
            .timeout(const Duration(seconds: 3));
        final networkCode = _normalizeCountry(response.body);
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            networkCode != null &&
            networkCode != _resolvedCountryCode) {
          _resolvedCountryCode = networkCode;
          await prefs.setString(_storedCountryKey, networkCode);
          revision.value++;
        }
      } catch (_) {
        // Locale/cached region remains the safe fallback.
      }
    } catch (_) {
      // Region is enrichment only; recommendation generation must never fail.
    } finally {
      _initialized = true;
      _initializing = false;
    }
  }

  static MusicRegionProfile current() {
    final code = _resolvedCountryCode ?? _localeCountryCode();
    return _forCountry(code);
  }

  static String _localeCountryCode() {
    final locale = PlatformDispatcher.instance.locale;
    final code = _normalizeCountry(locale.countryCode);
    // India is the app's cold-start fallback rather than United States. This
    // avoids the previous misleading "Personalized for United States" label
    // on devices using an English/US UI locale without a country override.
    return code ?? 'IN';
  }

  static String? _normalizeCountry(String? value) {
    final code = value?.trim().toUpperCase();
    if (code == null || !RegExp(r'^[A-Z]{2}$').hasMatch(code)) return null;
    return code;
  }

  static MusicRegionProfile _forCountry(String code) {
    switch (code) {
      case 'IN':
        return const MusicRegionProfile(
          countryCode: 'IN',
          countryName: 'India',
          primaryQueries: <String>[
            'Hindi Bollywood songs official audio',
            'Hindi songs official music video',
            'Indian trending songs official',
          ],
        );
      case 'US':
        return const MusicRegionProfile(
          countryCode: 'US',
          countryName: 'United States',
          primaryQueries: <String>[
            'US trending songs official',
            'English pop songs official audio',
            'American music hits official',
          ],
        );
      case 'GB':
        return const MusicRegionProfile(
          countryCode: 'GB',
          countryName: 'United Kingdom',
          primaryQueries: <String>[
            'UK trending songs official',
            'British pop songs official audio',
            'UK music hits official',
          ],
        );
      case 'CA':
        return const MusicRegionProfile(
          countryCode: 'CA',
          countryName: 'Canada',
          primaryQueries: <String>[
            'Canada trending songs official',
            'Canadian pop songs official audio',
          ],
        );
      case 'AU':
        return const MusicRegionProfile(
          countryCode: 'AU',
          countryName: 'Australia',
          primaryQueries: <String>[
            'Australia trending songs official',
            'Australian pop songs official audio',
          ],
        );
      case 'AE':
        return const MusicRegionProfile(
          countryCode: 'AE',
          countryName: 'United Arab Emirates',
          primaryQueries: <String>[
            'UAE trending songs official',
            'Arabic English hits official audio',
            'South Asian songs UAE official',
          ],
        );
      case 'SA':
        return const MusicRegionProfile(
          countryCode: 'SA',
          countryName: 'Saudi Arabia',
          primaryQueries: <String>[
            'Saudi Arabia trending songs official',
            'Arabic hits official audio',
          ],
        );
      default:
        return MusicRegionProfile(
          countryCode: code,
          countryName: code,
          primaryQueries: <String>[
            '$code trending songs official',
            'popular songs official audio',
          ],
        );
    }
  }
}
