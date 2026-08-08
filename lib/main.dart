// ════════════════════════════════════════════════
// V Shots — Complete App with YouTube Music
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() => runApp(const VShotsApp());

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

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF4D6A), Color(0xFFFF6B8A)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.music_note, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text('V Shots',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Your music, your way',
                style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// MAIN SCREEN WITH BOTTOM NAVIGATION
// ═══════════════════════════════════════════════

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music_rounded),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// HOME SCREEN — REAL TRENDING MUSIC
// ═══════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _tracks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final yt = YoutubeExplode();
      final results = await yt.search.search('trending music 2024');
      final videos = results.whereType<Video>().take(20).toList();
      yt.close();

      if (mounted) {
        setState(() {
          _tracks = videos.map((v) => {
            'id': v.id.value,
            'title': _cleanTitle(v.title, v.author),
            'artist': v.author,
            'artwork': v.thumbnails.highResUrl.toString(),
            'duration': v.duration?.inSeconds ?? 0,
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _cleanTitle(String title, String artist) {
    var cleaned = title;
    if (cleaned.startsWith('$artist - ')) {
      cleaned = cleaned.substring(artist.length + 3);
    }
    cleaned = cleaned
        .replaceAll(RegExp(r'\s*\(Official.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Official.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Lyric.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Lyric.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Audio.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Audio.*?\]', caseSensitive: false), '')
        .trim();
    return cleaned.isEmpty ? title : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF4D6A), Color(0xFFFF6B8A)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.music_note, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text('V Shots'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFFF4D6A)),
            SizedBox(height: 16),
            Text('Loading trending music...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadTrending, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrending,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Trending Now', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...List.generate(_tracks.length, (index) {
            final track = _tracks[index];
            return TrackTile(
              title: track['title'],
              artist: track['artist'],
              artwork: track['artwork'],
              duration: track['duration'],
              onTap: () => _playTrack(track),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _playTrack(Map<String, dynamic> track) async {
    try {
      final yt = YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(track['id']);
      final audioStreams = manifest.audioOnly.sortByBitrate();

      if (audioStreams.isEmpty) throw Exception('No audio stream');

      final streamUrl = audioStreams.last.url.toString();
      yt.close();

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              title: track['title'],
              artist: track['artist'],
              artwork: track['artwork'],
              streamUrl: streamUrl,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════
// SEARCH SCREEN — REAL RESULTS
// ═══════════════════════════════════════════════

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final yt = YoutubeExplode();
      final results = await yt.search.search(query);
      final videos = results.whereType<Video>().take(20).toList();
      yt.close();

      if (mounted) {
        setState(() {
          _results = videos.map((v) => {
            'id': v.id.value,
            'title': _cleanTitle(v.title, v.author),
            'artist': v.author,
            'artwork': v.thumbnails.highResUrl.toString(),
            'duration': v.duration?.inSeconds ?? 0,
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
      }
    }
  }

  String _cleanTitle(String title, String artist) {
    var cleaned = title;
    if (cleaned.startsWith('$artist - ')) {
      cleaned = cleaned.substring(artist.length + 3);
    }
    cleaned = cleaned
        .replaceAll(RegExp(r'\s*\(Official.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Official.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Lyric.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Lyric.*?\]', caseSensitive: false), '')
        .trim();
    return cleaned.isEmpty ? title : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: false,
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: 'Search music...',
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _results = [];
                        _hasSearched = false;
                      });
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D6A)))
          : _hasSearched
              ? _results.isEmpty
                  ? const Center(child: Text('No results'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final track = _results[index];
                        return TrackTile(
                          title: track['title'],
                          artist: track['artist'],
                          artwork: track['artwork'],
                          duration: track['duration'],
                          onTap: () => _playTrack(track),
                        );
                      },
                    )
              : const Center(child: Text('Search for your favorite music')),
    );
  }

  Future<void> _playTrack(Map<String, dynamic> track) async {
    try {
      final yt = YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(track['id']);
      final audioStreams = manifest.audioOnly.sortByBitrate();

      if (audioStreams.isEmpty) throw Exception('No audio stream');

      final streamUrl = audioStreams.last.url.toString();
      yt.close();

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              title: track['title'],
              artist: track['artist'],
              artwork: track['artwork'],
              streamUrl: streamUrl,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
          _LibraryItem(icon: Icons.favorite, label: 'Liked Songs', color: Colors.red),
          _LibraryItem(icon: Icons.download, label: 'Downloads', color: Colors.green),
          _LibraryItem(icon: Icons.history, label: 'History', color: Colors.orange),
          _LibraryItem(icon: Icons.playlist_play, label: 'Playlists', color: Colors.blue),
        ],
      ),
    );
  }
}

class _LibraryItem extends StatelessWidget {
  const _LibraryItem({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

// ═══════════════════════════════════════════════
// PLAYER SCREEN — REAL PLAYBACK
// ═══════════════════════════════════════════════

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    required this.title,
    required this.artist,
    required this.artwork,
    required this.streamUrl,
    super.key,
  });

  final String title;
  final String artist;
  final String artwork;
  final String streamUrl;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setUrl(widget.streamUrl);

      _player.playerStateStream.listen((state) {
        if (mounted) setState(() => _isPlaying = state.playing);
      });

      _player.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });

      _player.durationStream.listen((dur) {
        if (mounted) setState(() => _duration = dur ?? Duration.zero);
      });

      await _player.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('Now Playing'),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          const Spacer(),

          // Artwork
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4D6A).withOpacity(0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  widget.artwork,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1A1A2E),
                    child: const Icon(Icons.music_note, size: 80, color: Color(0xFFFF4D6A)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Track info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text(widget.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text(widget.artist,
                    style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Slider(
              value: _duration.inMilliseconds > 0
                  ? _position.inMilliseconds / _duration.inMilliseconds
                  : 0.0,
              onChanged: (v) {
                _player.seek(Duration(milliseconds: (v * _duration.inMilliseconds).round()));
              },
              activeColor: const Color(0xFFFF4D6A),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_format(_position), style: TextStyle(color: Colors.white.withOpacity(0.6))),
                Text(_format(_duration), style: TextStyle(color: Colors.white.withOpacity(0.6))),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.shuffle, size: 28), onPressed: () {}),
              IconButton(icon: const Icon(Icons.skip_previous, size: 40), onPressed: () {}),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: Color(0xFFFF4D6A), shape: BoxShape.circle),
                child: IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 36),
                  color: Colors.white,
                  onPressed: () {
                    _isPlaying ? _player.pause() : _player.play();
                  },
                ),
              ),
              IconButton(icon: const Icon(Icons.skip_next, size: 40), onPressed: () {}),
              IconButton(icon: const Icon(Icons.repeat, size: 28), onPressed: () {}),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  String _format(Duration d) {
    return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════
// TRACK TILE WIDGET
// ═══════════════════════════════════════════════

class TrackTile extends StatelessWidget {
  const TrackTile({
    required this.title,
    required this.artist,
    required this.artwork,
    required this.duration,
    required this.onTap,
  });

  final String title;
  final String artist;
  final String artwork;
  final int duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Image.network(
            artwork,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF1A1A2E),
              child: const Icon(Icons.music_note, color: Color(0xFFFF4D6A)),
            ),
          ),
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withOpacity(0.6))),
      trailing: Text(
        '${(duration ~/ 60).toString().padLeft(2, '0')}:${(duration % 60).toString().padLeft(2, '0')}',
        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
      ),
      onTap: onTap,
    );
  }
}
// Force rebuild - Sat Aug  8 18:35:07 UTC 2026
