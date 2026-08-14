// ═════════════════════════════════════════════════════════════════════════════
// V Shots — SettingsScreen (Nova Design System)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/backend/auth_service.dart';
import '../../core/backend/supabase_service.dart';
import '../onboarding/content_preferences_onboarding.dart';
import '../../main.dart' show resetHomeContentForPreferenceChange;
import '../../core/cache/search_cache.dart';
import '../../core/motion/motion.dart';
import '../../core/player/sleep_timer.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../auth/auth_modal.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _handleSignOut() async {
    await AuthService.instance.signOut();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed out of V Shots.'),
          backgroundColor: AppColors.surface2,
        ),
      );
      setState(() {});
    }
  }

  void _showDeleteAccountDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to delete your V Shots account and all associated shots, likes, and bookmarks? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              nav.pop();
              await _handleSignOut();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Account deletion requested.'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            child: const Text(
              'Delete Permanently',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = SupabaseService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textMain,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings & Privacy',
          style: TextStyle(
            color: AppColors.textMain,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Account Card
          const _SectionHeader('Account'),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser != null
                                ? (currentUser.email ?? 'V Shots User')
                                : 'Guest User',
                            style: const TextStyle(
                              color: AppColors.textMain,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentUser != null
                                ? 'Supabase Authenticated'
                                : 'Offline / Guest Session',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (currentUser == null)
                  AppButton(
                    text: 'Sign In / Register',
                    isFullWidth: true,
                    size: AppButtonSize.medium,
                    onPressed: () async {
                      await AuthModal.show(context);
                      setState(() {});
                    },
                  )
                else
                  AppButton(
                    text: 'Sign Out',
                    variant: AppButtonVariant.outline,
                    isFullWidth: true,
                    size: AppButtonSize.medium,
                    onPressed: _handleSignOut,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Content Preferences (Phase 19)
          const _SectionHeader('Content'),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.public_rounded,
                color: AppColors.accent,
              ),
              title: const Text(
                'Content Preferences',
                style: TextStyle(color: AppColors.textMain, fontSize: 15),
              ),
              subtitle: const Text(
                'Country, languages, genres & vibes',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textSubtle,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ContentPreferencesOnboarding(
                      onComplete: (ctx) {
                        // Phase 19/20: clear Home/Discover caches so the next
                        // load regenerates live, personalized content.
                        resetHomeContentForPreferenceChange();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Playback & Media
          const _SectionHeader('Playback'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.bedtime_outlined,
                    color: AppColors.accent,
                  ),
                  title: const Text(
                    'Sleep Timer',
                    style: TextStyle(color: AppColors.textMain, fontSize: 15),
                  ),
                  subtitle: ValueListenableBuilder<Duration?>(
                    valueListenable: SleepTimer.instance.remaining,
                    builder: (context, remaining, _) => Text(
                      remaining != null
                          ? 'Active — ${remaining.inMinutes}m ${remaining.inSeconds % 60}s remaining'
                          : 'Turn off playback automatically',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  trailing: ValueListenableBuilder<Duration?>(
                    valueListenable: SleepTimer.instance.remaining,
                    builder: (context, remaining, _) => remaining != null
                        ? TextButton(
                            onPressed: () {
                              SleepTimer.instance.cancel();
                              setState(() {});
                            },
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: AppColors.error),
                            ),
                          )
                        : const Icon(
                            Icons.chevron_right,
                            color: AppColors.textSubtle,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Storage & Cache
          const _SectionHeader('Storage & Cache'),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.cached_rounded,
                color: AppColors.primaryLight,
              ),
              title: const Text(
                'Clear Media & Search Cache',
                style: TextStyle(color: AppColors.textMain, fontSize: 15),
              ),
              subtitle: const Text(
                'Frees memory without affecting your Liked Shots or Playlists.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              onTap: () {
                SearchCache.instance.clear();
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cache successfully cleared!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // About & Legal
          const _SectionHeader('About & Legal'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.accent,
                  ),
                  title: Text(
                    'V Shots',
                    style: TextStyle(
                      color: AppColors.textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Version 5.4.0 (Nova Release)',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
                const Divider(color: AppColors.borderSubtle, height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    color: AppColors.textSecondary,
                  ),
                  title: const Text(
                    'Privacy Policy',
                    style: TextStyle(color: AppColors.textMain, fontSize: 15),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSubtle,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    AppPageRoute<void>(
                      builder: (_) => const LegalDocScreen(
                        title: 'Privacy Policy',
                        assetPath: 'docs/legal/privacy_policy.md',
                      ),
                    ),
                  ),
                ),
                const Divider(color: AppColors.borderSubtle, height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.description_outlined,
                    color: AppColors.textSecondary,
                  ),
                  title: const Text(
                    'Terms of Service',
                    style: TextStyle(color: AppColors.textMain, fontSize: 15),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSubtle,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    AppPageRoute<void>(
                      builder: (_) => const LegalDocScreen(
                        title: 'Terms of Service',
                        assetPath: 'docs/legal/terms_of_service.md',
                      ),
                    ),
                  ),
                ),
                const Divider(color: AppColors.borderSubtle, height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.help_outline_rounded,
                    color: AppColors.textSecondary,
                  ),
                  title: const Text(
                    'Help & Support',
                    style: TextStyle(color: AppColors.textMain, fontSize: 15),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSubtle,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    AppPageRoute<void>(builder: (_) => const HelpScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Danger Zone
          if (currentUser != null) ...[
            const _SectionHeader('Danger Zone'),
            AppCard(
              padding: EdgeInsets.zero,
              color: AppColors.error.withValues(alpha: 0.08),
              child: ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Permanently remove your account and content.',
                  style: TextStyle(color: AppColors.textSubtle, fontSize: 12),
                ),
                onTap: _showDeleteAccountDialog,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({
    required this.title,
    required this.assetPath,
    super.key,
  });

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textMain,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textMain,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                'Could not load $title.',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              snapshot.data!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          );
        },
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _repoUrl = 'https://github.com/vedanshjainn-vs/v-shots';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textMain,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: AppColors.textMain,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'V Shots is an open and social mobile experience built on Flutter and Supabase. '
            'If you encounter an issue or have a feature suggestion, you can reach out or contribute directly via GitHub.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          AppButton(
            text: 'Report an Issue on GitHub',
            icon: Icons.bug_report_outlined,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.large,
            onPressed: () => launchUrl(
              Uri.parse('$_repoUrl/issues/new'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 14),
          AppButton(
            text: 'View Project Source Code',
            icon: Icons.code_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.large,
            onPressed: () => launchUrl(
              Uri.parse(_repoUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    );
  }
}
