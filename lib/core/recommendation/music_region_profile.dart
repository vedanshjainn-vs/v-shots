import 'dart:ui' show PlatformDispatcher;

/// Lightweight, permission-free regional context for music discovery.
///
/// We intentionally use the device locale rather than GPS: country-level
/// personalization does not need location permission, and the user can still
/// override it through the existing Explore filters.
class MusicRegionProfile {
  const MusicRegionProfile({
    required this.countryCode,
    required this.countryName,
    required this.primaryQueries,
  });

  final String countryCode;
  final String countryName;
  final List<String> primaryQueries;

  static MusicRegionProfile current() {
    final locale = PlatformDispatcher.instance.locale;
    final code = (locale.countryCode ?? '').trim().toUpperCase();
    return _forCountry(code.isEmpty ? 'US' : code);
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
