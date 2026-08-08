// ════════════════════════════════════════════════
// Project Lyra — Search Input
// ════════════════════════════════════════════════
//
// Premium search bar with glass effect,
// voice input, and AI search toggle.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../config/theme/extensions/color_extension.dart';
import '../../../config/theme/extensions/theme_extension.dart';

/// Styled search input field.
///
/// Supports:
/// - Debounced text input
/// - Voice search button
/// - AI search toggle
/// - Clear button
class SearchInput extends StatelessWidget {
  const SearchInput({
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onVoiceTap,
    this.onAITap,
    this.hintText = 'Search songs, artists, podcasts...',
    this.showAIButton = false,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onVoiceTap;
  final VoidCallback? onAITap;
  final String hintText;
  final bool showAIButton;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lyra = context.lyra;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(lyra.radiusLarge),
      ),
      child: Row(
        children: [
          SizedBox(width: lyra.spacingMd),
          Icon(
            Icons.search_rounded,
            color: colors.onSurfaceVariant,
            size: 22,
          ),
          SizedBox(width: lyra.spacingSm),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              autofocus: autofocus,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          if (showAIButton) ...[
            GestureDetector(
              onTap: onAITap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: lyra.gradientAccent,
                  borderRadius: BorderRadius.circular(lyra.radiusCircular),
                ),
                child: Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SizedBox(width: lyra.spacingSm),
          ],
          if (onVoiceTap != null)
            GestureDetector(
              onTap: onVoiceTap,
              child: Icon(
                Icons.mic_rounded,
                color: colors.onSurfaceVariant,
                size: 20,
              ),
            ),
          SizedBox(width: lyra.spacingMd),
        ],
      ),
    );
  }
}
