// ════════════════════════════════════════════════
// Project Lyra — Environment Configuration
// ════════════════════════════════════════════════
//
// Holds all environment-specific values for a
// given flavor. Loaded at startup from .env files.
// ════════════════════════════════════════════════

import 'flavors.dart';

/// Environment-specific configuration.
///
/// Each flavor has its own [EnvConfig] instance
/// populated from the corresponding `.env` file.
class EnvConfig {
  const EnvConfig({
    required this.flavor,
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.adMobAppId,
    required this.adMobBannerId,
    required this.adMobInterstitialId,
    required this.adMobRewardedId,
    this.enableLogging = true,
    this.enableAnalytics = false,
    this.enableCrashlytics = false,
  });

  final Flavor flavor;
  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String adMobAppId;
  final String adMobBannerId;
  final String adMobInterstitialId;
  final String adMobRewardedId;
  final bool enableLogging;
  final bool enableAnalytics;
  final bool enableCrashlytics;

  // ── Flavor Configs ───────────────────────────

  static const development = EnvConfig(
    flavor: Flavor.development,
    apiBaseUrl: 'https://jzxtxqjheggyoqwohqjg.supabase.co',
    supabaseUrl: 'https://jzxtxqjheggyoqwohqjg.supabase.co',
    supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6eHR4cWpoZWdneW9xd29ocWpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxODM4OTcsImV4cCI6MjEwMTc1OTg5N30.fD6pKQ4VRG-AoF-nLdpU9iMK1qWz4N-diqMUOJESVw8',
    adMobAppId: 'ca-app-pub-3940256099942544~3347511713',
    adMobBannerId: 'ca-app-pub-3940256099942544/6300978111',
    adMobInterstitialId: 'ca-app-pub-3940256099942544/1033173712',
    adMobRewardedId: 'ca-app-pub-3940256099942544/5224354917',
    enableLogging: true,
    enableAnalytics: false,
    enableCrashlytics: false,
  );

  static const staging = EnvConfig(
    flavor: Flavor.staging,
    apiBaseUrl: 'https://jzxtxqjheggyoqwohqjg.supabase.co',
    supabaseUrl: 'https://jzxtxqjheggyoqwohqjg.supabase.co',
    supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6eHR4cWpoZWdneW9xd29ocWpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxODM4OTcsImV4cCI6MjEwMTc1OTg5N30.fD6pKQ4VRG-AoF-nLdpU9iMK1qWz4N-diqMUOJESVw8',
    adMobAppId: 'ca-app-pub-3940256099942544~3347511713',
    adMobBannerId: 'ca-app-pub-3940256099942544/6300978111',
    adMobInterstitialId: 'ca-app-pub-3940256099942544/1033173712',
    adMobRewardedId: 'ca-app-pub-3940256099942544/5224354917',
    enableLogging: true,
    enableAnalytics: true,
    enableCrashlytics: false,
  );

  static const production = EnvConfig(
    flavor: Flavor.production,
    apiBaseUrl: 'https://jzxtxqjheggyoqwohqjg.supabase.co',
    supabaseUrl: 'https://jzxtxqjheggyoqwohqjg.supabase.co',
    supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6eHR4cWpoZWdneW9xd29ocWpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxODM4OTcsImV4cCI6MjEwMTc1OTg5N30.fD6pKQ4VRG-AoF-nLdpU9iMK1qWz4N-diqMUOJESVw8',
    adMobAppId: 'ca-app-pub-3940256099942544~3347511713',
    adMobBannerId: 'ca-app-pub-3940256099942544/6300978111',
    adMobInterstitialId: 'ca-app-pub-3940256099942544/1033173712',
    adMobRewardedId: 'ca-app-pub-3940256099942544/5224354917',
    enableLogging: false,
    enableAnalytics: true,
    enableCrashlytics: true,
  );
}
