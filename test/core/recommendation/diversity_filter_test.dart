// ════════════════════════════════════════════════
// V Shots — DiversityFilter tests (Phase 7, Part X)
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/providers/provider_models.dart';
import 'package:v_shots/core/recommendation/diversity_filter.dart';
import 'package:v_shots/core/recommendation/recommendation_config.dart';
import 'package:v_shots/core/recommendation/recommendation_scorer.dart';

ScoredTrack _track(String id, String artist, double score) {
  return ScoredTrack(
    track: ProviderTrack(
      id: id,
      title: 'Title $id',
      artist: artist,
      artworkUrl: '',
      durationSeconds: 180,
    ),
    score: score,
    genreTags: const {},
  );
}

void main() {
  test('does not disturb an already-diverse list', () {
    final filter = DiversityFilter();
    final input = [
      _track('1', 'A', 10),
      _track('2', 'B', 9),
      _track('3', 'C', 8),
    ];
    final result = filter.apply(input);
    expect(result.map((t) => t.track.id).toList(), ['1', '2', '3']);
  });

  test('breaks up more than maxConsecutiveSameArtist in a row', () {
    const config = RecommendationConfig(maxConsecutiveSameArtist: 2);
    final filter = DiversityFilter(config: config);
    // 4 tracks from Artist A (highest scores) then 1 from Artist B.
    final input = [
      _track('1', 'A', 10),
      _track('2', 'A', 9),
      _track('3', 'A', 8),
      _track('4', 'A', 7),
      _track('5', 'B', 6),
    ];
    final result = filter.apply(input);

    // No more than 2 consecutive from the same artist.
    int consecutive = 1;
    for (var i = 1; i < result.length; i++) {
      if (result[i].track.artist == result[i - 1].track.artist) {
        consecutive++;
        expect(consecutive, lessThanOrEqualTo(2));
      } else {
        consecutive = 1;
      }
    }
  });

  test('is deterministic — same input always produces same output', () {
    final filter = DiversityFilter();
    final input = [
      _track('1', 'A', 10),
      _track('2', 'A', 9),
      _track('3', 'A', 8),
      _track('4', 'B', 7),
      _track('5', 'C', 6),
    ];
    final result1 = filter.apply(List.of(input));
    final result2 = filter.apply(List.of(input));
    expect(
      result1.map((t) => t.track.id).toList(),
      result2.map((t) => t.track.id).toList(),
    );
  });

  test('does not drop any tracks — diversity re-orders, never discards', () {
    final filter = DiversityFilter();
    final input = [
      _track('1', 'A', 10),
      _track('2', 'A', 9),
      _track('3', 'A', 8),
      _track('4', 'A', 7),
    ];
    final result = filter.apply(input);
    expect(result.length, input.length);
  });

  test('all-same-artist input is allowed through rather than infinite-looping',
      () {
    final filter = DiversityFilter();
    final input = [
      _track('1', 'OnlyArtist', 10),
      _track('2', 'OnlyArtist', 9),
      _track('3', 'OnlyArtist', 8),
      _track('4', 'OnlyArtist', 7),
      _track('5', 'OnlyArtist', 6),
    ];
    final result = filter.apply(input);
    expect(result.length, 5);
  });

  test('short lists (<= max consecutive) pass through unchanged', () {
    final filter = DiversityFilter();
    final input = [_track('1', 'A', 10), _track('2', 'A', 9)];
    final result = filter.apply(input);
    expect(result, input);
  });
}
