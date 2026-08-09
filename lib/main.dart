// ════════════════════════════════════════════════
// V Shots — Complete Premium Music App
// ════════════════════════════════════════════════

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'core/audio/player_controller.dart';
import 'features/home/data/home_content_service.dart';
import 'features/home/domain/models/home_models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  playerController.initialize();
  runApp(const VShotsApp());
}

class VShotsApp extends StatelessWidget {
  const VShotsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V Shots',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFFF4D6A),
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
      ),
      home: const SplashScreen(),
    );
  }
}

// ═══════════════════════════════════════════════
// SPLASH SCREEN
// ═══════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _c, curve: Curves.easeIn));
    _scale = Tween<double>(begin: 0.8, end: 1).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF4D6A), Color(0xFFFF6B8A)]),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF4D6A).withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))],
                  ),
                  child: const Icon(Icons.music_note, size: 52, color: Colors.white),
                ),
                const SizedBox(height: 28),
                const Text('V Shots', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text('Your music, your way', style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.6))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// MAIN SHELL
// ═══════════════════════════════════════════════

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: const [
              HomeScreen(),
              SearchScreen(),
              LibraryScreen(),
              ProfileScreen(),
            ],
          ),
          // Mini Player
          StreamBuilder<PlayerState>(
            stream: playerController.stateStream,
            builder: (context, snap) {
              final state = snap.data;
              if (state == null || state.currentTrack == null) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: 8, right: 8, bottom: 72,
                child: _MiniPlayer(state: state),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: const Color(0xFF0A0A0F).withOpacity(0.95),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search_rounded), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music_rounded), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// MINI PLAYER
// ═══════════════════════════════════════════════

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.state});
  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    final track = state.currentTrack!;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlayerScreen(playerState: state)),
      ),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E).withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                  child: track.artwork != null
                      ? Image.network(track.artwork!, width: 56, height: 56, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _artPlaceholder())
                      : _artPlaceholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
                  onPressed: () => playerController.togglePlayPause(),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, size: 28),
                  onPressed: () => playerController.next(),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _artPlaceholder() => Container(
    width: 56, height: 56, color: const Color(0xFF1A1A2E),
    child: const Icon(Icons.music_note, color: Color(0xFFFF4D6A)),
  );
}

// ═══════════════════════════════════════════════
// HOME SCREEN — PREMIUM CONTENT SECTIONS
// ═══════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = HomeContentService();
  HomeFeed? _feed;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() { _loading = true; _error = null; });
    try {
      final feed = await _service.fetchFeed();
      if (mounted) setState(() { _feed = feed; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            title: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF4D6A), Color(0xFFFF6B8A)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.music_note, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Text('V Shots', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            actions: [
              IconButton(icon: const Icon(Icons.search), onPressed: () {}),
              IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
            ],
          ),

          // Greeting
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('What do you want to listen to?',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15)),
                ],
              ),
            ),
          ),

          // Content
          if (_loading)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF4D6A), Color(0xFFFF6B8A)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.music_note, size: 28, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text('Loading your music...', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                    ],
                  ),
                ),
              ),
            )
          else if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadFeed, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else if (_feed != null)
            ..._feed!.sections.map((section) => _buildSection(section)),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 160)),
        ],
      ),
    );
  }

  Widget _buildSection(HomeSection section) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                if (section.subtitle != null)
                  Text(section.subtitle!, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
              ],
            ),
          ),
          SizedBox(
            height: section.type == HomeSectionType.artists ? 160 : 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: section.items.length,
              itemBuilder: (context, i) {
                final item = section.items[i];
                if (section.type == HomeSectionType.artists) {
                  return _ArtistCard(item: item, onTap: () => _playItem(item));
                }
                return _MusicCard(item: item, onTap: () => _playItem(item));
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playItem(HomeItem item) async {
    if (item.type != 'track') return;

    final track = TrackItem(
      id: item.id,
      title: item.title,
      artist: item.subtitle ?? '',
      artwork: item.artwork,
      durationSeconds: item.durationSeconds,
    );

    // Convert all section tracks to queue.
    final allTracks = _feed!.sections
        .expand((s) => s.items)
        .where((i) => i.type == 'track')
        .map((i) => TrackItem(
              id: i.id, title: i.title, artist: i.subtitle ?? '',
              artwork: i.artwork, durationSeconds: i.durationSeconds,
            ))
        .toList();

    final index = allTracks.indexWhere((t) => t.id == track.id);

    await playerController.playQueue(allTracks, startIndex: index >= 0 ? index : 0);
  }
}

// ═══════════════════════════════════════════════
// MUSIC CARD
// ═══════════════════════════════════════════════

class _MusicCard extends StatelessWidget {
  const _MusicCard({required this.item, required this.onTap});
  final HomeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      item.artwork ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1A1A2E),
                        child: const Icon(Icons.music_note, size: 40, color: Color(0xFFFF4D6A)),
                      ),
                    ),
                    Positioned(
                      right: 8, bottom: 8,
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D6A),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color(0xFFFF4D6A).withOpacity(0.4), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (item.subtitle != null)
              Text(item.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// ARTIST CARD
// ═══════════════════════════════════════════════

class _ArtistCard extends StatelessWidget {
  const _ArtistCard({required this.item, required this.onTap});
  final HomeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            ClipOval(
              child: Image.network(
                item.artwork ?? '',
                width: 100, height: 100, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 100, height: 100,
                  color: const Color(0xFF1A1A2E),
                  child: const Icon(Icons.person, size: 40, color: Color(0xFFFF4D6A)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// SEARCH SCREEN
// ═══════════════════════════════════════════════

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _yt = YoutubeExplode();
  List<Video> _results = [];
  bool _loading = false;
  bool _searched = false;

  static const _categories = [
    ('Bollywood', '🎵', Color(0xFFE91E63)),
    ('Hindi', '🎤', Color(0xFF9C27B0)),
    ('Punjabi', '🥁', Color(0xFFFF9800)),
    ('English', '🎸', Color(0xFF2196F3)),
    ('Pop', '🎵', Color(0xFFE91E63)),
    ('Hip-Hop', '🎤', Color(0xFF673AB7)),
    ('EDM', '🎧', Color(0xFF00BCD4)),
    ('Chill', '😌', Color(0xFF4CAF50)),
    ('Workout', '💪', Color(0xFFFF5722)),
    ('Romantic', '❤️', Color(0xFFE91E63)),
    ('Focus', '🧠', Color(0xFF3F51B5)),
    ('Sleep', '🌙', Color(0xFF607D8B)),
  ];

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() { _loading = true; _searched = true; });
    try {
      final results = await _yt.search.search(q);
      if (mounted) setState(() { _results = results.whereType<Video>().toList(); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _results = []; _loading = false; });
    }
  }

  Future<void> _playVideo(Video video) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
          Text('Loading ${_clean(video.title, video.author)}...'),
        ]),
        backgroundColor: const Color(0xFF1A1A2E),
        duration: const Duration(seconds: 5),
      ));

      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      final audio = manifest.audioOnly.sortByBitrate();
      if (audio.isEmpty) throw Exception('No audio stream');

      await playerController.playTrack(TrackItem(
        id: video.id.value,
        title: _clean(video.title, video.author),
        artist: video.author,
        artwork: video.thumbnails.highResUrl.toString(),
        durationSeconds: video.duration?.inSeconds,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlayerScreen(playerState: playerController.state)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _clean(String t, String a) {
    var c = t;
    if (c.startsWith('$a - ')) c = c.substring(a.length + 3);
    return c.replaceAll(RegExp(r'\s*[\(\[][^\)\]]*[\)\]]', caseSensitive: false), '').trim();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 44,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: _controller,
            onSubmitted: _search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search songs, artists, albums...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D6A)))
          : _searched
              ? _results.isEmpty
                  ? Center(child: Text('No results', style: TextStyle(color: Colors.white.withOpacity(0.5))))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      itemBuilder: (ctx, i) => _SearchTile(video: _results[i], onTap: () => _playVideo(_results[i])),
                    )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Browse Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.9))),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10, runSpacing: 10,
                      children: _categories.map((c) => GestureDetector(
                        onTap: () { _controller.text = c.$1; _search(c.$1); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: c.$3.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.$3.withOpacity(0.3)),
                          ),
                          child: Text('${c.$2} ${c.$1}', style: TextStyle(color: c.$3, fontWeight: FontWeight.w500)),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
    );
  }
}

class _SearchTile extends StatelessWidget {
  const _SearchTile({required this.video, required this.onTap});
  final Video video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(video.thumbnails.highResUrl.toString(), width: 48, height: 48, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: const Color(0xFF1A1A2E), child: const Icon(Icons.music_note, color: Color(0xFFFF4D6A)))),
      ),
      title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(video.author, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withOpacity(0.6))),
      trailing: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.3), size: 20),
      onTap: onTap,
    );
  }
}

// ═══════════════════════════════════════════════
// LIBRARY SCREEN
// ═══════════════════════════════════════════════

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LibItem(icon: Icons.favorite, label: 'Liked Songs', color: const Color(0xFFE91E63)),
          _LibItem(icon: Icons.download, label: 'Downloads', color: const Color(0xFF4CAF50)),
          _LibItem(icon: Icons.history, label: 'Recently Played', color: const Color(0xFFFF9800)),
          _LibItem(icon: Icons.playlist_play, label: 'Playlists', color: const Color(0xFF2196F3)),
          _LibItem(icon: Icons.album, label: 'Albums', color: const Color(0xFF9C27B0)),
          _LibItem(icon: Icons.person, label: 'Artists', color: const Color(0xFF00BCD4)),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Icon(Icons.library_music, size: 48, color: Colors.white.withOpacity(0.15)),
                const SizedBox(height: 12),
                Text('Your library is empty', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                const SizedBox(height: 8),
                Text('Music you save will appear here', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibItem extends StatelessWidget {
  const _LibItem({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// PROFILE SCREEN
// ═══════════════════════════════════════════════

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: const Color(0xFF1A1A2E),
                  child: Text('V', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.8))),
                ),
                const SizedBox(height: 12),
                const Text('V Shots User', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                Text('user@vshots.app', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Free Plan', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _ProfileItem(icon: Icons.workspace_premium, label: 'Upgrade to Premium', color: const Color(0xFFFF4D6A)),
          _ProfileItem(icon: Icons.settings, label: 'Settings'),
          _ProfileItem(icon: Icons.help_outline, label: 'Help & Support'),
          _ProfileItem(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy'),
          _ProfileItem(icon: Icons.description_outlined, label: 'Terms of Service'),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white.withOpacity(0.7)),
      title: Text(label),
      trailing: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
    );
  }
}

// ═══════════════════════════════════════════════
// PLAYER SCREEN — PREMIUM
// ═══════════════════════════════════════════════

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({required this.playerState, super.key});
  final PlayerState playerState;

  @override
  Widget build(BuildContext context) {
    final track = playerState.currentTrack;
    if (track == null) return const Scaffold(body: Center(child: Text('No track')));

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [const Color(0xFFFF4D6A).withOpacity(0.12), const Color(0xFF0A0A0F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 32), onPressed: () => Navigator.pop(context)),
                    Column(children: [
                      Text('PLAYING FROM', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
                      const Text('Search', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                    IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
                  ],
                ),
              ),

              const Spacer(),

              // Artwork
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Container(
                  width: double.infinity, height: 320,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF4D6A).withOpacity(0.25), blurRadius: 40, offset: const Offset(0, 20))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: track.artwork != null
                        ? Image.network(track.artwork!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A2E), child: const Icon(Icons.music_note, size: 80, color: Color(0xFFFF4D6A))))
                        : Container(color: const Color(0xFF1A1A2E), child: const Icon(Icons.music_note, size: 80, color: Color(0xFFFF4D6A))),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Track info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(track.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(track.artist, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  IconButton(icon: const Icon(Icons.favorite_border, size: 28), onPressed: () {}),
                ]),
              ),
              const SizedBox(height: 20),

              // Progress
              StreamBuilder<PlayerState>(
                stream: playerController.stateStream,
                builder: (context, snap) {
                  final s = snap.data ?? playerState;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(children: [
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: const Color(0xFFFF4D6A),
                          inactiveTrackColor: Colors.white.withOpacity(0.1),
                          thumbColor: const Color(0xFFFF4D6A),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          value: s.duration.inMilliseconds > 0
                              ? (s.position.inMilliseconds / s.duration.inMilliseconds).clamp(0.0, 1.0)
                              : 0.0,
                          onChanged: (v) => playerController.seek(
                            Duration(milliseconds: (v * s.duration.inMilliseconds).round()),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(s.position), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                            Text(_fmt(s.duration), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                          ],
                        ),
                      ),
                    ]),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Controls
              StreamBuilder<PlayerState>(
                stream: playerController.stateStream,
                builder: (context, snap) {
                  final s = snap.data ?? playerState;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.shuffle, size: 24,
                            color: s.isShuffle ? const Color(0xFFFF4D6A) : Colors.white.withOpacity(0.6)),
                        onPressed: () => playerController.toggleShuffle(),
                      ),
                      IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 40), onPressed: () => playerController.previous()),
                      GestureDetector(
                        onTap: () => playerController.togglePlayPause(),
                        child: Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF4D6A), Color(0xFFFF6B8A)]),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: const Color(0xFFFF4D6A).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                          ),
                          child: Icon(s.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36, color: Colors.white),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.skip_next_rounded, size: 40), onPressed: () => playerController.next()),
                      IconButton(
                        icon: Icon(
                          s.repeatMode == RepeatMode.all ? Icons.repeat : s.repeatMode == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
                          size: 24,
                          color: s.repeatMode != RepeatMode.off ? const Color(0xFFFF4D6A) : Colors.white.withOpacity(0.6),
                        ),
                        onPressed: () => playerController.cycleRepeatMode(),
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
