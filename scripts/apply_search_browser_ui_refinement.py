from pathlib import Path

ROOT = Path('.')


def patch(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'refinement anchor not found: {path}')
    p.write_text(text.replace(old, new, 1))


def patch_main() -> None:
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

/// Search relevance stays separate from recommendation generation. Exact
/// title/artist matches and provider-confirmed official music rank above loose
/// text matches while global search remains broader than Home/Discovery.
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
    return (score: score, index: entry.key, track: track);
  }).toList();
  ranked.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });
  return ranked.map((e) => e.track).toList();
}

/// A search tap starts with only the selected result. Recommendations are
/// fetched separately from the search pool and appended after the seed.
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
    for (final item in VShotsPlaybackManager.instance.queue) {
      final id = item['id']?.toString() ?? '';
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


def patch_browser() -> None:
    path = 'android/app/src/main/kotlin/com/vshots/live/VShotsBrowserPlatformView.kt'
    patch(
        path,
        '''            override fun onPageFinished(view: WebView?, url: String?) {
                events.invokeMethod("pageFinished", null)
                startPlaybackPolling()
                attemptAutoplayWithAudio()
            }
''',
        '''            override fun onPageFinished(view: WebView?, url: String?) {
                events.invokeMethod("pageFinished", null)
                isolateYoutubePlayerUi()
                startPlaybackPolling()
                attemptAutoplayWithAudio()
            }
''',
    )
    patch(
        path,
        '''    fun load(url: String) {
        if (!url.startsWith("https://")) return
''',
        '''    /** Keep only the actual YouTube video/player surface visible. */
    private fun isolateYoutubePlayerUi() {
        evaluateJavascript(
            """
            (function(){
              try {
                var host=(location.hostname||'').toLowerCase();
                if(host.indexOf('youtube.com')<0 && host.indexOf('youtu.be')<0) return;
                function isolate(){
                  var player=document.querySelector('#movie_player,.html5-video-player');
                  if(!player) return;
                  var node=player;
                  for(var depth=0;depth<12 && node && node.parentElement;depth++){
                    var parent=node.parentElement;
                    Array.prototype.forEach.call(parent.children,function(child){
                      if(child!==node) child.style.setProperty('display','none','important');
                    });
                    parent.style.setProperty('margin','0','important');
                    parent.style.setProperty('padding','0','important');
                    parent.style.setProperty('width','100%','important');
                    parent.style.setProperty('max-width','none','important');
                    node=parent;
                    if(parent===document.body) break;
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
                if(!window.__vshotsPlayerOnlyObserver && document.body){
                  window.__vshotsPlayerOnlyObserver=new MutationObserver(function(){
                    clearTimeout(window.__vshotsPlayerOnlyTimer);
                    window.__vshotsPlayerOnlyTimer=setTimeout(isolate,120);
                  });
                  window.__vshotsPlayerOnlyObserver.observe(document.body,{childList:true,subtree:true});
                }
              }catch(e){}
            })()
            """.trimIndent(),
            null,
        )
    }

    fun load(url: String) {
        if (!url.startsWith("https://")) return
''',
    )


if __name__ == '__main__':
    patch_main()
    patch_browser()
    print('Search and browser UI refinement patch applied.')
