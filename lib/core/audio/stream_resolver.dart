// ════════════════════════════════════════════════
// V Shots — Shared YouTube stream resolver
// ════════════════════════════════════════════════
//
// WHY THIS FILE EXISTS (read before touching this):
// This exact bug — "getManifest(videoId) called with no explicit
// ytClients, silently using the library default that YouTube's
// PO-Token requirement now 403s on" — has been fixed and then
// accidentally reintroduced in this repo's history at least twice
// already:
//   1. Originally fixed in core/audio/player_controller.dart (an
//      earlier session's work).
//   2. That file was superseded when lib/main.dart was rewritten
//      wholesale ("STABLE: Complete working app with real music"),
//      which reintroduced the same unfixed getManifest() call — but
//      NEW, inline, and copy-pasted across FOUR separate call sites in
//      main.dart (playTrack(), _playAdjacentInQueue()'s background-skip
//      path, and PlayerScreen's _play()) plus TWO more in the newer
//      For You feed (for_you_feed_screen.dart).
// Six copies of the same unfixed bug is exactly what happens when a
// fix lives inline instead of in one shared function. This file is
// that one shared function — every stream resolution in the app must
// call `resolveAudioStreamUrl()` from here, full stop. Do not
// copy-paste a new `_yt.videos.streamsClient.getManifest(...)` call
// anywhere else in this codebase.
// ════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// ── Short-TTL resolved-stream-URL cache (refinement list Section B #4) ──
// WHY A SHORT TTL, NOT A LONG ONE: YouTube's stream URLs are
// token-signed and expire after a few hours on their end regardless of
// what this app does — caching them indefinitely would eventually hand
// back a dead URL. 15 minutes is chosen to cover the very common case
// of "replaying a song you just played moments ago" (previously this
// re-ran the FULL androidVr->ios->android client-fallback resolution
// from scratch every single time, a real 1-3 network-round-trip cost)
// without risking a stale/expired URL for anything beyond a short
// replay window.
class _CachedStream {
  _CachedStream(this.url, this.expiresAt);
  final String url;
  final DateTime expiresAt;
}

final Map<String, _CachedStream> _streamUrlCache = {};
const Duration _streamCacheTtl = Duration(minutes: 15);

/// Resolves a playable audio-only stream URL for [videoId], trying
/// multiple YouTube Innertube clients in priority order. A single
/// client being rate-limited/blocked/requiring a PO-Token (the root
/// cause of the recurring "no audio" bug in this repo) no longer kills
/// playback entirely — this falls through to the next client.
///
/// Returns null if every client attempt fails (caller should show a
/// user-facing error rather than fail silently).
Future<String?> resolveAudioStreamUrl(
  YoutubeExplode yt,
  String videoId, {
  void Function(String message)? log,
}) async {
  void logMsg(String m) => log?.call(m);

  final cached = _streamUrlCache[videoId];
  if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
    logMsg('Using cached stream URL for $videoId (no network round-trip)');
    return cached.url;
  }

  // androidVr and ios are the most reliable clients for audio-only
  // streams without requiring a PO-Token/JS signature solver (see
  // MASTER_BUILD_PROMPT.md Part 0 for the full investigation trail);
  // android is kept as a last-resort fallback.
  final clientAttempts = [
    [YoutubeApiClient.androidVr],
    [YoutubeApiClient.ios],
    [YoutubeApiClient.android],
  ];

  for (final clients in clientAttempts) {
    try {
      logMsg('Attempting manifest fetch with client: $clients');
      final manifest = await yt.videos.streamsClient
          .getManifest(videoId, ytClients: clients)
          .timeout(const Duration(seconds: 12));

      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) {
        logMsg('No audio streams from $clients, trying next client');
        continue;
      }

      // Pick a middle-bitrate stream: highest-bitrate streams are
      // sometimes throttled/blocked more aggressively, and lowest
      // sounds bad — middle is the pragmatic default the app's own
      // prior working code used.
      final sorted = audioStreams.toList()
        ..sort((a, b) => a.bitrate.compareTo(b.bitrate));
      final selected = sorted[(sorted.length / 2).floor()];

      logMsg(
        'Selected stream via $clients: ${selected.bitrate}, '
        '${selected.codec}, ${selected.container}',
      );
      final url = selected.url.toString();
      _streamUrlCache[videoId] =
          _CachedStream(url, DateTime.now().add(_streamCacheTtl));
      return url;
    } catch (e) {
      logMsg('Client $clients failed: $e — trying next client');
      continue;
    }
  }

  logMsg('All client attempts failed for $videoId');
  return null;
}

/// Convenience wrapper that routes through [debugPrint] with a
/// consistent tag, matching the app's existing `_log()` helper style.
Future<String?> resolveAudioStreamUrlLogged(
  YoutubeExplode yt,
  String videoId, {
  String tag = 'StreamResolver',
}) {
  return resolveAudioStreamUrl(
    yt,
    videoId,
    log: (m) => debugPrint('[$tag] $m'),
  );
}
