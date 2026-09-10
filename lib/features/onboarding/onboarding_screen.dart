// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Onboarding Screen (real preference personalization, 2026 redesign)
// ═════════════════════════════════════════════════════════════════════════════
//
// A 6-step flow whose EVERY selection genuinely shapes the user's content:
//
//   1. Welcome      — what personalization does (sign-in optional)
//   2. Languages    — seeds the cold-start candidate generator's language
//                     pools (existing `_languageQueries` mapping)
//   3. Artists      — curated per selected language + free search; stored as
//                     favoriteArtists and used as recommendation seeds
//   4. Songs        — real search through the app's music repository
//                     (validated + blocked-channel filtered); stored as
//                     favoriteSongs seed content
//   5. Genres/Moods — seeds the engine's genre-tag queries
//   6. Review       — jump-back editing, then Finish
//
// Everything persists via PersonalizationStore.completeOnboarding, which
// bumps the store revision → RecommendationCache is invalidated → the FIRST
// Home/For You load after onboarding is already personalized. Skips, back,
// deselect and clear are supported everywhere; no step is mandatory; a
// failing/absent song-search source never blocks completion.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/blocked_channel_registry.dart';
import '../../core/storage/personalization_store.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_input.dart';
import '../../shared/widgets/loading_skeleton.dart';
import '../auth/auth_modal.dart';

/// Optional song-search injection (wired to the real music repository in
/// main.dart; omitted in tests → the songs step degrades gracefully).
typedef OnboardingSongSearch = Future<List<Map<String, dynamic>>> Function(
  String query,
);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen(
      {super.key, required this.onComplete, this.songSearch});

  final VoidCallback onComplete;
  final OnboardingSongSearch? songSearch;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _OnboardingStep { welcome, languages, artists, songs, genres, review }

class _OnboardingScreenState extends State<OnboardingScreen> {
  _OnboardingStep _step = _OnboardingStep.welcome;

  final Set<String> _selectedLanguages = {};
  final Set<String> _selectedArtists = {};
  final Set<String> _selectedGenres = {};
  final Map<String, Map<String, dynamic>> _selectedSongs = {};

  final TextEditingController _languageFilterCtrl = TextEditingController();
  final TextEditingController _artistFilterCtrl = TextEditingController();
  final TextEditingController _songSearchCtrl = TextEditingController();
  final TextEditingController _genreFilterCtrl = TextEditingController();

  Timer? _songDebounce;
  bool _songSearching = false;
  bool _songSearchFailed = false;
  List<Map<String, dynamic>> _songResults = const [];

  static const _languages = [
    'Hindi',
    'Punjabi',
    'English',
    'Tamil',
    'Telugu',
    'Bengali',
    'Marathi',
    'Gujarati',
  ];

  static const Map<String, String> _genreEmoji = {
    'Romantic': '❤️',
    'Bollywood': '🎬',
    'Punjabi': '🎉',
    'Sad': '💧',
    'Party': '🪩',
    'Workout': '💪',
    'Chill': '😌',
    'Lo-Fi': '🌙',
    'Devotional': '🕉️',
    'Indie': '🎸',
    'Hip-Hop': '🎤',
    'Rock': '🤘',
    'Pop': '✨',
  };

  static const List<String> _genres = [
    'Romantic',
    'Bollywood',
    'Punjabi',
    'Sad',
    'Party',
    'Workout',
    'Chill',
    'Lo-Fi',
    'Devotional',
    'Indie',
    'Hip-Hop',
    'Rock',
  ];

  /// Curated starter artists per supported language — instantly available
  /// (no network), aligned with the app's existing language taxonomy. The
  /// free-search field covers everything else.
  static const Map<String, List<String>> _artistsByLanguage = {
    'Hindi': [
      'Arijit Singh',
      'Pritam',
      'Shreya Ghoshal',
      'A.R. Rahman',
      'Neha Kakkar',
      'Badshah',
      'Atif Aslam',
      'Jubin Nautiyal',
      'Sunidhi Chauhan',
      'Vishal-Shekhar',
    ],
    'Punjabi': [
      'Diljit Dosanjh',
      'Karan Aujla',
      'Sidhu Moose Wala',
      'AP Dhillon',
      'Ammy Virk',
      'B Praak',
      'Shubh',
      'Nimrat Khaira',
      'Gippy Grewal',
    ],
    'English': [
      'Ed Sheeran',
      'Taylor Swift',
      'The Weeknd',
      'Dua Lipa',
      'Coldplay',
      'Bruno Mars',
      'Billie Eilish',
      'Adele',
      'Justin Bieber',
      'Ariana Grande',
    ],
    'Tamil': [
      'Anirudh Ravichander',
      'A.R. Rahman',
      'Sid Sriram',
      'Hariharan',
      'Yuvan Shankar Raja',
    ],
    'Telugu': [
      'Devi Sri Prasad',
      'Thaman S',
      'S. P. Balasubrahmanyam',
      'Sid Sriram',
    ],
    'Bengali': [
      'Anupam Roy',
      'Rupam Islam',
      'Jeet Gannguli',
    ],
    'Marathi': ['Ajay-Atul', 'Swapnil Bandodkar', 'Avadhoot Gupte'],
    'Gujarati': ['Falguni Pathak', 'Geeta Rabari', 'Kirtidan Gadhvi'],
  };

  int get _stepIndex => _step.index;
  static const int _stepCount = 6;

  @override
  void dispose() {
    _songDebounce?.cancel();
    _languageFilterCtrl.dispose();
    _artistFilterCtrl.dispose();
    _songSearchCtrl.dispose();
    _genreFilterCtrl.dispose();
    super.dispose();
  }

  void _goTo(_OnboardingStep step) {
    setState(() => _step = step);
  }

  void _next() {
    final next = _OnboardingStep.values[_stepIndex + 1];
    _goTo(next);
  }

  Future<void> _finish() async {
    final songs = _selectedSongs.values
        .map((t) => FavoriteSong(
              id: (t['id'] as String?) ?? '',
              title: (t['title'] as String?) ?? '',
              artist: (t['artist'] as String?) ?? '',
            ))
        .where((s) => s.id.isNotEmpty && s.title.isNotEmpty)
        .toList();

    await PersonalizationStore.instance.completeOnboarding(
      languages: _selectedLanguages.toList(),
      genres: _selectedGenres.toList(),
      artists: _selectedArtists.toList(),
      songs: songs,
    );
    widget.onComplete();
  }

  Future<void> _skip() async {
    if (_selectedLanguages.isNotEmpty ||
        _selectedGenres.isNotEmpty ||
        _selectedArtists.isNotEmpty ||
        _selectedSongs.isNotEmpty) {
      await _finish();
    } else {
      await PersonalizationStore.instance.markOnboardedSkipped();
      widget.onComplete();
    }
  }

  // ── song search (debounced, failure-tolerant) ───────────────────────────

  void _onSongQueryChanged(String q) {
    _songDebounce?.cancel();
    final query = q.trim();
    if (query.length < 2 || widget.songSearch == null) {
      setState(() {
        _songSearching = false;
        _songResults = const [];
      });
      return;
    }
    setState(() {
      _songSearching = true;
      _songSearchFailed = false;
    });
    _songDebounce = Timer(const Duration(milliseconds: 450), () async {
      final results = await widget.songSearch!(query).catchError((_) {
        if (mounted) {
          setState(() => _songSearchFailed = true);
        }
        return const <Map<String, dynamic>>[];
      });
      if (!mounted) return;
      setState(() {
        // Authoritative blocked-channel filter INSIDE the picker too — even
        // an injected/legacy search source can never offer blocked content.
        _songResults = results
            .where(BlockedChannelRegistry.isContentAllowed)
            .take(12)
            .toList();
        _songSearching = false;
      });
    });
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canSkip =
        _step != _OnboardingStep.welcome && _step != _OnboardingStep.review;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── header: progress + back + skip ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  if (_stepIndex > 0)
                    _RoundIconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => _goTo(
                        _OnboardingStep.values[_stepIndex - 1],
                      ),
                    )
                  else
                    const SizedBox(width: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (_stepIndex + 1) / _stepCount,
                        minHeight: 6,
                        backgroundColor: AppColors.surface2,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (canSkip)
                    TextButton(
                      onPressed: _skip,
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    const SizedBox(width: 60),
                ],
              ),
            ),
            // ── body ─────────────────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _buildStep(),
                ),
              ),
            ),
            // ── footer CTA ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AppButton(
                text: switch (_step) {
                  _OnboardingStep.welcome => 'Get Started',
                  _OnboardingStep.review => 'Finish',
                  _ => 'Continue',
                },
                onPressed: _step == _OnboardingStep.review ? _finish : _next,
                isFullWidth: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      _OnboardingStep.welcome => _buildWelcome(),
      _OnboardingStep.languages => _buildChipStep(
          title: 'Pick your languages',
          subtitle: 'Home and Discovery prioritize the languages you love.',
          all: _languages,
          selected: _selectedLanguages,
          filterCtrl: _languageFilterCtrl,
          filterHint: 'Search languages',
          onClear: () => setState(_selectedLanguages.clear),
        ),
      _OnboardingStep.artists => _buildArtistsStep(),
      _OnboardingStep.songs => _buildSongsStep(),
      _OnboardingStep.genres => _buildChipStep(
          title: 'Pick your moods & genres',
          subtitle: 'These shape your daily mixes and recommendations.',
          all: _genres,
          selected: _selectedGenres,
          filterCtrl: _genreFilterCtrl,
          filterHint: 'Search genres',
          emoji: _genreEmoji,
          onClear: () => setState(_selectedGenres.clear),
        ),
      _OnboardingStep.review => _buildReview(),
    };
  }

  // ── welcome ──────────────────────────────────────────────────────────────

  Widget _buildWelcome() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      children: [
        const SizedBox(height: 32),
        Container(
          width: 92,
          height: 92,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 40,
              ),
            ],
          ),
          child: const Icon(
            Icons.graphic_eq_rounded,
            size: 46,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Music that gets you',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textMain,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tell us your languages, favorite artists and moods — your Home, '
          'Discovery and playlists are built around them from the very first '
          'song. Preferences keep learning as you listen.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 28),
        _featureRow(
          Icons.translate_rounded,
          'Your languages, front and center',
        ),
        _featureRow(
          Icons.person_rounded,
          'Favorite artists seed your mixes',
        ),
        _featureRow(
          Icons.tune_rounded,
          'Editable anytime from Profile',
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => AuthModal.show(context),
            child: const Text(
              'I already have an account — sign in',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryLight),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMain,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ── generic chip step (languages / genres) ───────────────────────────────

  Widget _buildChipStep({
    required String title,
    required String subtitle,
    required List<String> all,
    required Set<String> selected,
    required TextEditingController filterCtrl,
    required String filterHint,
    Map<String, String>? emoji,
    required VoidCallback onClear,
  }) {
    final query = filterCtrl.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? all
        : all.where((e) => e.toLowerCase().contains(query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: _StepHeader(
            title: title,
            subtitle: subtitle,
            selectedCount: selected.length,
            onClear: selected.isEmpty ? null : onClear,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AppTextInput(
            controller: filterCtrl,
            hintText: filterHint,
            prefixIcon: Icons.search_rounded,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: visible.isEmpty
              ? _emptyFilter(query)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final item in visible)
                        _SelectChip(
                          label: item,
                          emoji: emoji?[item],
                          selected: selected.contains(item),
                          onTap: () => setState(() {
                            if (!selected.remove(item)) selected.add(item);
                          }),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _emptyFilter(String query) => Center(
        child: Text(
          'No matches for "$query"',
          style: const TextStyle(color: AppColors.textSubtle),
        ),
      );

  // ── artists step ────────────────────────────────────────────────────────

  Widget _buildArtistsStep() {
    final query = _artistFilterCtrl.text.trim().toLowerCase();
    final langSections = <_ArtistSection>[];

    if (query.isEmpty) {
      // Curated sections for chosen languages first, then the rest.
      final seen = <String>{};
      for (final lang in _selectedLanguages) {
        final artists =
            (_artistsByLanguage[lang] ?? const []).where(seen.add).toList();
        if (artists.isNotEmpty) {
          langSections.add(_ArtistSection('Popular in $lang', artists));
        }
      }
      if (_selectedLanguages.isEmpty) {
        final top = <String>[];
        for (final list in _artistsByLanguage.values) {
          for (final a in list) {
            if (top.length >= 12) break;
            if (seen.add(a)) top.add(a);
          }
        }
        if (top.isNotEmpty) {
          langSections.add(_ArtistSection('Popular artists', top));
        }
      }
    }

    final customAdd = query.length >= 2 &&
        !_selectedArtists.any(
          (a) => a.toLowerCase() == query,
        ) &&
        !_artistsByLanguage.values
            .any((list) => list.any((a) => a.toLowerCase() == query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: _StepHeader(
            title: 'Favorite artists',
            subtitle: 'Pick a few — or search for anyone. '
                'Choosing languages first shows their top artists.',
            selectedCount: _selectedArtists.length,
            onClear: _selectedArtists.isEmpty
                ? null
                : () => setState(_selectedArtists.clear),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AppTextInput(
            controller: _artistFilterCtrl,
            hintText: 'Search artists',
            prefixIcon: Icons.search_rounded,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedArtists.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final artist in _selectedArtists)
                  _SelectChip(
                    label: artist,
                    selected: true,
                    onTap: () => setState(
                      () => _selectedArtists.remove(artist),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: query.isNotEmpty && query.length < 2
              ? _emptyFilter(query)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  children: [
                    if (query.isEmpty && langSections.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text(
                          'Search any artist above to add them.',
                          style: TextStyle(color: AppColors.textSubtle),
                        ),
                      ),
                    for (final section in langSections) ...[
                      _sectionLabel(section.title),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final artist in section.artists)
                            _SelectChip(
                              label: artist,
                              selected: _selectedArtists.contains(artist),
                              onTap: () => setState(() {
                                if (!_selectedArtists.remove(artist)) {
                                  _selectedArtists.add(artist);
                                }
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (customAdd)
                      _SelectChip(
                        label: 'Add "${_artistFilterCtrl.text.trim()}"',
                        selected: false,
                        icon: Icons.add_rounded,
                        onTap: () {
                          final name = _artistFilterCtrl.text.trim();
                          if (name.isEmpty) return;
                          setState(() {
                            _selectedArtists.add(name);
                            _artistFilterCtrl.clear();
                          });
                        },
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  // ── songs step ──────────────────────────────────────────────────────────

  Widget _buildSongsStep() {
    final hasSearch = widget.songSearch != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: _StepHeader(
            title: 'Seed with favorite songs',
            subtitle: 'Optional — pick songs you love and your feed starts '
                'from there. You can skip this entirely.',
            selectedCount: _selectedSongs.length,
            onClear: _selectedSongs.isEmpty
                ? null
                : () => setState(_selectedSongs.clear),
          ),
        ),
        if (!hasSearch)
          Padding(
            padding: const EdgeInsets.all(24),
            child: _infoCard(
              'Song picks are unavailable right now — everything else still '
              'works. You can favorite songs anytime from the player.',
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppTextInput(
              controller: _songSearchCtrl,
              hintText: 'Search songs or artists',
              prefixIcon: Icons.search_rounded,
              onChanged: _onSongQueryChanged,
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedSongs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final song in _selectedSongs.values)
                    _SelectChip(
                      label: song['title'] as String? ?? '',
                      selected: true,
                      onTap: () => setState(
                        () => _selectedSongs.remove(song['id']),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _songSearching
                ? ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: List.generate(5, (_) => const _SongRowSkeleton()),
                  )
                : _songSearchFailed
                    ? Center(
                        child: _infoCard(
                          'Search is not reachable right now. Continue — you '
                          'can add favorites later from the player.',
                        ),
                      )
                    : _songResults.isEmpty
                        ? Center(
                            child: Text(
                              _songSearchCtrl.text.trim().length < 2
                                  ? 'Type at least 2 letters to search.'
                                  : 'No songs found.',
                              style: const TextStyle(
                                color: AppColors.textSubtle,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                            itemCount: _songResults.length,
                            itemBuilder: (context, i) {
                              final track = _songResults[i];
                              final id = track['id'] as String? ?? '';
                              final isSel = _selectedSongs.containsKey(id);
                              return _SongResultTile(
                                track: track,
                                selected: isSel,
                                onTap: () => setState(() {
                                  if (isSel) {
                                    _selectedSongs.remove(id);
                                  } else if (id.isNotEmpty) {
                                    _selectedSongs[id] = track;
                                  }
                                }),
                              );
                            },
                          ),
          ),
        ],
      ],
    );
  }

  // ── review ──────────────────────────────────────────────────────────────

  Widget _buildReview() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      children: [
        Text(
          'Your taste profile',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textMain,
              ),
        ),
        const SizedBox(height: 6),
        const Text(
          'This is what shapes your Home, Discovery and playlists. '
          'Everything stays editable from Profile.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),
        _reviewSection(
          icon: Icons.translate_rounded,
          title: 'Languages',
          values: _selectedLanguages.toList(),
          emptyHint: 'None selected',
          onEdit: () => _goTo(_OnboardingStep.languages),
        ),
        _reviewSection(
          icon: Icons.person_rounded,
          title: 'Artists',
          values: _selectedArtists.toList(),
          emptyHint: 'None selected',
          onEdit: () => _goTo(_OnboardingStep.artists),
        ),
        _reviewSection(
          icon: Icons.music_note_rounded,
          title: 'Seed songs',
          values: _selectedSongs.values
              .map((s) => s['title'] as String? ?? '')
              .toList(),
          emptyHint: 'None selected',
          onEdit: () => _goTo(_OnboardingStep.songs),
        ),
        _reviewSection(
          icon: Icons.tune_rounded,
          title: 'Moods & genres',
          values: _selectedGenres.toList(),
          emptyHint: 'None selected',
          onEdit: () => _goTo(_OnboardingStep.genres),
        ),
      ],
    );
  }

  Widget _reviewSection({
    required IconData icon,
    required String title,
    required List<String> values,
    required String emptyHint,
    required VoidCallback onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surface2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                child: const Text(
                  'Edit',
                  style: TextStyle(color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (values.isEmpty)
            Text(emptyHint, style: const TextStyle(color: AppColors.textSubtle))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in values.take(10))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      v,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                if (values.length > 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '+${values.length - 10} more',
                      style: const TextStyle(color: AppColors.textSubtle),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _infoCard(String message) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surface2),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.warning, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: AppColors.textSecondary, height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      );
}

class _ArtistSection {
  const _ArtistSection(this.title, this.artists);
  final String title;
  final List<String> artists;
}

// ── small building blocks ──────────────────────────────────────────────────

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: AppColors.textSecondary),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.title,
    required this.subtitle,
    required this.selectedCount,
    this.onClear,
  });

  final String title;
  final String subtitle;
  final int selectedCount;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (selectedCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$selectedCount',
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onClear != null)
              TextButton(
                onPressed: onClear,
                child: const Text(
                  'Clear',
                  style: TextStyle(color: AppColors.textSubtle, fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.emoji,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface2,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
              ],
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textMain,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SongResultTile extends StatelessWidget {
  const _SongResultTile({
    required this.track,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> track;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = track['title'] as String? ?? '';
    final artist = track['artist'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: AppColors.primaryLight,
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
                          color: AppColors.textMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSubtle,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color:
                      selected ? AppColors.primaryLight : AppColors.textSubtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SongRowSkeleton extends StatelessWidget {
  const _SongRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          LoadingSkeleton(width: 44, height: 44, borderRadius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingSkeleton(height: 14, width: 220),
                SizedBox(height: 6),
                LoadingSkeleton(height: 11, width: 130),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
