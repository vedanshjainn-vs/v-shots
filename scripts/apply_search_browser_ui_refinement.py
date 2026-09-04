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


if __name__ == '__main__':
    patch_main()
    # Native browser/WebView DOM and layout are intentionally left untouched.
    # This is a playback-critical PlatformView; search changes must not
    # resize, hide, or mutate the real YouTube player.
    print('Search refinement applied; native browser playback left untouched.')
