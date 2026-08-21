// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music diversity rolling-window tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/music/music_candidate.dart';
import 'package:v_shots/core/music/music_diversity.dart';
import 'package:v_shots/core/providers/provider_models.dart';

ProviderTrack _track(String id, String artist, String genre) => ProviderTrack(
  id: id,
  title: 'T $id',
  artist: artist,
  artworkUrl: '',
  durationSeconds: 200,
);

ScoredMusicCandidate _c(String id, String artist, String genre, double score) =>
    ScoredMusicCandidate(
      candidate: MusicCandidate(
        track: _track(id, artist, genre),
        songId: 'song-$id',
        source: 'trending',
        artist: artist,
        genre: genre,
        language: '',
        album: '',
      ),
      score: score,
    );

void main() {
  const diversity = MusicDiversity();

  test('caps one artist within the rolling window', () {
    final candidates = [
      _c('1', 'A', 'Pop', 10),
      _c('2', 'A', 'Pop', 9),
      _c('3', 'A', 'Pop', 8),
      _c('4', 'A', 'Pop', 7),
      _c('5', 'B', 'Rock', 6),
      _c('6', 'B', 'Rock', 5),
      _c('7', 'C', 'Jazz', 4),
    ];
    final result = diversity.diversify(candidates);

    // Rolling 5 window must never contain more than 2 of the same artist.
    for (var i = 0; i + 5 <= result.length; i++) {
      final window = result.sublist(i, i + 5);
      final counts = <String, int>{};
      for (final s in window) {
        counts[s.candidate.artist] = (counts[s.candidate.artist] ?? 0) + 1;
      }
      for (final entry in counts.entries) {
        expect(
          entry.value,
          lessThanOrEqualTo(2),
          reason: 'artist ${entry.key} repeats too much in window $i',
        );
      }
    }
  });

  test('never drops content — same set of ids out', () {
    final candidates = [
      _c('1', 'A', 'Pop', 10),
      _c('2', 'A', 'Pop', 9),
      _c('3', 'B', 'Rock', 8),
      _c('4', 'C', 'Jazz', 7),
    ];
    final result = diversity.diversify(candidates);
    expect(
      result.map((s) => s.candidate.track.id).toSet(),
      candidates.map((s) => s.candidate.track.id).toSet(),
    );
  });
}
