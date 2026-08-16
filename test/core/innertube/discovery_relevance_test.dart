// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Discovery relevance filter tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/innertube/discovery_relevance.dart';

Map<String, dynamic> _t(String id, String title, String artist) =>
    {'id': id, 'title': title, 'artist': artist};

void main() {
  group('isIrrelevantContent', () {
    test('rejects gaming / news / sports / podcast / tutorial', () {
      expect(
          isIrrelevantContent('My PUBG Gameplay Highlights', 'GamerX'), isTrue);
      expect(isIrrelevantContent('Daily News Update', 'News24'), isTrue);
      expect(
          isIrrelevantContent('Cricket Match Highlights', 'SportsTV'), isTrue);
      expect(isIrrelevantContent('The Daily Podcast ep 9', 'Host'), isTrue);
      expect(isIrrelevantContent('How to make a beat (FL Tutorial)', 'Tutor'),
          isTrue);
    });

    test('rejects reactions / vlogs / explanations', () {
      expect(isIrrelevantContent('Reacting to Top Songs', 'Reactor'), isTrue);
      expect(isIrrelevantContent('My Daily Vlog #412', 'Vlogger'), isTrue);
      expect(
          isIrrelevantContent('Movie Ending Explained', 'ExplainIt'), isTrue);
    });

    test('accepts real music titles', () {
      expect(isIrrelevantContent('Tum Hi Ho (Official Video)', 'Arijit Singh'),
          isFalse);
      expect(isIrrelevantContent('Lo-Fi Beats', 'Chill Channel'), isFalse);
    });
  });

  group('filterRelevantTracks', () {
    test('drops irrelevant items and keeps music', () {
      final tracks = [
        _t('a', 'Romantic Hindi Song', 'T-Series'),
        _t('b', 'PUBG Gameplay', 'Gamer'),
        _t('c', 'Sad Song', 'Sony Music'),
      ];
      final result = filterRelevantTracks(tracks);
      expect(result.map((t) => t['id']).toList(), ['a', 'c']);
    });

    test('relaxed fallback: returns original when filter empties the batch',
        () {
      final tracks = [_t('x', 'PUBG Gameplay', 'Gamer')];
      final result = filterRelevantTracks(tracks);
      expect(result, tracks, reason: 'never leave Discovery empty');
    });

    test('empty input stays empty', () {
      expect(filterRelevantTracks(const []), isEmpty);
    });
  });
}
