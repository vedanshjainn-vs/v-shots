// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Robust Stream Resolver (Multi-Client + Cache + Retry)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class _CachedStream {
  _CachedStream(this.url, this.expiresAt);
  final String url;
  final DateTime expiresAt;
}

final Map<String, _CachedStream> _streamUrlCache = {};
// 4-hour TTL for YouTube tokenized stream URLs
const Duration _streamCacheTtl = Duration(hours: 4);

/// Resolves a playable audio stream URL for [videoId] with multi-client fallback and retry.
Future<String?> resolveAudioStreamUrl(
  YoutubeExplode yt,
  String videoId, {
  void Function(String message)? log,
}) async {
  void logMsg(String m) => log?.call(m);

  // Check in-memory cache first
  final cached = _streamUrlCache[videoId];
  if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
    logMsg('Using cached stream URL for $videoId (instant resolution)');
    return cached.url;
  }

  // Priority clients for reliable audio without PO-Token requirement
  final clientAttempts = [
    [YoutubeApiClient.androidVr],
    [YoutubeApiClient.ios],
    [YoutubeApiClient.android],
    <YoutubeApiClient>[],
  ];

  for (final clients in clientAttempts) {
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        logMsg(
          'Attempting manifest fetch with client: $clients (attempt $attempt)',
        );
        final manifest = await yt.videos.streamsClient
            .getManifest(videoId, ytClients: clients.isEmpty ? null : clients)
            .timeout(const Duration(seconds: 8));

        final audioStreams = manifest.audioOnly;
        if (audioStreams.isNotEmpty) {
          final bestStream = audioStreams.withHighestBitrate();
          final url = bestStream.url.toString();
          logMsg(
            'Resolved stream via $clients: ${bestStream.bitrate}, '
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
          logMsg('Resolved muxed stream fallback: ${bestMuxed.bitrate}');
          _streamUrlCache[videoId] = _CachedStream(
            url,
            DateTime.now().add(_streamCacheTtl),
          );
          return url;
        }
      } catch (e) {
        logMsg('Client $clients (attempt $attempt) failed: $e');
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
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
