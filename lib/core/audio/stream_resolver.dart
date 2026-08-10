// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Shared YouTube Stream Resolver
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class _CachedStream {
  _CachedStream(this.url, this.expiresAt);
  final String url;
  final DateTime expiresAt;
}

final Map<String, _CachedStream> _streamUrlCache = {};
const Duration _streamCacheTtl = Duration(minutes: 15);

/// Resolves a playable audio stream URL for [videoId] with multi-client fallback.
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

  final clientAttempts = [
    [YoutubeApiClient.androidVr],
    [YoutubeApiClient.ios],
    [YoutubeApiClient.android],
    <YoutubeApiClient>[],
  ];

  for (final clients in clientAttempts) {
    try {
      logMsg('Attempting manifest fetch with client: $clients');
      final manifest = await yt.videos.streamsClient
          .getManifest(videoId, ytClients: clients.isEmpty ? null : clients)
          .timeout(const Duration(seconds: 10));

      final audioStreams = manifest.audioOnly;
      if (audioStreams.isNotEmpty) {
        // Pick best playable audio stream (highest bitrate or mp4/webm audio)
        final bestStream = audioStreams.withHighestBitrate();
        final url = bestStream.url.toString();
        logMsg(
          'Selected stream via $clients: ${bestStream.bitrate}, '
          '${bestStream.codec}, ${bestStream.container}',
        );
        _streamUrlCache[videoId] = _CachedStream(
          url,
          DateTime.now().add(_streamCacheTtl),
        );
        return url;
      }

      final muxedStreams = manifest.muxed;
      if (muxedStreams.isNotEmpty) {
        final bestMuxed = muxedStreams.withHighestBitrate();
        final url = bestMuxed.url.toString();
        logMsg('Selected muxed stream fallback: ${bestMuxed.bitrate}');
        _streamUrlCache[videoId] = _CachedStream(
          url,
          DateTime.now().add(_streamCacheTtl),
        );
        return url;
      }
    } catch (e) {
      logMsg('Client $clients failed: $e — trying next client');
      continue;
    }
  }

  logMsg('All client attempts failed for $videoId');
  return null;
}

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
