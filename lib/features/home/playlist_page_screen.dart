// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Playlist Page (full-screen playlist list)
// ═════════════════════════════════════════════════════════════════════════════
//
// Tapping a playlist section (card or "View all") opens the FULL playlist
// here: every track listed, Play All / Shuffle, tap a track → the whole
// list becomes the playback queue so songs AUTO-ADVANCE on completion
// (no manual next). Reuses the single global playback manager + browser.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../core/providers/music_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart' show currentTrackNotifier, musicRepository, playTrack;
import '../../shared/utils/youtube_url.dart';
import '../../shared/widgets/animated_equalizer.dart';
import '../../shared/widgets/app_image.dart';

class PlaylistPageScreen extends StatefulWidget {
  const PlaylistPageScreen({
    super.key,
    required this.sectionId,
    required this.title,
    required this.subtitle,
    required this.sourceValue,
    this.initialTracks = const [],
    this.repository,
  });

  final String sectionId;
  final String title;
  final String subtitle;
  final String sourceValue;

  /// Tracks already resolved by the Home shelf (instant first paint while
  /// the full list loads).
  final List<Map<String, dynamic>> initialTracks;
  final MusicRepository? repository;

  @override
  State<PlaylistPageScreen> createState() => _PlaylistPageScreenState();
}

class _PlaylistPageScreenState extends State<PlaylistPageScreen> {
  List<Map<String, dynamic>> _tracks = [];
  bool _loading = true;
  String? _error;

  MusicRepository get _repo => widget.repository ?? musicRepository;

  @override
  void initState() {
    super.initState();
    _tracks = List.of(widget.initialTracks);
    _loading = _tracks.isEmpty;
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = _tracks.isEmpty;
        _error = null;
      });
    }
    final playlistId = extractYoutubePlaylistId(widget.sourceValue);
    if (playlistId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not extract a playlist id from this URL.';
        });
      }
      return;
    }
    try {
      final tracks = await _repo.getPlaylistTracks(playlistId, limit: 100);
      if (!mounted) return;
      setState(() {
        if (tracks.isNotEmpty) _tracks = tracks;
        _loading = false;
        _error = tracks.isEmpty
            ? 'This playlist returned no playable videos.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the playlist: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon:
                const Icon(Icons.arrow_back_rounded, color: AppColors.textMain),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                if (widget.subtitle.isNotEmpty)
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_tracks.isNotEmpty)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => playTrack(context, _tracks.first, _tracks, 0),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Play All'),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.playlist_remove_rounded,
                  size: 44, color: AppColors.textMuted),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_tracks.isEmpty) {
      return const Center(
        child: Text(
          'No songs in this playlist',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _tracks.length,
      itemBuilder: (context, i) => _trackTile(_tracks[i], i),
    );
  }

  Widget _trackTile(Map<String, dynamic> track, int i) {
    final title = (track['title'] as String?) ?? 'Untitled';
    final artist = (track['artist'] as String?) ?? '';
    final artwork = (track['artwork'] as String?) ?? '';
    return InkWell(
      onTap: () => playTrack(context, track, _tracks, i),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AppImage(
                artwork,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorIconColor: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: currentTrackNotifier,
              builder: (context, current, _) {
                final playing = current?['id'] == track['id'];
                return playing
                    ? const AnimatedEqualizer(
                        isPlaying: true, size: 16, color: AppColors.primary)
                    : const Icon(Icons.play_circle_outline_rounded,
                        color: AppColors.textMuted);
              },
            ),
          ],
        ),
      ),
    );
  }
}
