// ═════════════════════════════════════════════════════════════════════════
// V Shots — RecommendationEventService (Phase 10)
//
// Tracks product/recommendation signals (song_play, song_complete, song_like,
// search, vibe_selected, discover_swipe, etc.) WITHOUT collecting unnecessary
// personal data. Events are used ONLY to improve recommendations and product
// decisions. If the user is signed in and Supabase is available, events are
// recorded to recommendation_events (best-effort); otherwise they are dropped
// silently (never blocking the UI).
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../backend/supabase_sync_service.dart';

/// Event type constants (keep in sync with analytics vocabulary).
abstract final class RecommendationEvents {
  static const songImpression = 'song_impression';
  static const songPlay = 'song_play';
  static const songPause = 'song_pause';
  static const songComplete = 'song_complete';
  static const songSkip = 'song_skip';
  static const songLike = 'song_like';
  static const doubleTapLike = 'double_tap_like';
  static const search = 'search';
  static const searchResultClick = 'search_result_click';
  static const artistOpen = 'artist_open';
  static const vibeSelected = 'vibe_selected';
  static const discoverSwipe = 'discover_swipe';
  static const queueAdd = 'queue_add';
  static const queueRemove = 'queue_remove';
  static const miniPlayerOpen = 'mini_player_open';
  static const miniPlayerClose = 'mini_player_close';
}

class RecommendationEventService {
  RecommendationEventService._();
  static final RecommendationEventService instance =
      RecommendationEventService._();

  // Small in-memory buffer to avoid spamming Supabase on rapid events
  // (e.g. swipes). Flushed periodically and on significant events.
  final List<Map<String, dynamic>> _buffer = [];
  Timer? _flushTimer;
  static const int _maxBuffer = 40;
  static const Duration _flushInterval = Duration(seconds: 20);

  /// Records an event. `extra` is a small, non-personal metadata map.
  void track(String eventType,
      {String? videoId, Map<String, dynamic> extra = const {}}) {
    _buffer.add({
      'type': eventType,
      'videoId': videoId,
      'at': DateTime.now().toIso8601String(),
      ...extra,
    });
    debugPrint('[Event] $eventType${videoId != null ? ' ($videoId)' : ''}');

    if (_buffer.length >= _maxBuffer) {
      unawaited(_flush());
    } else {
      _flushTimer ??= Timer(_flushInterval, () => unawaited(_flush()));
    }
  }

  Future<void> _flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_buffer.isEmpty) return;
    final events = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();
    for (final e in events) {
      await SupabaseSyncService.instance.recordEvent(
        (e['type'] as String?) ?? 'unknown',
        videoId: e['videoId'] as String?,
        metadata: {
          for (final k in e.keys)
            if (k != 'type' && k != 'videoId' && k != 'at') k: e[k],
        },
      );
    }
  }
}
