// ════════════════════════════════════════════════
// V Shots — Main Entry Point
// ════════════════════════════════════════════════
//
// REAL YouTube Music integration.
// No dummy data. No Track 1. No Artist 1.
// ════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'core/cache/cache_manager.dart';
import 'core/cache/memory/memory_cache.dart';
import 'core/cache/serialization/cache_serializer.dart';
import 'core/providers/adapters/youtube_music/youtube_music_provider.dart';
import 'core/providers/imusic_provider.dart';
import 'core/providers/models/provider_models.dart';

// ═══════════════════════════════════════════════
// GLOBAL STATE
// ═══════════════════════════════════════════════

late YouTubeMusicProvider musicProvider;
late CacheManager cacheManager;
final AudioPlayer audioPlayer = AudioPlayer();

// ═══════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize cache.
  cacheManager = CacheManager(
    memory: MemoryCache<String>(maxSize: 200),
    disk: FakeDiskCache(),
    serializer: CacheSerializer(),
  );

  // Initialize YouTube Music provider.
  musicProvider = YouTubeMusicProvider(cacheManager: cacheManager);
  await musicProvider.initialize(const ProviderInitConfig(apiKey: ''));

  runApp(const VShotsApp());
}

/// Fake disk cache for now (memory only).
class FakeDiskCache {
  final Map<String, String> _store = {};
  String? get(String key) => _store[key];
  Future<void> put(String key, String data, {Duration? ttl}) async {
    _store[key] = data;
  }
  Future<void> clear() async => _store.clear();
  int get length => _store.length;
}

// ═══════════════════════════════════════════════
// ROOT APP
// ═══════════════════════════════════════════════

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
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  void _navigate() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
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
            Text('Powered by YouTube Music',
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// HOME SCREEN — REAL DATA
// ═══════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ProviderTrack> _trendingTracks = [];
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

      final tracks = await musicProvider.getTrending(limit: 20);

      if (mounted) {
        setState(() {
          _trendingTracks = tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load music: $e';
          _isLoading = false;
        });
      }
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
        ],
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
            ElevatedButton(
              onPressed: _loadTrending,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_trendingTracks.isEmpty) {
      return const Center(child: Text('No trending music found'));
    }

    return RefreshIndicator(
      onRefresh: _loadTrending,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Trending Now',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...List.generate(_trendingTracks.length, (index) {
            final track = _trendingTracks[index];
            return _TrackTile(
              track: track,
              onTap: () => _playTrack(track, index),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _playTrack(ProviderTrack track, int index) async {
    try {
      // Get stream URL.
      final stream = await musicProvider.getStream(track.id);

      // Navigate to player.
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              track: track,
              streamUrl: stream.url,
              playlist: _trendingTracks,
              currentIndex: index,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play: $e'), backgroundColor: Colors.red),
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
  List<ProviderTrack> _results = [];
  List<String> _suggestions = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.length >= 2) {
        _getSuggestions(query);
      } else {
        setState(() => _suggestions = []);
      }
    });
  }

  Future<void> _getSuggestions(String query) async {
    try {
      final suggestions = await musicProvider.getSuggestions(query);
      if (mounted) {
        setState(() => _suggestions = suggestions);
      }
    } catch (e) {
      // Ignore suggestion errors.
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _suggestions = [];
    });

    try {
      final results = await musicProvider.search(query, limit: 30);

      if (mounted) {
        setState(() {
          _results = results.tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onSearchChanged,
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
                        _suggestions = [];
                        _hasSearched = false;
                      });
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Show suggestions.
    if (_suggestions.isNotEmpty && !_hasSearched) {
      return ListView.builder(
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.search, size: 20),
            title: Text(_suggestions[index]),
            onTap: () {
              _controller.text = _suggestions[index];
              _search(_suggestions[index]);
            },
          );
        },
      );
    }

    // Show loading.
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF4D6A)),
      );
    }

    // Show results.
    if (_hasSearched) {
      if (_results.isEmpty) {
        return const Center(child: Text('No results found'));
      }

      return ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final track = _results[index];
          return _TrackTile(
            track: track,
            onTap: () => _playTrack(track, index),
          );
        },
      );
    }

    // Show recent searches / suggestions.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'Search for your favorite music',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Future<void> _playTrack(ProviderTrack track, int index) async {
    try {
      final stream = await musicProvider.getStream(track.id);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              track: track,
              streamUrl: stream.url,
              playlist: _results,
              currentIndex: index,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════
// PLAYER SCREEN — REAL PLAYBACK
// ═══════════════════════════════════════════════

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    required this.track,
    required this.streamUrl,
    this.playlist = const [],
    this.currentIndex = 0,
    super.key,
  });

  final ProviderTrack track;
  final String streamUrl;
  final List<ProviderTrack> playlist;
  final int currentIndex;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late AudioPlayer _player;
  late ProviderTrack _currentTrack;
  late int _currentIndex;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _currentTrack = widget.track;
    _currentIndex = widget.currentIndex;
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      // Set the audio source.
      await _player.setUrl(widget.streamUrl);

      // Listen to player state.
      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
        }
      });

      // Listen to position.
      _player.positionStream.listen((position) {
        if (mounted) {
          setState(() => _position = position);
        }
      });

      // Listen to duration.
      _player.durationStream.listen((duration) {
        if (mounted) {
          setState(() => _duration = duration ?? Duration.zero);
        }
      });

      // Start playing.
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

          // Artwork.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
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
                  child: _currentTrack.artworkUrl != null
                      ? Image.network(
                          _currentTrack.artworkUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _artworkPlaceholder(),
                        )
                      : _artworkPlaceholder(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Track info.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text(
                  _currentTrack.title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  _currentTrack.artist,
                  style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Progress.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Slider(
                  value: _duration.inMilliseconds > 0
                      ? _position.inMilliseconds / _duration.inMilliseconds
                      : 0.0,
                  onChanged: (value) {
                    final position = Duration(
                      milliseconds: (value * _duration.inMilliseconds).round(),
                    );
                    _player.seek(position);
                  },
                  activeColor: const Color(0xFFFF4D6A),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_position),
                          style: TextStyle(color: Colors.white.withOpacity(0.6))),
                      Text(_formatDuration(_duration),
                          style: TextStyle(color: Colors.white.withOpacity(0.6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Controls.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.shuffle, size: 28),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 40),
                onPressed: _playPrevious,
              ),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF4D6A),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 36),
                  color: Colors.white,
                  onPressed: () {
                    if (_isPlaying) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 40),
                onPressed: _playNext,
              ),
              IconButton(
                icon: const Icon(Icons.repeat, size: 28),
                onPressed: () {},
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _artworkPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Icon(Icons.music_note, size: 80, color: Color(0xFFFF4D6A)),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _playNext() async {
    if (widget.playlist.isEmpty) return;

    _currentIndex = (_currentIndex + 1) % widget.playlist.length;
    _currentTrack = widget.playlist[_currentIndex];

    try {
      final stream = await musicProvider.getStream(_currentTrack.id);
      await _player.setUrl(stream.url);
      await _player.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _playPrevious() async {
    if (widget.playlist.isEmpty) return;

    _currentIndex = (_currentIndex - 1 + widget.playlist.length) % widget.playlist.length;
    _currentTrack = widget.playlist[_currentIndex];

    try {
      final stream = await musicProvider.getStream(_currentTrack.id);
      await _player.setUrl(stream.url);
      await _player.play();
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
// TRACK TILE WIDGET
// ═══════════════════════════════════════════════

class _TrackTile extends StatelessWidget {
  const _TrackTile({required this.track, required this.onTap});

  final ProviderTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: track.artworkUrl != null
              ? Image.network(
                  track.artworkUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.white.withOpacity(0.6)),
      ),
      trailing: track.duration != Duration.zero
          ? Text(
              _formatDuration(track.duration),
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Icon(Icons.music_note, color: Color(0xFFFF4D6A)),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
