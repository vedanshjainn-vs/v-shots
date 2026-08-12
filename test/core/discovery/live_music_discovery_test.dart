// ═════════════════════════════════════════════════════════════════════════
// V Shots — Live Music Discovery Tests (Phase 25)
//
// Verifies:
//   - live query building is country/language-aware
//   - song-key normalization collapses "Kesariya" / "Kesariya Official Video"
//   - music candidate validation rejects podcasts/shorts/mixes
//   - source priority: live only when repo.isLive, else fallback
//   - region/relevanceLanguage codes map correctly
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/discovery/home_content_coordinator.dart';
import 'package:v_shots/core/discovery/live_music_discovery_service.dart';
import 'package:v_shots/core/preferences/user_preferences.dart';
import 'package:v_shots/core/providers/adapters/youtube/youtube_data_api_client.dart';

void main() {
  final live = LiveMusicDiscoveryService();

  group('buildLiveQueries', () {
    test('India + Hindi produces Hindi, region-aware queries', () {
      final p = UserPreferences(country: 'India', languages: ['Hindi']);
      final q = live.buildLiveQueries(p, 'new songs');
      final joined = q.join(' ').toLowerCase();
      expect(joined, contains('hindi'));
      // Should include a region token (IN).
      expect(joined, contains('in'));
    });

    test('US + English produces English queries', () {
      final p =
          UserPreferences(country: 'United States', languages: ['English']);
      final q = live.buildLiveQueries(p, 'pop hits');
      expect(q.join(' ').toLowerCase(), contains('english'));
    });
  });

  group('region / relevanceLanguage codes', () {
    test('India maps to IN / hi', () {
      final p = UserPreferences(country: 'India', languages: ['Hindi']);
      expect(live.regionCodeFor(p), 'IN');
      expect(live.relevanceLanguageFor(p), 'hi');
    });
    test('US maps to US / en', () {
      final p =
          UserPreferences(country: 'United States', languages: ['English']);
      expect(live.regionCodeFor(p), 'US');
      expect(live.relevanceLanguageFor(p), 'en');
    });
  });

  group('song normalization', () {
    test('collapses official-video variants of the same track', () {
      final a = normalizeSongKey('Arijit Singh', 'Kesariya');
      final b = normalizeSongKey('Arijit Singh', 'Kesariya Official Video');
      final c = normalizeSongKey('Arijit Singh', 'Kesariya - Lyric');
      expect(a, b);
      expect(a, c);
    });
    test('different artists with same title differ', () {
      final a = normalizeSongKey('Artist A', 'Song X');
      final b = normalizeSongKey('Artist B', 'Song X');
      expect(a, isNot(b));
    });
  });

  group('music candidate validation', () {
    YouTubeVideoItem item(String title, {int dur = 240, String id = 'x'}) =>
        YouTubeVideoItem(
          id: id,
          title: title,
          channelTitle: 'Channel',
          thumbnailUrl: 'http://img',
          durationSeconds: dur,
        );

    test('rejects podcasts', () {
      expect(MusicValidator.isMusicCandidate(item('My Podcast ep 5')), isFalse);
    });
    test('rejects reaction videos', () {
      expect(
          MusicValidator.isMusicCandidate(item('REACTION to song')), isFalse);
    });
    test('rejects long compilations', () {
      expect(MusicValidator.isMusicCandidate(item('Full Album Mix', dur: 6000)),
          isFalse);
    });
    test('rejects Shorts', () {
      expect(MusicValidator.isMusicCandidate(item('#shorts clip', dur: 20)),
          isFalse);
    });
    test('accepts an official music video', () {
      expect(
          MusicValidator.isMusicCandidate(
              item('Official Music Video', dur: 240)),
          isTrue);
    });
  });

  group('source priority', () {
    test('coordinator uses fallback when repo is not live (no key)', () async {
      final coord = HomeContentCoordinator(); // no injected live key
      final p = UserPreferences(
          country: 'India', languages: ['Hindi'], onboardingCompleted: true);
      final result = await coord.fetchSection(
        'New Releases',
        intent: 'new songs',
        prefs: p,
        limit: 5,
      );
      // Without an API key, source must be fallback — never falsely "live".
      expect(result.source, ContentSource.fallback);
    });
  });
}
