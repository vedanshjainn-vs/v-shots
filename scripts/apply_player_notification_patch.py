from pathlib import Path

ROOT = Path('.')


def patch(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'player notification anchor not found: {path}')
    p.write_text(text.replace(old, new, 1))


def patch_main_audio_service() -> None:
    path = 'lib/main.dart'
    patch(
        path,
        """      androidNotificationClickStartsActivity: true,
    ),""",
        """      androidNotificationClickStartsActivity: true,
      preloadArtwork: true,
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
    ),""",
    )


def patch_search_and_more_like_this() -> None:
    path = 'lib/main.dart'

    patch(
        path,
        "import 'core/recommendation/music_recommendation_engine.dart';\n",
        "import 'core/recommendation/feed_intent.dart';\nimport 'core/recommendation/music_recommendation_engine.dart';\n",
    )

    patch(
        path,
        """// ═══════════════════════════════════════════════

class SearchScreen extends StatefulWidget {""",
        """// ═══════════════════════════════════════════════

/// Search relevance is intentionally separate from recommendation generation.
/// Exact title/artist matches and provider-confirmed official music are ranked
/// above loose text matches, while global search remains broader than the
/// Home/Discovery official-only recommendation surfaces.
List<Map<String, dynamic>> _rankVShotsSearchResults(
  String query,
  List<Map<String, dynamic>> input,
) {
  String normalize(Object? value) =>
      (value?.toString() ?? '')
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim()
          .replaceAll(RegExp(r'\\s+'), ' ');

  final q = normalize(query);
  final ranked = input.asMap().entries.map((entry) {
    final track = entry.value;
    final title = normalize(track['title']);
    final artist = normalize(track['artist']);
    var score = 0;

    if (q.isNotEmpty && title == q) score += 120;
    if (q.isNotEmpty && artist == q) score += 110;
    if (q.isNotEmpty && title.startsWith(q)) score += 70;
    if (q.isNotEmpty && title.contains(q)) score += 45;
    if (q.isNotEmpty && artist.contains(q)) score += 40;
    if (track['isOfficial'] == true) score += 30;
    if (track['channelVerified'] == true || track['isVerified'] == true) {
      score += 8;
    }

    final tokens = q.split(' ').where((t) => t.length > 1).toSet();
    if (tokens.isNotEmpty) {
      final combined = '$title $artist';
      score += tokens.where(combined.contains).length * 6;
    }

    // Stable tie-breaker: preserve provider ordering instead of making
    // equally relevant results jump around between requests.
    return (score: score, index: entry.key, track: track);
  }).toList();

  ranked.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });
  return ranked.map((e) => e.track).toList();
}

/// Search playback starts with ONLY the selected result. This asynchronously
/// replaces the old "remaining search results" queue with recommendations
/// generated from the selected song's artist/genre/language/mood context.
Future<void> _populateMoreLikeThis(Map<String, dynamic> seedTrack) async {
  final seedId = seedTrack['id']?.toString() ?? '';
  if (seedId.isEmpty) return;

  try {
    final scored = await recommendationEngine.generateFeed(
      intent: FeedIntent.moreLikeThis,
      excludeIds: {seedId},
      seedTrackId: seedId,
      count: 12,
      forceRefresh: true,
    );
    if (currentTrack?['id']?.toString() != seedId) return;

    final existingIds = <String>{seedId};
    for (final existing in VShotsPlaybackManager.instance.queue) {
      final id = existing['id']?.toString() ?? '';
      if (id.isNotEmpty) existingIds.add(id);
    }

    for (final scoredTrack in scored) {
      final track = scoredTrack.track.toTrackMap();
      final id = track['id']?.toString() ?? '';
      if (id.isEmpty || !existingIds.add(id)) continue;
      if (track['isOfficial'] != true) continue;
      VShotsPlaybackManager.instance.addToEnd(track);
    }

    currentQueue = VShotsPlaybackManager.instance.queue;
    queueVersionNotifier.value++;
  } catch (e) {
    debugPrint('[VShots] More Like This generation failed: $e');
  }
}

bool currentQueueIsMoreLikeThis = false;

class SearchScreen extends StatefulWidget {""",
    )

    patch(
        path,
        """      final toShow = musicResults.isNotEmpty
          ? musicResults
          : (merged.isNotEmpty ? merged : uniqueResults);""",
        """      final toShow = _rankVShotsSearchResults(
        query,
        musicResults.isNotEmpty
            ? musicResults
            : (merged.isNotEmpty ? merged : uniqueResults),
      );""",
    )

    patch(
        path,
        """  VShotsPlaybackManager.instance.playQueue(
    resolvedQueue.isEmpty ? [resolvedTrack] : resolvedQueue,
    safeIndex,
    expanded: expanded,
  );""",
        """  currentQueueIsMoreLikeThis = resolvedQueue.length <= 1;
  VShotsPlaybackManager.instance.playQueue(
    resolvedQueue.isEmpty ? [resolvedTrack] : resolvedQueue,
    safeIndex,
    expanded: expanded,
  );
  if (currentQueueIsMoreLikeThis) {
    unawaited(_populateMoreLikeThis(resolvedTrack));
  }""",
    )

    patch(
        path,
        """  VShotsPlaybackManager.instance.addToEnd(track);
  currentQueue = VShotsPlaybackManager.instance.queue;""",
        """  currentQueueIsMoreLikeThis = false;
  VShotsPlaybackManager.instance.addToEnd(track);
  currentQueue = VShotsPlaybackManager.instance.queue;""",
    )

    patch(
        path,
        """  VShotsPlaybackManager.instance.playNext(track);
  currentQueue = VShotsPlaybackManager.instance.queue;""",
        """  currentQueueIsMoreLikeThis = false;
  VShotsPlaybackManager.instance.playNext(track);
  currentQueue = VShotsPlaybackManager.instance.queue;""",
    )

    patch(
        path,
        """                    'Up Next',""",
        """                    currentQueueIsMoreLikeThis
                        ? 'More Like This'
                        : 'Up Next',""",
    )
}


def patch_native_browser() -> None:
    path = 'android/app/src/main/kotlin/com/vshots/live/VShotsBrowserPlatformView.kt'
    patch(path, '    init {\n        setBackgroundColor(Color.BLACK)\n', '    init {\n        VShotsBrowserPlaybackService.eventChannel = events\n        setBackgroundColor(Color.BLACK)\n')

    patch(path, '''            override fun onPageFinished(view: WebView?, url: String?) {
                events.invokeMethod("pageFinished", null)
                startPlaybackPolling()
                attemptAutoplayWithAudio()
            }
''', '''            override fun onPageFinished(view: WebView?, url: String?) {
                events.invokeMethod("pageFinished", null)
                isolateYoutubePlayerUi()
                startPlaybackPolling()
                attemptAutoplayWithAudio()
            }
''')

    patch(path, '''    fun load(url: String) {
        if (!url.startsWith("https://")) return
''', '''    /**
     * Keep only the real YouTube player surface visible inside the native
     * browser. The video element and its native YouTube controls remain intact;
     * page-level metadata, comments, subscribe, recommendations and other
     * webpage chrome are hidden so V Shots can own the player UI below it.
     */
    private fun isolateYoutubePlayerUi() {
        evaluateJavascript(
            """
            (function(){
              try {
                var host = (location.hostname || '').toLowerCase();
                if (host.indexOf('youtube.com') < 0 && host.indexOf('youtu.be') < 0) return;
                function isolate(){
                  var player = document.querySelector('#movie_player, .html5-video-player');
                  if (!player) return;
                  var node = player;
                  for (var depth = 0; depth < 12 && node && node.parentElement; depth++) {
                    var parent = node.parentElement;
                    Array.prototype.forEach.call(parent.children, function(child){
                      if (child !== node) child.style.setProperty('display','none','important');
                    });
                    parent.style.setProperty('margin','0','important');
                    parent.style.setProperty('padding','0','important');
                    parent.style.setProperty('max-width','none','important');
                    parent.style.setProperty('width','100%','important');
                    node = parent;
                    if (parent === document.body) break;
                  }
                  document.documentElement.style.setProperty('margin','0','important');
                  document.documentElement.style.setProperty('padding','0','important');
                  document.body.style.setProperty('margin','0','important');
                  document.body.style.setProperty('padding','0','important');
                  document.body.style.setProperty('background','#000','important');
                  player.style.setProperty('width','100%','important');
                  player.style.setProperty('max-width','100vw','important');
                }
                isolate();
                if (!window.__vshotsPlayerOnlyObserver && document.body) {
                  window.__vshotsPlayerOnlyObserver = new MutationObserver(function(){
                    clearTimeout(window.__vshotsPlayerOnlyTimer);
                    window.__vshotsPlayerOnlyTimer = setTimeout(isolate, 120);
                  });
                  window.__vshotsPlayerOnlyObserver.observe(document.body, {childList:true, subtree:true});
                }
              } catch(e) {}
            })()
            """.trimIndent(),
            null,
        )
    }

    fun load(url: String) {
        if (!url.startsWith("https://")) return
''')

    patch(path, '''    fun setMediaPlaying(value: Boolean) {
        if (mediaPlaying == value) return
        mediaPlaying = value
        if (value) {
            startPlaybackForegroundService()
        } else {
            stopPlaybackForegroundService()
        }
        events.invokeMethod("playbackState", value)
    }
''', '''    fun setMediaPlaying(value: Boolean) {
        if (mediaPlaying == value) {
            updatePlaybackNotification(value)
            return
        }
        mediaPlaying = value
        startPlaybackForegroundService(playing = value)
        events.invokeMethod("playbackState", value)
    }

    fun updateNotification(title: String, artist: String, artwork: String, playing: Boolean) {
        startPlaybackForegroundService(title = title, artist = artist, artwork = artwork, playing = playing)
    }
''')

    patch(path, '''    private fun startPlaybackForegroundService() {
        val intent = Intent(appContext, VShotsBrowserPlaybackService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                appContext.startForegroundService(intent)
            } else {
                appContext.startService(intent)
            }
        } catch (_: Exception) {
            // FGS startup is a hardening layer and must never crash Discovery.
        }
    }
''', '''    private fun startPlaybackForegroundService(
        title: String? = null,
        artist: String? = null,
        artwork: String? = null,
        playing: Boolean = mediaPlaying,
    ) {
        val intent = Intent(appContext, VShotsBrowserPlaybackService::class.java).apply {
            action = VShotsBrowserPlaybackService.ACTION_UPDATE
            putExtra("title", title ?: "V Shots")
            putExtra("artist", artist ?: "Music playback")
            putExtra("artwork", artwork ?: "")
            putExtra("playing", playing)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                appContext.startForegroundService(intent)
            } else {
                appContext.startService(intent)
            }
        } catch (_: Exception) {
            // FGS startup is a hardening layer and must never crash Discovery.
        }
    }

    private fun updatePlaybackNotification(playing: Boolean) {
        startPlaybackForegroundService(playing = playing)
    }
''')

    patch(path, '''    fun disposeMedia() {
        stopPlaybackPolling()
        setMediaPlaying(false)
        stopLoading()
        loadUrl("about:blank")
    }
''', '''    fun disposeMedia() {
        stopPlaybackPolling()
        stopPlaybackForegroundService()
        if (VShotsBrowserPlaybackService.eventChannel === events) {
            VShotsBrowserPlaybackService.eventChannel = null
        }
        mediaPlaying = false
        stopLoading()
        loadUrl("about:blank")
    }
''')

    patch(path, '''                "setAdAssist" -> {
                    webView.setAdAssist((call.arguments as? Boolean) ?: true)
                    result.success(null)
                }
''', '''                "setAdAssist" -> {
                    webView.setAdAssist((call.arguments as? Boolean) ?: true)
                    result.success(null)
                }
                "updateNotification" -> {
                    val args = call.arguments as? Map<*, *>
                    val title = args?.get("title")?.toString() ?: "V Shots"
                    val artist = args?.get("artist")?.toString() ?: "Music playback"
                    val artwork = args?.get("artwork")?.toString() ?: ""
                    val playing = args?.get("playing") as? Boolean ?: true
                    webView.updateNotification(title, artist, artwork, playing)
                    result.success(null)
                }
''')


def patch_session() -> None:
    path = 'lib/features/foryou/vshots_browser_session.dart'
    p = ROOT / path
    text = p.read_text()
    if 'onNotificationAction' not in text:
        text = text.replace('    this.onAdState,\n', '    this.onAdState,\n    this.onNotificationAction,\n', 1)
        text = text.replace('  final void Function(bool adActive)? onAdState;\n', '''  final void Function(bool adActive)? onAdState;

  /// Android notification/lock-screen media actions are routed back through
  /// the single global playback manager.
  final Future<void> Function(String action)? onNotificationAction;
''', 1)
    if "case 'notificationAction':" not in text:
        text = text.replace("      case 'adState':\n        onAdState?.call(call.arguments == true);\n        break;\n", '''      case 'adState':
        onAdState?.call(call.arguments == true);
        break;
      case 'notificationAction':
        final action = call.arguments?.toString() ?? '';
        if (action.isNotEmpty) {
          await onNotificationAction?.call(action);
        }
        break;
''', 1)
    if 'Future<void> updateNotification({' not in text:
        text = text.replace('  Future<void> _autoplayPass() async {\n', '''  Future<void> updateNotification({
    required String title,
    required String artist,
    required String artwork,
    required bool playing,
  }) async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('updateNotification', {
        'title': title,
        'artist': artist,
        'artwork': artwork,
        'playing': playing,
      });
    } catch (_) {}
  }

  Future<void> _autoplayPass() async {
''', 1)
    p.write_text(text)


def patch_sheet() -> None:
    path = 'lib/features/foryou/discovery_browser_sheet.dart'
    p = ROOT / path
    text = p.read_text()
    if "import 'dart:async';" not in text:
        text = "import 'dart:async';\n\n" + text
    if 'onNotificationAction:' not in text:
        text = text.replace('      onAdState: (on) => widget.controller.setAdActive(on),\n', '''      onAdState: (on) => widget.controller.setAdActive(on),
      onNotificationAction: (action) async {
        switch (action) {
          case 'toggle':
            await _togglePagePlayback();
            break;
          case 'next':
            VShotsPlaybackManager.instance.next();
            break;
          case 'previous':
            VShotsPlaybackManager.instance.previous();
            break;
          case 'stop':
            _close();
            break;
        }
      },
''', 1)
    if "_session.updateNotification(" not in text:
        text = text.replace('    widget.controller.setError(null);\n    await _session.load(url);\n', '''    widget.controller.setError(null);
    unawaited(
      _session.updateNotification(
        title: widget.controller.title ?? 'V Shots',
        artist: widget.controller.artist ?? 'Music playback',
        artwork: widget.controller.artwork ?? '',
        playing: true,
      ),
    );
    await _session.load(url);
''', 1)
    p.write_text(text)


if __name__ == '__main__':
    patch_main_audio_service()
    patch_search_and_more_like_this()
    patch_native_browser()
    patch_session()
    patch_sheet()
    print('Interactive player/search/browser patch applied.')
