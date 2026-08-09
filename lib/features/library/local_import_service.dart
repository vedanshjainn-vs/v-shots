// ════════════════════════════════════════════════
// V Shots — Local Audio Import (the app's "Downloads" feature)
// ════════════════════════════════════════════════
//
// ⚠️ WHAT THIS IS AND ISN'T (read before "improving" this):
// This is NOT a way to download/cache streamed YouTube audio for
// offline playback — that would recreate exactly the illegal pattern
// (unauthorized local copies of copyrighted streamed content) this
// entire project has consistently avoided, and it's explicitly what
// Google Play's Developer Program Policy prohibits ("Streaming apps
// that allow users to download a local copy of copyrighted content
// without authorization").
//
// What this DOES do, which is genuinely legal with zero licensing risk:
// lets the user pick audio files they ALREADY own/have on their device
// (via the system file picker — the same mechanism any file manager or
// media app uses) and add them to the app's library so they show up
// alongside streamed tracks, playable offline because they're just
// local files. This mirrors what real FOSS music apps in this space do
// (Musify's "Cloud Import" feature, referenced during this project's
// earlier research, is the same idea) and what the standalone iOS
// "Lyra" app found in the brand-research phase calls "Import your own
// music files".
// ════════════════════════════════════════════════

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class LocalImportService {
  LocalImportService._();
  static final LocalImportService instance = LocalImportService._();

  static const _audioExtensions = ['mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg'];

  /// Opens the system file picker restricted to common audio formats.
  /// Returns a list of app-track-shaped maps (same shape as the app's
  /// existing YouTube-sourced tracks, so they can flow through the
  /// exact same playback/queue/UI code — see `isLocal`/`localPath` as
  /// the only new fields callers need to branch on).
  Future<List<Map<String, dynamic>>> pickAudioFiles() async {
    try {
      // file_picker v11+ uses static methods directly on FilePicker
      // (breaking change from the older FilePicker.platform.* pattern
      // used pre-11.0.0 — confirmed via the package's own changelog).
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _audioExtensions,
        allowMultiple: true,
      );

      if (result == null) return [];

      return result.files
          .where((f) => f.path != null)
          .map(_fileToTrack)
          .toList();
    } catch (e) {
      debugPrint('[LocalImportService] pickAudioFiles failed: $e');
      return [];
    }
  }

  Map<String, dynamic> _fileToTrack(PlatformFile file) {
    final path = file.path!;
    final nameWithoutExt = file.name.contains('.')
        ? file.name.substring(0, file.name.lastIndexOf('.'))
        : file.name;

    // Best-effort "Artist - Title" split, matching the naming
    // convention most people already use for their own audio files —
    // falls back gracefully to "Unknown Artist" if not present.
    String title = nameWithoutExt;
    String artist = 'Unknown Artist';
    if (nameWithoutExt.contains(' - ')) {
      final parts = nameWithoutExt.split(' - ');
      artist = parts.first.trim();
      title = parts.sublist(1).join(' - ').trim();
    }

    return {
      'id': 'local_${path.hashCode}',
      'title': title,
      'artist': artist,
      'artwork': null,
      'duration': 0,
      'isLocal': true,
      'localPath': path,
    };
  }

  /// True if the given local file still exists on disk — a device
  /// migration, file deletion, or storage cleanup can invalidate a
  /// previously-imported track; callers should check this before
  /// attempting playback and surface a clear "file no longer available"
  /// message rather than a confusing generic playback error.
  bool fileStillExists(String path) => File(path).existsSync();
}
