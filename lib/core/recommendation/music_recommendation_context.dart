// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music recommendation context (mode + filters + state)
// ═════════════════════════════════════════════════════════════════════════════

import 'music_seen_store.dart';
import 'music_session_state.dart';

class MusicRecommendationContext {
  MusicRecommendationContext({
    required this.mode,
    this.languages = const [],
    this.moods = const [],
    this.regions = const [],
    this.count = 12,
    this.excludeIds = const {},
    MusicSeenStore? seenStore,
    MusicSessionState? session,
  })  : seenStore = seenStore ?? MusicSeenStore(),
        session = session ?? MusicSessionState();

  /// 'for_you' | 'trending' | 'new' | 'viral' | 'popular' | 'latest'.
  final String mode;

  final List<String> languages;
  final List<String> moods;
  final List<String> regions;
  final int count;
  final Set<String> excludeIds;
  final MusicSeenStore seenStore;
  final MusicSessionState session;
}
