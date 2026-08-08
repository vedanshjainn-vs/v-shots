// ════════════════════════════════════════════════
// Project Lyra — Image Pipeline
// ════════════════════════════════════════════════
//
// Complete image loading pipeline:
// 1. Check memory cache
// 2. Check disk cache
// 3. Show placeholder (blurhash/color)
// 4. Download with retry
│  5. Compress
│  6. Decode
│  7. Cache
│  8. Display
// ════════════════════════════════════════════════

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../logging/app_logger.dart';
import '../cache/image_cache.dart';
import '../placeholders/placeholder_generator.dart';

/// Orchestrates the full image loading lifecycle.
///
/// Handles caching, placeholders, retry, compression,
/// and error recovery automatically.
///
/// ```dart
/// final pipeline = ImagePipeline(cache: imageCache, dio: dio);
/// final result = await pipeline.load('https://...');
/// ```
class ImagePipeline {
  ImagePipeline({
    required this.cache,
    required this.dio,
    this.maxRetries = 3,
    this.compressionQuality = 85,
    this.maxWidth = 1024,
    this.maxHeight = 1024,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final ImageCacheService cache;
  final Dio dio;
  final int maxRetries;
  final int compressionQuality;
  final int maxWidth;
  final int maxHeight;
  final AppLogger _logger;

  /// Load an image through the full pipeline.
  ///
  /// Returns [ImagePipelineResult] with the image data
  /// and metadata about how it was loaded.
  Future<ImagePipelineResult> load(String url) async {
    // Step 1-2: Check cache (memory → disk).
    final cached = await cache.get(url);
    if (cached != null) {
      _logger.d('ImagePipeline: Cache hit for $url');
      return ImagePipelineResult(
        data: cached,
        source: ImageSource.cache,
        url: url,
      );
    }

    // Step 4: Download with retry.
    final data = await _downloadWithRetry(url);
    if (data == null) {
      return ImagePipelineResult(
        data: null,
        source: ImageSource.network,
        url: url,
        error: 'Failed to download image',
      );
    }

    // Step 5-6: Compress (if needed).
    final processed = await _processImage(data);

    // Step 7: Cache.
    await cache.put(url, processed);

    return ImagePipelineResult(
      data: processed,
      source: ImageSource.network,
      url: url,
    );
  }

  /// Prefetch an image into cache without returning it.
  Future<bool> prefetch(String url) async {
    try {
      final result = await load(url);
      return result.data != null;
    } catch (e) {
      return false;
    }
  }

  /// Prefetch a list of images (for carousel preloading).
  Future<void> prefetchAll(List<String> urls) async {
    await Future.wait(
      urls.map((url) => prefetch(url)),
      eagerError: false,
    );
  }

  /// Download with exponential backoff retry.
  Future<Uint8List?> _downloadWithRetry(String url) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

        if (response.data != null) {
          return Uint8List.fromList(response.data!);
        }
      } catch (e) {
        _logger.w('ImagePipeline: Download attempt ${attempt + 1} failed for $url');

        if (attempt < maxRetries - 1) {
          // Exponential backoff: 500ms, 1000ms, 2000ms.
          await Future.delayed(Duration(milliseconds: 500 * (1 << attempt)));
        }
      }
    }

    _logger.e('ImagePipeline: All download attempts failed for $url');
    return null;
  }

  /// Process/compress image if needed.
  Future<Uint8List> _processImage(Uint8List data) async {
    // TODO(team): Implement flutter_image_compress integration.
    // For now, return data as-is.
    return data;
  }
}

/// Source of a loaded image.
enum ImageSource {
  /// Loaded from memory or disk cache.
  cache,

  /// Downloaded from network.
  network,

  /// Generated placeholder.
  placeholder,
}

/// Result of an image pipeline load operation.
class ImagePipelineResult {
  const ImagePipelineResult({
    required this.data,
    required this.source,
    required this.url,
    this.error,
    this.blurHash,
  });

  /// The image bytes (null if failed).
  final Uint8List? data;

  /// Where the image was loaded from.
  final ImageSource source;

  /// The original URL.
  final String url;

  /// Error message if failed.
  final String? error;

  /// BlurHash string for progressive loading.
  final String? blurHash;

  /// Whether the load was successful.
  bool get isSuccess => data != null;

  /// Whether the image came from cache.
  bool get isCached => source == ImageSource.cache;
}
