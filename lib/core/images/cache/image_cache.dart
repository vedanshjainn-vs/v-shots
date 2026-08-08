// ════════════════════════════════════════════════
// Project Lyra — Image Cache
// ════════════════════════════════════════════════
//
// Two-tier image cache:
// - Memory: LRU byte buffer (fast, RAM-limited)
// - Disk: Persistent file cache (slower, large capacity)
// ════════════════════════════════════════════════

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../logging/app_logger.dart';

/// Two-tier image cache with memory and disk layers.
///
/// Memory cache is an LRU byte buffer for hot images.
/// Disk cache persists across app restarts.
///
/// ```dart
/// final cache = ImageCache();
/// await cache.initialize();
///
/// // Put image bytes.
/// await cache.put('https://...', imageBytes);
///
/// // Get from memory first, then disk.
/// final bytes = await cache.get('https://...');
/// ```
class ImageCacheService {
  ImageCacheService({
    this.maxMemoryEntries = 200,
    this.maxMemorySizeBytes = 50 * 1024 * 1024, // 50 MB
    this.maxDiskSizeBytes = 200 * 1024 * 1024, // 200 MB
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final int maxMemoryEntries;
  final int maxMemorySizeBytes;
  final int maxDiskSizeBytes;
  final AppLogger _logger;

  // ── Memory Cache (LRU) ───────────────────────
  final LinkedHashMap<String, Uint8List> _memoryCache = LinkedHashMap();
  int _currentMemorySize = 0;
  String? _diskCachePath;

  /// Initialize the image cache (create disk directory).
  Future<void> initialize() async {
    try {
      final dir = await getTemporaryDirectory();
      _diskCachePath = '${dir.path}/lyra_image_cache';
      final cacheDir = Directory(_diskCachePath!);
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      _logger.d('ImageCache: Initialized at $_diskCachePath');
    } catch (e, st) {
      _logger.e('ImageCache: Init failed', error: e, stackTrace: st);
    }
  }

  // ── Read ─────────────────────────────────────

  /// Get image bytes from cache (memory first, then disk).
  Future<Uint8List?> get(String url) async {
    final key = _hashKey(url);

    // Layer 1: Memory.
    final memResult = _memoryCache.remove(key);
    if (memResult != null) {
      // Move to front (most recently used).
      _memoryCache[key] = memResult;
      return memResult;
    }

    // Layer 2: Disk.
    final diskResult = await _getFromDisk(key);
    if (diskResult != null) {
      // Promote to memory.
      _putInMemory(key, diskResult);
      return diskResult;
    }

    return null;
  }

  // ── Write ────────────────────────────────────

  /// Put image bytes into both cache layers.
  Future<void> put(String url, Uint8List data) async {
    final key = _hashKey(url);

    // Layer 1: Memory.
    _putInMemory(key, data);

    // Layer 2: Disk.
    await _putOnDisk(key, data);
  }

  /// Prefetch an image from a URL into cache.
  Future<bool> prefetch(String url) async {
    try {
      final file = File('${_diskCachePath}/${_hashKey(url)}');
      if (await file.exists()) return true;

      // TODO(team): Use Dio to download and cache.
      return false;
    } catch (e) {
      return false;
    }
  }

  // ── Invalidate ───────────────────────────────

  /// Remove an image from both cache layers.
  Future<void> remove(String url) async {
    final key = _hashKey(url);
    _memoryCache.remove(key);
    _currentMemorySize -= 0; // Size tracking simplified.

    await _removeFromDisk(key);
  }

  /// Clear all cached images.
  Future<void> clear() async {
    _memoryCache.clear();
    _currentMemorySize = 0;

    if (_diskCachePath != null) {
      final dir = Directory(_diskCachePath!);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    }
  }

  /// Clean up disk cache to stay within size limit.
  Future<void> cleanup() async {
    if (_diskCachePath == null) return;

    try {
      final dir = Directory(_diskCachePath!);
      if (!await dir.exists()) return;

      final files = await dir.list().toList();
      int totalSize = 0;
      final fileSizes = <(File, int)>[];

      for (final entity in files) {
        if (entity is File) {
          final size = await entity.length();
          totalSize += size;
          fileSizes.add((entity, size));
        }
      }

      if (totalSize <= maxDiskSizeBytes) return;

      // Sort by modification time (oldest first).
      fileSizes.sort((a, b) =>
          a.$1.lastModifiedSync().compareTo(b.$1.lastModifiedSync()));

      // Delete oldest files until under limit.
      for (final (file, size) in fileSizes) {
        if (totalSize <= maxDiskSizeBytes) break;
        await file.delete();
        totalSize -= size;
        _logger.d('ImageCache: Evicted ${file.path}');
      }
    } catch (e, st) {
      _logger.e('ImageCache: Cleanup failed', error: e, stackTrace: st);
    }
  }

  /// Get cache statistics.
  Future<ImageCacheStats> getStats() async {
    int diskSize = 0;
    int diskCount = 0;

    if (_diskCachePath != null) {
      final dir = Directory(_diskCachePath!);
      if (await dir.exists()) {
        final files = await dir.list().toList();
        for (final entity in files) {
          if (entity is File) {
            diskSize += await entity.length();
            diskCount++;
          }
        }
      }
    }

    return ImageCacheStats(
      memoryEntries: _memoryCache.length,
      memorySizeBytes: _currentMemorySize,
      diskEntries: diskCount,
      diskSizeBytes: diskSize,
    );
  }

  // ── Private Helpers ──────────────────────────

  void _putInMemory(String key, Uint8List data) {
    // Evict LRU entries if over capacity.
    while (_memoryCache.length >= maxMemoryEntries ||
        _currentMemorySize + data.length > maxMemorySizeBytes) {
      if (_memoryCache.isEmpty) break;
      final removedKey = _memoryCache.keys.first;
      final removed = _memoryCache.remove(removedKey);
      if (removed != null) _currentMemorySize -= removed.length;
    }

    _memoryCache[key] = data;
    _currentMemorySize += data.length;
  }

  Future<Uint8List?> _getFromDisk(String key) async {
    if (_diskCachePath == null) return null;

    try {
      final file = File('$_diskCachePath/$key');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      _logger.w('ImageCache: Disk read failed for $key');
    }
    return null;
  }

  Future<void> _putOnDisk(String key, Uint8List data) async {
    if (_diskCachePath == null) return;

    try {
      final file = File('$_diskCachePath/$key');
      await file.writeAsBytes(data);
    } catch (e) {
      _logger.w('ImageCache: Disk write failed for $key');
    }
  }

  Future<void> _removeFromDisk(String key) async {
    if (_diskCachePath == null) return;

    try {
      final file = File('$_diskCachePath/$key');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      _logger.w('ImageCache: Disk delete failed for $key');
    }
  }

  /// Hash a URL to create a safe filename.
  String _hashKey(String url) {
    // Simple hash — use crypto.sha256 for production.
    return url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').substring(
        0, url.length > 100 ? 100 : url.length);
  }
}

/// Image cache statistics.
class ImageCacheStats {
  const ImageCacheStats({
    required this.memoryEntries,
    required this.memorySizeBytes,
    required this.diskEntries,
    required this.diskSizeBytes,
  });

  final int memoryEntries;
  final int memorySizeBytes;
  final int diskEntries;
  final int diskSizeBytes;

  double get memorySizeMB => memorySizeBytes / (1024 * 1024);
  double get diskSizeMB => diskSizeBytes / (1024 * 1024);
}
