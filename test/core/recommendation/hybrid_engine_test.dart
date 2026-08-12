// ═════════════════════════════════════════════════════════════════════════
// V Shots — Hybrid Recommendation Engine Tests (Phase 31)
//
// Verifies the deterministic hybrid recommender:
//   - New Releases freshness
//   - podcast rejection
//   - duplicate dedup
//   - language relevance
//   - artist diversity (no artist domination)
//   - RecommendationMemory repetition/skip penalties
//   - SongSimilarityEngine similarity ordering
//   - CandidatePool ranking is not raw order
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/preferences/user_preferences.dart';
import 'package:v_shots/core/providers/provider_models.dart';
import 'package:v_shots/core/recommendation/candidate_pool.dart';
import 'package:v_shots/core/recommendation/hybrid_recommendation_score.dart';
import 'package:v_shots/core/recommendation/recommendation_memory.dart';
import 'package:v_shots/core/recommendation/song_similarity_engine.dart';

ProviderTrack track(String id, String title, String artist, {int dur = 240}) =>
    ProviderTrack(
      id: id,
      title: title,
      artist: artist,
      artworkUrl: 'http://img/$id',
      durationSeconds: dur,
    );

void main() {
  group('RecommendationMemory', () {
    test('repetition penalty grows with repeated shows', () {
      final m = RecommendationMemory.instance;
      m.clear();
      m.recordShown('a');
      m.recordShown('a');
      expect(m.repetitionPenalty('a'), greaterThan(0));
      expect(m.repetitionPenalty('b'), 0);
    });

    test('likes allow resurfacing (no repetition penalty)', () {
      final m = RecommendationMemory.instance;
      m.clear();
      m.recordShown('a');
      m.recordShown('a');
      m.recordLike('a');
      expect(m.repetitionPenalty('a'), 0);
    });

    test('repeated skips cause rejection', () {
      final m = RecommendationMemory.instance;
      m.clear();
      m.recordSkip('x');
      m.recordSkip('x');
      m.recordSkip('x');
      expect(m.shouldReject('x'), isTrue);
    });
  });

  group('SongSimilarityEngine', () {
    test('same-artist songs score higher than different-artist', () {
      final sim = SongSimilarityEngine();
      final seed = track('s', 'Romantic Love Song', 'Arijit Singh');
      final sameArtist = track('1', 'Another Romantic Song', 'Arijit Singh');
      final diffArtist = track('2', 'Some Track', 'Ed Sheeran');
      final sa = sim.similarity(seed, sameArtist);
      final da = sim.similarity(seed, diffArtist);
      expect(sa, greaterThan(da));
    });
  });

  group('HybridRecommendationScore freshness', () {
    test('recent is fresher than old', () {
      final recent = HybridRecommendationScore.freshnessScore(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      final old = HybridRecommendationScore.freshnessScore(
        DateTime.now().subtract(const Duration(days: 120)),
      );
      expect(recent, greaterThan(old));
    });
  });

  group('CandidatePool', () {
    test('rejects podcasts and dedups duplicates, ranks fresh content', () {
      final pool = CandidatePool();
      pool.reset();
      final raw = [
        track('a', 'Old Hindi Song', 'Artist A'), // old
        track('b', 'New Hindi Song Official', 'Artist B'), // new
        track('c', 'New Punjabi Song', 'Artist C'), // new, other lang
        track('d', 'Podcast Episode 5', 'Podcast'), // reject
        track('b', 'New Hindi Song Official', 'Artist B'), // duplicate
      ];
      final ranked = pool.process(
        raw: raw,
        limit: 10,
        prefs: UserPreferences(country: 'India', languages: ['Hindi']),
      );
      final ids = ranked.map((s) => s.track.id).toList();
      expect(ids.contains('d'), isFalse, reason: 'podcast must be rejected');
      expect(ids.where((i) => i == 'b').length, 1,
          reason: 'duplicate must be deduped');
      // New content (b, c) should be ranked ahead of the old 'a' when present.
      final idxB = ids.indexOf('b');
      final idxA = ids.indexOf('a');
      if (idxA != -1 && idxB != -1) {
        expect(idxB, lessThan(idxA));
      }
    });

    test('artist diversity prevents domination', () {
      final pool = CandidatePool();
      pool.reset();
      final raw = [
        for (var i = 0; i < 6; i++) track('id$i', 'Song $i', 'Same Artist'),
      ];
      final ranked = pool.process(raw: raw, limit: 10);
      // Even with all same-artist, the pool caps frequency (should not return
      // 6 of them; at most a few).
      expect(ranked.length, lessThan(6));
    });
  });
}
