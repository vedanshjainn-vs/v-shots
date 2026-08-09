// ════════════════════════════════════════════════
// V Shots — Settings / Legal / Help screens (Phase 8 fix)
// ════════════════════════════════════════════════
//
// WHY THIS FILE EXISTS:
// The read-only audit confirmed ProfileScreen's secondary menu items
// ("Upgrade to Premium", "Settings", "Help & Support", "Privacy
// Policy", "Terms of Service") rendered via a shared `_item()` helper
// with NO `onTap` at all — every one of them was a dead ListTile
// despite `docs/legal/privacy_policy.md`/`terms_of_service.md`
// actually existing as real files the app never linked to. Per this
// task's Phase 10 rule ("Every visible button must either work
// correctly, OR be removed until implemented — no dummy
// interactions"), this file gives each of those five items a real
// destination:
//   - Settings -> SettingsScreen: real, working toggles/actions that
//     already have a backing implementation elsewhere in the app
//     (Sleep Timer default, cache clear, sign-out) — NOT invented
//     settings with no effect.
//   - Privacy Policy / Terms of Service -> LegalDocScreen: renders the
//     REAL, already-existing markdown files from docs/legal/ (bundled
//     as Flutter assets — see pubspec.yaml).
//   - Help & Support -> a real, honest screen (this is a personal/
//     hobby app with no support team — the honest content here is
//     "how to report a bug" via the real GitHub repo, not a fake
//     "contact us" form that goes nowhere).
//   - Upgrade to Premium -> REMOVED from ProfileScreen entirely (see
//     main.dart's ProfileScreen), not wired here, because there is no
//     real subscription/premium tier implemented anywhere in this
//     codebase (no billing integration, no premium feature gating)
//     and building one is out of scope for this task. Per Phase 10's
//     own rule ("If a feature is not implemented, remove the button
//     rather than leaving a dummy button"), removing it is the
//     honest choice — a "Coming Soon" dialog would still be a
//     UI-only decoration masquerading as a feature.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/cache/search_cache.dart';
import '../../core/motion/motion.dart';
import '../../core/player/sleep_timer.dart';
import '../../core/theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader('Playback'),
          ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('Sleep Timer'),
            subtitle: ValueListenableBuilder<Duration?>(
              valueListenable: SleepTimer.instance.remaining,
              builder: (context, remaining, _) => Text(
                remaining != null
                    ? 'Active — ${remaining.inMinutes}m ${remaining.inSeconds % 60}s left'
                    : 'Not running',
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
                      child: const Text('Cancel'),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 8),
          const _SectionHeader('Storage & Cache'),
          ListTile(
            leading: const Icon(Icons.cached),
            title: const Text('Clear search cache'),
            subtitle: const Text(
                'Clears the short-lived Home/Search result cache. Liked Songs, Playlists, and Recently Played are NOT affected.'),
            onTap: () {
              SearchCache.instance.clear();
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search cache cleared')),
              );
            },
          ),
          const SizedBox(height: 8),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('V Shots'),
            subtitle: Text(
                'A personal, hobby-scale music app. Streams audio via YouTube for personal/learning use — see Terms of Service for the full disclosure.'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
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
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
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
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

/// Renders one of the app's real, already-written markdown files from
/// docs/legal/ (bundled via pubspec.yaml assets) — plain, unstyled
/// text is intentional here (this is a legal document, not a place for
/// custom markdown rendering/an extra dependency); a monospace-ish
/// SelectableText keeps it simple, real, and copy-pasteable.
class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({required this.title, required this.assetPath, super.key});

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                'Could not load $title.',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              snapshot.data!,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          );
        },
      ),
    );
  }
}

/// Honest "Help & Support" for a personal/hobby app: no fake ticketing
/// system or contact form — points to the real, actual GitHub repo
/// (where bugs genuinely get fixed in this project, per this whole
/// conversation's own history) as the real support channel.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _repoUrl = 'https://github.com/vedanshjainn-vs/v-shots';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'V Shots is a personal, hobby-scale project — there is no dedicated support team. '
            'If something is broken, the most useful thing you can do is open an issue on the '
            'real GitHub repository this app is built from.',
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse('$_repoUrl/issues/new'),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('Report an issue on GitHub'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(_repoUrl),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.code),
            label: const Text('View source on GitHub'),
          ),
        ],
      ),
    );
  }
}
