// ════════════════════════════════════════════════
// Project Lyra — Settings Screen
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/extensions/color_extension.dart';
import '../../../../config/theme/extensions/theme_extension.dart';
import '../../domain/entities/settings_entities.dart';

/// Settings screen — app preferences.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Appearance section
          _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Theme'),
            subtitle: const Text('Dark'),
            onTap: () => _showThemeDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: const Text('English'),
            onTap: () {},
          ),

          // Audio section
          _SectionHeader(title: 'Audio'),
          ListTile(
            leading: const Icon(Icons.high_quality),
            title: const Text('Streaming Quality'),
            subtitle: const Text('High (256 kbps)'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Download Quality'),
            subtitle: const Text('High (256 kbps)'),
            onTap: () {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.equalizer),
            title: const Text('Gapless Playback'),
            value: true,
            onChanged: (v) {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.swap_horiz),
            title: const Text('Crossfade'),
            value: false,
            onChanged: (v) {},
          ),

          // Downloads section
          _SectionHeader(title: 'Downloads'),
          SwitchListTile(
            secondary: const Icon(Icons.wifi),
            title: const Text('Download over Wi-Fi only'),
            value: true,
            onChanged: (v) {},
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Storage'),
            subtitle: const Text('1.2 GB used'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear Cache'),
            onTap: () {},
          ),

          // Notifications section
          _SectionHeader(title: 'Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Push Notifications'),
            value: true,
            onChanged: (v) {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.new_releases_outlined),
            title: const Text('New Releases'),
            value: true,
            onChanged: (v) {},
          ),

          // Content section
          _SectionHeader(title: 'Content'),
          SwitchListTile(
            secondary: const Icon(Icons.explicit),
            title: const Text('Show Explicit Content'),
            value: true,
            onChanged: (v) {},
          ),

          // About section
          _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('0.1.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () {},
          ),
          SizedBox(height: lyra.spacingXxl),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              value: ThemeMode.system,
              groupValue: ThemeMode.dark,
              onChanged: (_) {},
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: ThemeMode.dark,
              onChanged: (_) {},
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: ThemeMode.dark,
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final lyra = context.lyra;
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.fromLTRB(lyra.spacingMd, lyra.spacingLg, lyra.spacingMd, lyra.spacingSm),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
