// ════════════════════════════════════════════════
// V Shots — TasteProfileBuilder tests (Phase 7, Part X)
// ════════════════════════════════════════════════
// ignore_for_file: unnecessary_null_checks
//
// Tests artist affinity, genre affinity, skip penalty, and completion
// reward — all against real SignalEvent lists (no shared_preferences
// dependency; TasteProfileBuilder.build() accepts an explicit events
// list for exactly this kind of isolated, deterministic testing).
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/recommendation/recommendation_config.dart';
import 'package:v_shots/core/recommendation/signal_event.dart';
import 'package:v_shots/core/recommendation/taste_profile.dart';

void main() {
  final builder =
      TasteProfileBuilder(config: RecommendationConfig.defaultConfig);

  group('artist affinity', () {
    test('like contributes very strong positive affinity', () {
      final events = [
        SignalEvent(
          type: SignalType.like,
          timestamp: DateTime.now(),
          trackId: 't1',
          artist: 'Arijit Singh',
          title: 'Tum Hi Ho',
        ),
      ];
      final profile = builder.build(events: events);
      expect(profile.artistAffinity['Arijit Singh'], greaterThan(0));
    });

    test('completed track contributes more than a bare play', () {
      final now = DateTime.now();
      final playOnly = builder.build(events: [
        SignalEvent(
            type: SignalType.play, timestamp: now, artist: 'A', trackId: 't1'),
      ]);
      final completed = builder.build(events: [
        SignalEvent(
            type: SignalType.completed,
            timestamp: now,
            artist: 'A',
            trackId: 't1'),
      ]);
      expect(completed.artistAffinity['A']!,
          greaterThan(playOnly.artistAffinity['A']!));
    });

    test('replay contributes strong positive affinity', () {
      final profile = builder.build(events: [
        SignalEvent(
          type: SignalType.replay,
          timestamp: DateTime.now(),
          artist: 'B',
          trackId: 't2',
        ),
      ]);
      expect(profile.artistAffinity['B']!, greaterThanOrEqualTo(4.0));
    });

    test('unlike is a mild negative, not punitive', () {
      final profile = builder.build(events: [
        SignalEvent(
            type: SignalType.unlike,
            timestamp: DateTime.now(),
            artist: 'C',
            trackId: 't3'),
      ]);
      // Should be negative but small in magnitude (not treated like a
      // skip-level penalty).
      expect(profile.artistAffinity['C']!, lessThan(0));
      expect(profile.artistAffinity['C']!, greaterThan(-2.0));
    });

    test('affinity decays with age (recency-weighted)', () {
      final now = DateTime.now();
      final recent = builder.build(events: [
        SignalEvent(
            type: SignalType.completed,
            timestamp: now,
            artist: 'D',
            trackId: 't4'),
      ]);
      final old = builder.build(events: [
        SignalEvent(
          type: SignalType.completed,
          timestamp: now.subtract(const Duration(days: 30)),
          artist: 'D',
          trackId: 't4',
        ),
      ]);
      expect(
          recent.artistAffinity['D']!, greaterThan(old.artistAffinity['D']!));
    });
  });

  group('skip penalty', () {
    test('immediate skip (<10s) produces a real, tracked penalty', () {
      final profile = builder.build(events: [
        SignalEvent(
          type: SignalType.skip,
          timestamp: DateTime.now(),
          artist: 'E',
          trackId: 't5',
          value: 3.0, // 3 seconds listened before skip
        ),
      ]);
      expect(profile.artistSkipPenalty['E']!, greaterThan(0));
    });

    test(
        'late skip (near end of track) produces a smaller penalty than an immediate skip',
        () {
      final now = DateTime.now();
      final immediate = builder.build(events: [
        SignalEvent(
            type: SignalType.skip,
            timestamp: now,
            artist: 'F',
            trackId: 't6',
            value: 2.0),
      ]);
      final late = builder.build(events: [
        SignalEvent(
            type: SignalType.skip,
            timestamp: now,
            artist: 'F',
            trackId: 't6',
            value: 180.0),
      ]);
      expect(immediate.artistSkipPenalty['F']!,
          greaterThan(late.artistSkipPenalty['F']!));
    });

    test('skip penalty decays with age — does not permanently punish an artist',
        () {
      final now = DateTime.now();
      final recentSkip = builder.build(events: [
        SignalEvent(
            type: SignalType.skip,
            timestamp: now,
            artist: 'G',
            trackId: 't7',
            value: 2.0),
      ]);
      final oldSkip = builder.build(events: [
        SignalEvent(
          type: SignalType.skip,
          timestamp: now.subtract(const Duration(days: 10)),
          artist: 'G',
          trackId: 't7',
          value: 2.0,
        ),
      ]);
      expect(recentSkip.artistSkipPenalty['G']!,
          greaterThan(oldSkip.artistSkipPenalty['G']!));
      // Old skip should have decayed toward (but not necessarily to)
      // zero, not stayed at full strength.
      expect(oldSkip.artistSkipPenalty['G']!,
          lessThan(recentSkip.artistSkipPenalty['G']!));
    });

    test('one skip does not appear in artistAffinity — tracked separately', () {
      final profile = builder.build(events: [
        SignalEvent(
            type: SignalType.skip,
            timestamp: DateTime.now(),
            artist: 'H',
            trackId: 't8',
            value: 2.0),
      ]);
      // Skip contributes to artistSkipPenalty, not artistAffinity —
      // this is what lets scoring apply independently-weighted terms.
      expect(profile.artistAffinity.containsKey('H'), isFalse);
      expect(profile.artistSkipPenalty.containsKey('H'), isTrue);
    });
  });

  group('genre affinity', () {
    test('genre tags are derived from title/artist/query text', () {
      final profile = builder.build(events: [
        SignalEvent(
          type: SignalType.completed,
          timestamp: DateTime.now(),
          artist: 'Diljit Dosanjh',
          trackId: 't9',
          title: 'Punjabi Anthem (Official Audio)',
        ),
      ]);
      expect(profile.genreAffinity.containsKey('Punjabi'), isTrue);
    });
  });

  group('cold start', () {
    test('empty signal history produces an empty profile with no crash', () {
      final profile = builder.build(events: []);
      expect(profile, TasteProfile.empty);
      expect(profile.hasEnoughHistoryForPersonalization, isFalse);
    });

    test('fewer than 3 signals is not enough for personalization', () {
      final profile = builder.build(events: [
        SignalEvent(
            type: SignalType.play,
            timestamp: DateTime.now(),
            artist: 'X',
            trackId: 't10'),
        SignalEvent(
            type: SignalType.play,
            timestamp: DateTime.now(),
            artist: 'Y',
            trackId: 't11'),
      ]);
      expect(profile.hasEnoughHistoryForPersonalization, isFalse);
    });
  });

  group('topArtists / topGenres ordering', () {
    test('topArtists is sorted by affinity descending', () {
      final now = DateTime.now();
      final profile = builder.build(events: [
        SignalEvent(
            type: SignalType.play,
            timestamp: now,
            artist: 'Low',
            trackId: 't12'),
        SignalEvent(
            type: SignalType.like,
            timestamp: now,
            artist: 'High',
            trackId: 't13'),
        SignalEvent(
            type: SignalType.like,
            timestamp: now,
            artist: 'High',
            trackId: 't13'),
      ]);
      expect(profile.topArtists.first, 'High');
    });
  });
}
