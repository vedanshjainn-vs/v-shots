// ═════════════════════════════════════════════════════════════════════════
// V Shots — Content Preferences Onboarding (Phase 1)
//
// One-time, first-install screen. Asks:
//   1. Country
//   2. Preferred music languages (multi-select, country-aware defaults)
//   3. Preferred genres/vibes (optional but recommended)
// On completion it saves UserPreferences locally (and syncs to Supabase when
// signed in). It never re-shows once completed.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/backend/supabase_sync_service.dart';
import '../../core/preferences/user_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';

class ContentPreferencesOnboarding extends StatefulWidget {
  const ContentPreferencesOnboarding({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<ContentPreferencesOnboarding> createState() =>
      _ContentPreferencesOnboardingState();
}

class _ContentPreferencesOnboardingState
    extends State<ContentPreferencesOnboarding> {
  int _step = 0; // 0 = country, 1 = languages, 2 = genres
  String _country = 'India';
  final Set<String> _languages = {};
  final Set<String> _genres = {};

  static const _countries = [
    'India',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'Pakistan',
    'Bangladesh',
    'Nepal',
    'UAE',
    'Saudi Arabia',
    'Other',
  ];

  static const _languagesByCountry = {
    'India': [
      'Hindi',
      'Punjabi',
      'English',
      'Tamil',
      'Telugu',
      'Bengali',
      'Marathi',
      'Gujarati',
      'Kannada',
      'Malayalam',
      'Urdu',
      'Other'
    ],
    'Pakistan': ['Urdu', 'Punjabi', 'English', 'Other'],
    'Bangladesh': ['Bengali', 'English', 'Other'],
    'Nepal': ['Nepali', 'English', 'Other'],
    'UAE': ['English', 'Arabic', 'Hindi', 'Urdu', 'Other'],
    'Saudi Arabia': ['Arabic', 'English', 'Other'],
  };

  static const kGenres = [
    'Bollywood',
    'Punjabi',
    'Pop',
    'Hip-Hop',
    'Romantic',
    'Chill',
    'Workout',
    'Devotional',
    'Indie',
    'EDM',
    'Rock',
    'Classical',
    'Lo-fi',
    'Sad',
    'Party',
  ];

  List<String> get _languagesForCountry =>
      _languagesByCountry[_country] ?? ['English', 'Other'];

  bool _saving = false;

  Future<void> _finish() async {
    // Guard against double-taps causing the "Finish does nothing" bug.
    if (_saving) return;
    _saving = true;

    final prefs = UserPreferences(
      country: _country,
      languages: _languages.isEmpty ? ['English'] : _languages.toList(),
      genres: _genres.toList(),
      vibes: _genres.toList(),
      onboardingCompleted: true,
    );
    // Await the local save so navigation only happens after persistence.
    await PreferencesStore.instance.save(prefs);

    // Phase 18: background sync when signed in (non-blocking, never blocks nav).
    unawaited(
      SupabaseSyncService.instance.syncPreferences(
        country: prefs.country,
        languages: prefs.languages,
        genres: prefs.genres,
        vibes: prefs.vibes,
        onboardingCompleted: prefs.onboardingCompleted,
      ),
    );

    // Always navigate regardless of Supabase/API availability.
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (_step + 1) / 3,
                backgroundColor: AppColors.surface,
                color: AppColors.accent,
              ),
              const SizedBox(height: 24),
              Text(
                _step == 0
                    ? 'Where are you from?'
                    : _step == 1
                        ? 'Choose your music languages'
                        : 'What music do you like?',
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _step == 2
                    ? 'Optional but recommended — helps us personalize.'
                    : 'You can change this anytime in Settings.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildStep()),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: AppButton(
                        text: 'Back',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => setState(() => _step--),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      text: _step < 2 ? 'Next' : 'Finish',
                      icon: _step < 2
                          ? Icons.arrow_forward_rounded
                          : Icons.check_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: () {
                        if (_step < 2) {
                          setState(() => _step++);
                        } else {
                          unawaited(_finish());
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    if (_step == 0) {
      return _choiceGrid(
        items: _countries,
        selected: {_country},
        onTap: (c) => setState(() {
          _country = c;
          _languages.clear();
        }),
        singleSelect: true,
      );
    }
    if (_step == 1) {
      return _choiceGrid(
        items: _languagesForCountry,
        selected: _languages,
        onTap: (l) => setState(() {
          _languages.contains(l) ? _languages.remove(l) : _languages.add(l);
        }),
      );
    }
    return _choiceGrid(
      items: kGenres,
      selected: _genres,
      onTap: (g) => setState(() {
        _genres.contains(g) ? _genres.remove(g) : _genres.add(g);
      }),
    );
  }

  Widget _choiceGrid({
    required List<String> items,
    required Set<String> selected,
    required void Function(String) onTap,
    bool singleSelect = false,
  }) {
    return GridView.builder(
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        final isSel = selected.contains(item);
        return GestureDetector(
          onTap: () => onTap(item),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSel
                  ? AppColors.accent.withValues(alpha: 0.2)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSel ? AppColors.accent : AppColors.border,
                width: isSel ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSel) ...[
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.accent, size: 16),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    item,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSel ? AppColors.accent : AppColors.textMain,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
