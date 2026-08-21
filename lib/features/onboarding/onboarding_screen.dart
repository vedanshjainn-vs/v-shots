// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Onboarding Screen (Nova Design System + taste personalization)
// ═════════════════════════════════════════════════════════════════════════════
//
// Welcome carousel (3 slides) + a final "personalize" step where the user
// picks languages and moods/genres. Those choices are persisted to
// PersonalizationStore and seed the RecommendationEngine's COLD-START
// candidate generation, so a brand-new user gets a Home/Discovery shaped by
// their stated taste instead of a completely generic feed. Skipping is
// always allowed (no preferences → the engine's regional/global defaults).
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../core/storage/personalization_store.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../auth/auth_modal.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final Set<String> _selectedLanguages = {};
  final Set<String> _selectedGenres = {};

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

  static const _genres = [
    'Romantic',
    'Punjabi',
    'Bollywood',
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

  static const int _personalizePage = 3;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Discover Your Next Song',
      'subtitle':
          'Explore trending music, new releases, timeless hits, and songs picked for your taste — all in one place.',
      'icon': Icons.music_note_rounded,
      'gradient': AppColors.primaryGradient,
    },
    {
      'title': 'Music That Gets You',
      'subtitle':
          'V SHOTS learns what you listen to and helps you discover songs, artists, moods, and sounds you\u2019ll actually love.',
      'icon': Icons.graphic_eq_rounded,
      'gradient': const LinearGradient(
        colors: [AppColors.accent, AppColors.primaryLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'title': 'Explore Without Limits',
      'subtitle':
          'Discover music by mood, language, genre, region, artists, and what\u2019s trending right now.',
      'icon': Icons.public_rounded,
      'gradient': const LinearGradient(
        colors: [AppColors.hotPink, AppColors.warning],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
  ];

  Future<void> _finish() async {
    await PersonalizationStore.instance.completeOnboarding(
      languages: _selectedLanguages.toList(),
      genres: _selectedGenres.toList(),
    );
    widget.onComplete();
  }

  void _next() {
    if (_currentPage < _personalizePage) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPersonalize = _currentPage == _personalizePage;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.1),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'V SHOTS',
                            style: TextStyle(
                              color: AppColors.textMain,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _finish,
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemCount: _pages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _personalizePage) {
                        return _buildPersonalizePage();
                      }
                      final p = _pages[index];
                      return _buildWelcomeSlide(p);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length + 1,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: _currentPage == index
                                  ? AppColors.primaryGradient
                                  : null,
                              color: _currentPage == index
                                  ? null
                                  : AppColors.surface2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        text: isPersonalize ? 'Get Started' : 'Continue',
                        isFullWidth: true,
                        size: AppButtonSize.large,
                        onPressed: _next,
                      ),
                      const SizedBox(height: 12),
                      if (!isPersonalize)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => AuthModal.show(context),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSlide(Map<String, dynamic> p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: p['gradient'] as Gradient,
              boxShadow: [
                BoxShadow(
                  color: (p['gradient'] as LinearGradient).colors.first
                      .withValues(alpha: 0.35),
                  blurRadius: 36,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Center(
              child: Icon(p['icon'] as IconData, size: 64, color: Colors.white),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            p['title'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            p['subtitle'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personalize your feed',
            style: TextStyle(
              color: AppColors.textMain,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pick what you love — we\u2019ll shape your Home and Discovery around it. You can change this anytime in Settings.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Languages',
            style: TextStyle(
              color: AppColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _languages
                .map(
                  (l) => _chip(
                    label: l,
                    selected: _selectedLanguages.contains(l),
                    onTap: () => setState(() {
                      if (!_selectedLanguages.remove(l)) {
                        _selectedLanguages.add(l);
                      }
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 22),
          const Text(
            'Moods & genres',
            style: TextStyle(
              color: AppColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genres
                .map(
                  (g) => _chip(
                    label: g,
                    selected: _selectedGenres.contains(g),
                    onTap: () => setState(() {
                      if (!_selectedGenres.remove(g)) {
                        _selectedGenres.add(g);
                      }
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryLight : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
