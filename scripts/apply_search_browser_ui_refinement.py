from pathlib import Path

ROOT = Path('.')


def try_patch(path: str, old: str, new: str, label: str) -> None:
    p = ROOT / path
    text = p.read_text()
    if new in text:
        print(f'{label}: already applied')
        return
    if old not in text:
        print(f'{label}: anchor not present; skipped safely')
        return
    p.write_text(text.replace(old, new, 1))
    print(f'{label}: applied')


def patch_main() -> None:
    path = 'lib/main.dart'
    try_patch(path, "import 'core/recommendation/recommendation_engine.dart';\n", "import 'core/recommendation/feed_intent.dart';\nimport 'core/recommendation/recommendation_engine.dart';\n", 'FeedIntent import')
    try_patch(path, """// ═══════════════════════════════════════════════

class SearchScreen extends StatefulWidget {""", """// ═══════════════════════════════════════════════

/// Stable relevance ranking for global search. Home/Discovery policy remains
/// separate; search simply prefers exact matches and official music.
List<Map<String, dynamic>> _rankVShotsSearchResults(String query, List<Map<String, dynamic>> input) {
  String n(Object? v) => (v?.toString() ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim().replaceAll(RegExp(r'\\s+'), ' ');
  final q = n(query);
  final ranked = input.asMap().entries.map((e) {
    final t = e.value;
    final title = n(t['title']);
    final artist = n(t['artist']);
    var score = 0;
    if (q.isNotEmpty && title == q) score += 120;
    if (q.isNotEmpty && artist == q) score += 110;
    if (q.isNotEmpty && title.startsWith(q)) score += 70;
    if (q.isNotEmpty && title.contains(q)) score += 45;
    if (q.isNotEmpty && artist.contains(q)) score += 40;
    if (t['isOfficial'] == true) score += 30;
    if (t['channelVerified'] == true || t['isVerified'] == true) score += 8;
    return (score: score, index: e.key, track: t);
  }).toList();
  ranked.sort((a, b) => b.score != a.score ? b.score.compareTo(a.score) : a.index.compareTo(b.index));
  return ranked.map((e) => e.track).toList();
}

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
    final seen = <String>{seedId, ...VShotsPlaybackManager.instance.queue.map((t) => t['id']?.toString() ?? '')};
    for (final item in scored) {
      final track = item.track.toTrackMap();
      final id = track['id']?.toString() ?? '';
      if (id.isEmpty || !seen.add(id) || track['isOfficial'] != true) continue;
      VShotsPlaybackManager.instance.addToEnd(track);
    }
    currentQueue = VShotsPlaybackManager.instance.queue;
    queueVersionNotifier.value++;
  } catch (e) {
    debugPrint('[VShots] More Like This generation failed: $e');
  }
}

bool currentQueueIsMoreLikeThis = false;

class SearchScreen extends StatefulWidget {""", 'Search + More Like This helper')
    try_patch(path, """      final toShow = musicResults.isNotEmpty
          ? musicResults
          : (merged.isNotEmpty ? merged : uniqueResults);""", """      final toShow = _rankVShotsSearchResults(
        query,
        musicResults.isNotEmpty
            ? musicResults
            : (merged.isNotEmpty ? merged : uniqueResults),
      );""", 'Search ranking')
    try_patch(path, """  VShotsPlaybackManager.instance.playQueue(
    resolvedQueue.isEmpty ? [resolvedTrack] : resolvedQueue,
    safeIndex,
    expanded: expanded,
  );""", """  currentQueueIsMoreLikeThis = resolvedQueue.length <= 1;
  VShotsPlaybackManager.instance.playQueue(
    resolvedQueue.isEmpty ? [resolvedTrack] : resolvedQueue,
    safeIndex,
    expanded: expanded,
  );
  if (currentQueueIsMoreLikeThis) {
    unawaited(_populateMoreLikeThis(resolvedTrack));
  }""", 'More Like This queue')
    try_patch(path, """  VShotsPlaybackManager.instance.addToEnd(track);
  currentQueue = VShotsPlaybackManager.instance.queue;""", """  currentQueueIsMoreLikeThis = false;
  VShotsPlaybackManager.instance.addToEnd(track);
  currentQueue = VShotsPlaybackManager.instance.queue;""", 'Queue add state')
    try_patch(path, """  VShotsPlaybackManager.instance.playNext(track);
  currentQueue = VShotsPlaybackManager.instance.queue;""", """  currentQueueIsMoreLikeThis = false;
  VShotsPlaybackManager.instance.playNext(track);
  currentQueue = VShotsPlaybackManager.instance.queue;""", 'Play-next state')
    try_patch(path, """                    'Up Next',""", """                    currentQueueIsMoreLikeThis
                        ? 'More Like This'
                        : 'Up Next',""", 'Player heading')


def patch_browser() -> None:
    path = 'android/app/src/main/kotlin/com/vshots/live/VShotsBrowserPlatformView.kt'
    try_patch(path, '''            override fun onPageFinished(view: WebView?, url: String?) {
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
''', 'Browser player hook')
    try_patch(path, '''    fun load(url: String) {
        if (!url.startsWith("https://")) return
''', '''    /** Keep only the real YouTube player visible; V Shots owns everything below it. */
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
                    Array.prototype.forEach.call(parent.children,function(child){if(child!==node)child.style.setProperty('display','none','important');});
                    parent.style.setProperty('margin','0','important');
                    parent.style.setProperty('padding','0','important');
                    parent.style.setProperty('width','100%','important');
                    parent.style.setProperty('max-width','none','important');
                    node=parent;
                    if(parent===document.body)break;
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
                  window.__vshotsPlayerOnlyObserver=new MutationObserver(function(){clearTimeout(window.__vshotsPlayerOnlyTimer);window.__vshotsPlayerOnlyTimer=setTimeout(isolate,120);});
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
''', 'Browser player isolation')


if __name__ == '__main__':
    patch_main()
    patch_browser()
    print('Search/browser refinement patch completed.')
