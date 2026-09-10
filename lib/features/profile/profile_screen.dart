// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Profile screen + track sheets + creator gating
//
// Extracted verbatim from lib/main.dart (2026-09-10, no-behavior-change
// refactor): ProfileScreen, _ProfileTabBarDelegate, showAddToPlaylistSheet,
// showMoreOptionsSheet, _showSleepTimerDialog, _handleCreatorUpload,
// _CreatorGatingSheet. main.dart re-exports this file so all existing
// imports keep working unchanged.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';

import 'package:share_plus/share_plus.dart';

import 'package:v_shots/main.dart'
    show
        addToQueueEnd,
        currentTrackNotifier,
        playbackSignalTracker,
        playNextInQueue,
        playTrack;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:v_shots/core/remote_config/remote_feature_flags.dart';
import 'package:v_shots/core/backend/supabase_service.dart';
import 'package:v_shots/core/models/profile_model.dart';
import 'package:v_shots/core/motion/motion.dart';
import 'package:v_shots/core/player/sleep_timer.dart';
import 'package:v_shots/core/recommendation/taste_profile.dart';
import 'package:v_shots/core/services/profile_service.dart';
import 'package:v_shots/core/theme/app_colors.dart';
import 'package:v_shots/shared/widgets/animated_equalizer.dart';
import 'package:v_shots/shared/widgets/app_avatar.dart';
import 'package:v_shots/shared/widgets/app_button.dart';
import 'package:v_shots/shared/widgets/app_image.dart';
import 'package:v_shots/core/storage/local_library.dart';
import 'package:v_shots/features/auth/auth_modal.dart';
import 'package:v_shots/features/library/history_screen.dart';
import 'package:v_shots/features/morelikethis/more_like_this_screen.dart';
import 'package:v_shots/features/profile/artist_details_screen.dart';
import 'package:v_shots/features/profile/edit_profile_screen.dart';
import 'package:v_shots/features/profile/settings_screen.dart';
import 'package:v_shots/features/shots/upload_shot_screen.dart';

Future<void> _handleCreatorUpload(BuildContext context) async {
  unawaited(HapticFeedback.selectionClick());
  final profile = await ProfileService.instance.getCurrentProfile();
  final isCreator = profile.isCreator;
  if (!context.mounted) return;
  if (isCreator) {
    unawaited(
      Navigator.push(
        context,
        AppPageRoute<void>(builder: (_) => const UploadShotScreen()),
      ),
    );
  } else {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => const _CreatorGatingSheet(),
      ),
    );
  }
}

class _CreatorGatingSheet extends StatelessWidget {
  const _CreatorGatingSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Creator Upload — Limited Access',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMain,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Creator uploads are currently limited to verified creators. Request access to upload your original music, audio shots, and videos to V Shots.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              text: 'Request Access',
              icon: Icons.send_rounded,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.large,
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Creator access request submitted! Our team will review your application.',
                    ),
                    backgroundColor: AppColors.accent,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            AppButton(
              text: 'Maybe Later',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.medium,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// OFFICIAL YOUTUBE PLAYBACK PIPELINE
// ═══════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  ProfileModel? _profile;
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
    LocalLibrary.instance.likedSongs.addListener(_onLibraryChange);
    LocalLibrary.instance.playlists.addListener(_onLibraryChange);
    LocalLibrary.instance.recentlyPlayed.addListener(_onLibraryChange);
  }

  @override
  void dispose() {
    _tabController.dispose();
    LocalLibrary.instance.likedSongs.removeListener(_onLibraryChange);
    LocalLibrary.instance.playlists.removeListener(_onLibraryChange);
    LocalLibrary.instance.recentlyPlayed.removeListener(_onLibraryChange);
    super.dispose();
  }

  void _onLibraryChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final profile = await ProfileService.instance.getCurrentProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final isSignedIn = user != null;
    final profile = _profile ??
        ProfileModel(
          id: 'self',
          username: 'vshots_listener',
          fullName: user?.email ?? 'Music Listener',
          bio: 'Listening on V Shots',
        );

    final likedSongs = LocalLibrary.instance.likedSongs.value;
    final playlists = LocalLibrary.instance.playlists.value;
    final recentlyPlayed = LocalLibrary.instance.recentlyPlayed.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'My Music Profile',
          style: TextStyle(
            color: AppColors.textMain,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.textMain),
            tooltip: 'Listening History',
            onPressed: () => Navigator.push(
              context,
              AppPageRoute<void>(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textMain,
            ),
            onPressed: () => Navigator.push(
              context,
              AppPageRoute<void>(builder: (_) => const SettingsScreen()),
            ).then((_) => _loadProfileData()),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            )
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              color: AppColors.primaryLight,
              backgroundColor: AppColors.surface2,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          Center(
                            child: AppAvatar(
                              avatarUrl: profile.avatarUrl,
                              name: profile.fullName,
                              size: 84,
                              hasGradientBorder: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            profile.fullName,
                            style: const TextStyle(
                              color: AppColors.textMain,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isSignedIn
                                ? (user.email ?? '@${profile.username}')
                                : 'Guest Session',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Music Stats Row
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMusicStat(
                                  'Liked Songs',
                                  '${likedSongs.length}',
                                  Icons.favorite,
                                  AppColors.hotPink,
                                ),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: AppColors.border,
                                ),
                                _buildMusicStat(
                                  'Playlists',
                                  '${playlists.length}',
                                  Icons.playlist_play,
                                  AppColors.accent,
                                ),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: AppColors.border,
                                ),
                                _buildMusicStat(
                                  'Played',
                                  '${recentlyPlayed.length}',
                                  Icons.history,
                                  AppColors.warning,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Your Taste — derived live from the recommendation
                          // engine's taste profile (plays, completions, likes,
                          // skips), not a static label.
                          _buildTasteCard(),

                          const SizedBox(height: 14),

                          // Action Buttons Row
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  text: 'Edit Profile',
                                  icon: Icons.edit_outlined,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.medium,
                                  onPressed: () => Navigator.push(
                                    context,
                                    AppPageRoute<void>(
                                      builder: (_) => EditProfileScreen(
                                        initialProfile: profile,
                                        onProfileUpdated: (p) =>
                                            setState(() => _profile = p),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AppButton(
                                  text: isSignedIn ? 'Settings' : 'Sign In',
                                  icon: isSignedIn
                                      ? Icons.settings_outlined
                                      : Icons.login_rounded,
                                  variant: isSignedIn
                                      ? AppButtonVariant.secondary
                                      : AppButtonVariant.primary,
                                  size: AppButtonSize.medium,
                                  onPressed: () {
                                    if (isSignedIn) {
                                      Navigator.push(
                                        context,
                                        AppPageRoute<void>(
                                          builder: (_) =>
                                              const SettingsScreen(),
                                        ),
                                      ).then((_) => _loadProfileData());
                                    } else {
                                      AuthModal.show(
                                        context,
                                      ).then((_) => _loadProfileData());
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Creator Hub Card — hidden until a real UGC backend
                          // exists (`enable_social`).
                          if (RemoteFeatureFlags.instance.enableSocial)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: profile.isCreator
                                      ? AppColors.accent.withValues(alpha: 0.4)
                                      : AppColors.border,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: AppColors.primaryGradient,
                                    ),
                                    child: Icon(
                                      profile.isCreator
                                          ? Icons.video_library_rounded
                                          : Icons.stars_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile.isCreator
                                              ? 'Creator Studio'
                                              : 'Become a Creator',
                                          style: const TextStyle(
                                            color: AppColors.textMain,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          profile.isCreator
                                              ? 'Upload original music & shots'
                                              : 'Share music with listeners',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _handleCreatorUpload(context),
                                    child: Text(
                                      profile.isCreator ? 'Upload' : 'Request',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ProfileTabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        indicatorColor: AppColors.accent,
                        indicatorWeight: 3,
                        labelColor: AppColors.accent,
                        unselectedLabelColor: AppColors.textMuted,
                        tabs: const [
                          Tab(
                            icon: Icon(Icons.favorite_rounded),
                            text: 'Liked Songs',
                          ),
                          Tab(
                            icon: Icon(Icons.playlist_play_rounded),
                            text: 'Playlists',
                          ),
                          Tab(
                            icon: Icon(Icons.history_rounded),
                            text: 'Recently Played',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLikedTracksTab(likedSongs),
                    _buildPlaylistsTab(playlists),
                    _buildRecentlyPlayedTab(recentlyPlayed),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTasteCard() {
    final taste = TasteProfileBuilder().build();
    final genres = taste.topGenres.take(5).toList();
    final artists = taste.topArtists.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AppColors.accent),
              SizedBox(width: 6),
              Text(
                'Your Taste',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (genres.isEmpty && artists.isEmpty)
            const Text(
              'Listen to a few songs — your taste profile will build itself here.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            )
          else ...[
            if (genres.isNotEmpty) ...[
              const Text(
                'Top genres',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: genres.map((g) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      g,
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (artists.isNotEmpty) ...[
              const Text(
                'Top artists',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              ...artists.map(
                (a) => InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.push(
                    context,
                    AppPageRoute<void>(
                      builder: (_) => ArtistDetailsScreen(
                        name: a,
                        role: 'Artist',
                        imageUrl: '',
                        query: '$a top songs official audio',
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          size: 14,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.textSubtle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMusicStat(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textMain,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLikedTracksTab(List<Map<String, dynamic>> liked) {
    if (liked.isEmpty) {
      return const Center(
        child: Text(
          'No liked songs yet — tap ♡ on any song to save it here.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: liked.length,
      itemBuilder: (context, index) {
        if (index < 0 || index >= liked.length) return const SizedBox.shrink();
        final t = liked[index];
        final trackId = t['id'] as String? ?? '';
        final isCurrentPlaying = currentTrackNotifier.value?['id'] == trackId;
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                ArtworkFadeIn(
                  child: AppImage(
                    t['artwork'] as String?,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                if (isCurrentPlaying)
                  const Positioned(
                    left: 4,
                    bottom: 4,
                    child: AnimatedEqualizer(size: 12, color: AppColors.accent),
                  ),
              ],
            ),
          ),
          title: Text(
            t['title'] as String? ?? '',
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
          ),
          subtitle: Text(
            t['artist'] as String? ?? '',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            maxLines: 1,
          ),
          trailing: const Icon(
            Icons.play_arrow_rounded,
            color: AppColors.accent,
            size: 22,
          ),
          onTap: () => playTrack(context, t, liked, index),
        );
      },
    );
  }

  Widget _buildPlaylistsTab(List<Map<String, dynamic>> playlists) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          title: const Text(
            'Create Playlist',
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: const Text(
            'Create a new music playlist',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          onTap: () {
            final ctrl = TextEditingController();
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: const Text('New Playlist'),
                content: TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Playlist Name'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (ctrl.text.trim().isNotEmpty) {
                        LocalLibrary.instance.createPlaylist(ctrl.text.trim());
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('Create'),
                  ),
                ],
              ),
            );
          },
        ),
        for (final p in playlists)
          ListTile(
            leading: const Icon(
              Icons.playlist_play_rounded,
              color: AppColors.accent,
              size: 32,
            ),
            title: Text(p['name'] as String? ?? ''),
            subtitle: Text(
              '${(p['tracks'] as List?)?.length ?? 0} tracks',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentlyPlayedTab(List<Map<String, dynamic>> recent) {
    if (recent.isEmpty) {
      return const Center(
        child: Text(
          'No recently played tracks.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: recent.length,
      itemBuilder: (context, index) {
        if (index < 0 || index >= recent.length) return const SizedBox.shrink();
        final t = recent[index];
        final trackId = t['id'] as String? ?? '';
        final isCurrentPlaying = currentTrackNotifier.value?['id'] == trackId;
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                ArtworkFadeIn(
                  child: AppImage(
                    t['artwork'] as String?,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                if (isCurrentPlaying)
                  const Positioned(
                    left: 4,
                    bottom: 4,
                    child: AnimatedEqualizer(size: 12, color: AppColors.accent),
                  ),
              ],
            ),
          ),
          title: Text(
            t['title'] as String? ?? '',
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
          ),
          subtitle: Text(
            t['artist'] as String? ?? '',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            maxLines: 1,
          ),
          trailing: const Icon(
            Icons.play_arrow_rounded,
            color: AppColors.accent,
            size: 22,
          ),
          onTap: () => playTrack(context, t, recent, index),
        );
      },
    );
  }
}

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  _ProfileTabBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.background, child: _tabBar);
  }

  @override
  bool shouldRebuild(_ProfileTabBarDelegate oldDelegate) {
    return false;
  }
}

// ═══════════════════════════════════════════════
// LYRICS & SHARED BOTTOM SHEETS
// ═══════════════════════════════════════════════

void showAddToPlaylistSheet(BuildContext context, Map<String, dynamic> track) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (ctx) {
      return ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: LocalLibrary.instance.playlists,
        builder: (context, playlists, _) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Add to playlist',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No playlists yet. Create one from Profile first.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                else
                  ...playlists.map(
                    (p) => ListTile(
                      leading: const Icon(Icons.playlist_play),
                      title: Text(p['name'] as String? ?? ''),
                      onTap: () async {
                        await LocalLibrary.instance.addTrackToPlaylist(
                          p['id'] as String,
                          track,
                        );
                        playbackSignalTracker.onPlaylistAdd(track);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added to ${p['name']}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

void showMoreOptionsSheet(
  BuildContext context,
  Map<String, dynamic> track, {
  VoidCallback? onNotInterested,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final title = (track['title'] as String?) ?? 'Unknown Track';
      final artist = (track['artist'] as String?) ?? 'Unknown Artist';
      final trackId = (track['id'] as String?) ?? '';

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ArtworkFadeIn(
                    child: AppImage(
                      track['artwork'] as String?,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(color: AppColors.borderSubtle),
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: const Text('More Like This'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(HapticFeedback.selectionClick());
                  Navigator.push(
                    context,
                    AppPageRoute<void>(
                      builder: (_) => MoreLikeThisScreen(track: track),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: const Text('View Artist'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(HapticFeedback.selectionClick());
                  final artistName =
                      (track['artist'] as String?) ?? 'Unknown Artist';
                  Navigator.push(
                    context,
                    AppPageRoute<void>(
                      builder: (_) => ArtistDetailsScreen(
                        name: artistName,
                        role: 'Artist',
                        imageUrl: (track['artwork'] as String?) ?? '',
                        query: '$artistName top songs official audio',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_play_rounded),
                title: const Text('Play Next'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(HapticFeedback.lightImpact());
                  playNextInQueue(context, track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: const Text('Add to Queue'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(HapticFeedback.lightImpact());
                  addToQueueEnd(context, track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(HapticFeedback.selectionClick());
                  SharePlus.instance.share(
                    ShareParams(
                      text:
                          'Listen to "$title" by $artist on V Shots: https://www.youtube.com/watch?v=$trackId',
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Sleep Timer'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(HapticFeedback.selectionClick());
                  _showSleepTimerDialog(context);
                },
              ),
              if (onNotInterested != null)
                ListTile(
                  leading: const Icon(Icons.do_not_disturb_on_outlined),
                  title: const Text('Not Interested in this artist'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onNotInterested();
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

void _showSleepTimerDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Sleep Timer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('1 minute'),
            onTap: () {
              SleepTimer.instance.start(const Duration(minutes: 1));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('5 minutes'),
            onTap: () {
              SleepTimer.instance.start(const Duration(minutes: 5));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('10 minutes'),
            onTap: () {
              SleepTimer.instance.start(const Duration(minutes: 10));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('15 minutes'),
            onTap: () {
              SleepTimer.instance.start(const Duration(minutes: 15));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('30 minutes'),
            onTap: () {
              SleepTimer.instance.start(const Duration(minutes: 30));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('45 minutes'),
            onTap: () {
              SleepTimer.instance.start(const Duration(minutes: 45));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('60 minutes'),
            onTap: () {
              SleepTimer.instance.start(const Duration(minutes: 60));
              Navigator.pop(ctx);
            },
          ),
          if (SleepTimer.instance.isActive)
            ListTile(
              title: const Text(
                'Turn off timer',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                SleepTimer.instance.cancel();
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    ),
  );
}
