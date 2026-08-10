// ════════════════════════════════════════════════
// V Shots — GenreClassifier tests (Phase 7, Part X)
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/recommendation/genre_classifier.dart';

void main() {
  final classifier = GenreClassifier.instance;

  test('classifies genre from title text', () {
    final tags =
        classifier.classify(title: 'Bollywood Romantic Hit', artist: 'Someone');
    expect(tags, contains('Bollywood'));
  });

  test('classifies genre from the source query when title/artist give no hint',
      () {
    final tags = classifier.classify(
      title: 'Some Random Video Title',
      artist: 'Some Channel',
      sourceQuery: 'punjabi hit songs official audio',
    );
    expect(tags, contains('Punjabi'));
  });

  test('returns an empty set for genuinely unclassifiable text', () {
    final tags = classifier.classify(title: 'xyz123', artist: 'abc456');
    expect(tags, isEmpty);
  });

  test('can return multiple overlapping tags', () {
    final tags = classifier.classify(
      title: 'Romantic Lofi Chill Mix',
      artist: 'Someone',
    );
    expect(tags.length, greaterThanOrEqualTo(2));
  });

  group('similarity (Jaccard)', () {
    test('identical tag sets have similarity 1.0', () {
      final a = {'Bollywood', 'Romantic'};
      expect(classifier.similarity(a, a), 1.0);
    });

    test('disjoint tag sets have similarity 0.0', () {
      expect(classifier.similarity({'Bollywood'}, {'EDM'}), 0.0);
    });

    test('partial overlap is between 0 and 1', () {
      final sim = classifier
          .similarity({'Bollywood', 'Romantic'}, {'Bollywood', 'Sad'});
      expect(sim, greaterThan(0.0));
      expect(sim, lessThan(1.0));
    });

    test('empty sets have similarity 0.0 (not a divide-by-zero crash)', () {
      expect(classifier.similarity({}, {'Bollywood'}), 0.0);
      expect(classifier.similarity({}, {}), 0.0);
    });
  });
}
