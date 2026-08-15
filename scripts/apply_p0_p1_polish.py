from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = root / 'lib' / 'main.dart'
text = main.read_text()

imports = [
    "import 'features/polish/archive_style_screens.dart';",
    "import 'features/polish/browser_player_overlay.dart';",
    "import 'features/polish/premium_discovery_screen.dart';",
]
anchor = "import 'features/shots/upload_shot_screen.dart';\n"
for line in imports:
    if line not in text:
        text = text.replace(anchor, anchor + line + "\n")

old_tabs = '''children: const [
                HomeScreen(),
                ForYouFeedScreen(),
                SearchScreen(),
                ProfileScreen(),
              ],'''
new_tabs = '''children: [
                ArchiveStyleHomeScreen(
                  onPlay: (context, track, queue, index) =>
                      playTrack(context, track, queue, index),
                ),
                PremiumDiscoveryScreen(
                  onPlay: (context, track, queue, index) =>
                      playTrack(context, track, queue, index),
                ),
                ArchiveStyleSearchScreen(
                  onPlay: (context, track, queue, index) =>
                      playTrack(context, track, queue, index),
                ),
                const ProfileScreen(),
              ],'''
if new_tabs not in text:
    if old_tabs not in text:
        raise SystemExit('MainShell tab block not found in either old or new form')
    text = text.replace(old_tabs, new_tabs, 1)

old_overlay = '''                    // The Discover feed is a full-screen immersive surface
                    // that renders the single global IFrame itself, so the
                    // persistent overlay (mini/full player) is hidden while
                    // the Discover tab is active to avoid two `YoutubePlayer`
                    // widgets sharing the same controller.
                    if (_index == 1) return const SizedBox.shrink();
                    return _PersistentPlayerOverlay(
                      track: track,
                      isExpanded: isExpanded,
                      onToggleExpand: (val) {
                        isPlayerExpandedNotifier.value = val;
                      },
                    );'''
new_overlay = '''                    return BrowserPlayerOverlay(
                      track: track,
                      expanded: isExpanded,
                      onToggleExpand: (val) {
                        isPlayerExpandedNotifier.value = val;
                      },
                      onTrackEnded: () => _handleTrackCompleted(context),
                    );'''
if new_overlay not in text:
    if old_overlay not in text:
        raise SystemExit('Persistent overlay block not found in either old or new form')
    text = text.replace(old_overlay, new_overlay, 1)

old_init = '''    currentTabIndexNotifier.value = 0;
    audioPlayer.playerStateStream.listen((state) {'''
new_init = '''    currentTabIndexNotifier.value = 0;
    isPlayerExpandedNotifier.value = false;
    currentTrackNotifier.value = null;
    audioPlayer.playerStateStream.listen((state) {'''
if new_init not in text:
    if old_init not in text:
        raise SystemExit('MainShell init anchor not found in either old or new form')
    text = text.replace(old_init, new_init, 1)

old_play = '''  final videoId = (track['id'] as String?) ?? 'kJQP7kiw5Fk';
  // Play through the single global YouTube engine (stops/replaces the previous
  // video; does not create a second playback engine).
  ensureGlobalPlayer(videoId: videoId, autoPlay: true);
  globalPlaybackStateNotifier.value = true;

  isPlayerExpandedNotifier.value = true;'''
new_play = '''  // BrowserPlayerOverlay is the single playback surface. It stays mounted
  // above the IndexedStack and loads this track into the same WebView instance.
  globalPlaybackStateNotifier.value = true;

  // A tap selects a track and starts it in the persistent mini-player.
  isPlayerExpandedNotifier.value = false;'''
if new_play not in text:
    if old_play not in text:
        raise SystemExit('playTrack player block not found in either old or new form')
    text = text.replace(old_play, new_play, 1)

text = text.replace("import 'features/foryou/for_you_feed_screen.dart';\n", '')
main.write_text(text)

# Remove unused/malformed standalone ArchiveTune reference files if present.
for filename in ('archive_tune_home_screen.dart', 'archive_tune_discovery_screen.dart'):
    path = root / filename
    if path.exists():
        path.unlink()

# Analyzer hygiene for the new ArchiveTune-inspired screens.
home = root / 'lib/features/polish/archive_style_screens.dart'
if home.exists():
    home_text = home.read_text()
    home_text = home_text.replace(
        "if (tracks.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());",
        "if (tracks.isEmpty) {\n      return const SliverToBoxAdapter(child: SizedBox.shrink());\n    }",
    )
    home.write_text(home_text)

premium = root / 'lib/features/polish/premium_discovery_screen.dart'
if premium.exists():
    premium_text = premium.read_text()
    premium_text = premium_text.replace("  int _index = 0;\n", "")
    premium_text = premium_text.replace("        _index = 0;\n", "")
    premium_text = premium_text.replace("                          setState(() => _index = index);\n", "")
    premium.write_text(premium_text)

print('P0/P1 patch applied and analyzer hygiene fixed.')
