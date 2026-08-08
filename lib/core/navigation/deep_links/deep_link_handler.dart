// ════════════════════════════════════════════════
// Project Lyra — Deep Link Handler
// ════════════════════════════════════════════════
//
// Parses and routes incoming deep links:
// - Universal links (https://projectlyra.com/...)
// - Custom scheme (lyra://...)
// - Push notification taps
// - Dynamic links
// ════════════════════════════════════════════════

import '../../logging/app_logger.dart';
import '../route_paths.dart';

/// Parsed deep link information.
class DeepLink {
  const DeepLink({
    required this.path,
    required this.type,
    this.params = const {},
    this.queryParams = const {},
    this.rawUrl,
  });

  final String path;
  final DeepLinkType type;
  final Map<String, String> params;
  final Map<String, String> queryParams;
  final String? rawUrl;
}

/// Type of deep link source.
enum DeepLinkType {
  /// Universal link (https://...).
  universal,

  /// Custom scheme (lyra://...).
  customScheme,

  /// Push notification tap.
  notification,

  /// Dynamic link.
  dynamic,
}

/// Handles incoming deep links and maps them to routes.
///
/// ```dart
/// final handler = DeepLinkHandler();
/// final link = handler.parse('https://projectlyra.com/track/abc123');
/// if (link != null) {
///   context.go(link.path, extra: link.params);
/// }
/// ```
class DeepLinkHandler {
  DeepLinkHandler({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  /// URL patterns and their corresponding routes.
  static final Map<RegExp, String Function(Match)> _patterns = {
    RegExp(r'/track/([a-zA-Z0-9]+)'): (m) => RoutePaths.trackById(m.group(1)!),
    RegExp(r'/album/([a-zA-Z0-9]+)'): (m) => RoutePaths.albumById(m.group(1)!),
    RegExp(r'/artist/([a-zA-Z0-9]+)'): (m) => RoutePaths.artistById(m.group(1)!),
    RegExp(r'/playlist/([a-zA-Z0-9]+)'): (m) => RoutePaths.playlistById(m.group(1)!),
    RegExp(r'/podcast/([a-zA-Z0-9]+)'): (m) => RoutePaths.podcastById(m.group(1)!),
    RegExp(r'/audiobook/([a-zA-Z0-9]+)'): (m) => RoutePaths.audiobookById(m.group(1)!),
    RegExp(r'/premium'): (_) => RoutePaths.premium,
    RegExp(r'/settings'): (_) => RoutePaths.settings,
  };

  /// Parse a URL into a [DeepLink].
  DeepLink? parse(String url, {DeepLinkType type = DeepLinkType.universal}) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;

      for (final entry in _patterns.entries) {
        final match = entry.key.firstMatch(path);
        if (match != null) {
          final routePath = entry.value(match);

          _logger.d('DeepLinkHandler: Matched $url → $routePath');

          return DeepLink(
            path: routePath,
            type: type,
            params: _extractParams(uri),
            queryParams: uri.queryParameters,
            rawUrl: url,
          );
        }
      }

      _logger.w('DeepLinkHandler: No match for $url');
      return null;
    } catch (e) {
      _logger.e('DeepLinkHandler: Parse error for $url', error: e);
      return null;
    }
  }

  /// Parse a notification payload into a route.
  DeepLink? parseNotification(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final id = data['id'] as String?;

    if (type == null || id == null) return null;

    return switch (type) {
      'track' => DeepLink(
          path: RoutePaths.trackById(id),
          type: DeepLinkType.notification,
          params: {'id': id},
        ),
      'album' => DeepLink(
          path: RoutePaths.albumById(id),
          type: DeepLinkType.notification,
          params: {'id': id},
        ),
      'artist' => DeepLink(
          path: RoutePaths.artistById(id),
          type: DeepLinkType.notification,
          params: {'id': id},
        ),
      'playlist' => DeepLink(
          path: RoutePaths.playlistById(id),
          type: DeepLinkType.notification,
          params: {'id': id},
        ),
      'premium' => const DeepLink(
          path: RoutePaths.premium,
          type: DeepLinkType.notification,
        ),
      _ => null,
    };
  }

  Map<String, String> _extractParams(Uri uri) {
    final params = <String, String>{};
    final segments = uri.pathSegments;

    // Extract :id params from path segments.
    for (int i = 0; i < segments.length - 1; i++) {
      if (segments[i] == 'track' ||
          segments[i] == 'album' ||
          segments[i] == 'artist' ||
          segments[i] == 'playlist' ||
          segments[i] == 'podcast' ||
          segments[i] == 'audiobook') {
        params['id'] = segments[i + 1];
      }
    }

    return params;
  }
}
