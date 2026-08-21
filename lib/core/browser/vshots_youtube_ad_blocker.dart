// YouTube ad blocker — DISABLED for YouTube ToS compliance.
class VShotsYouTubeAdBlocker {
  VShotsYouTubeAdBlocker._();
  static final VShotsYouTubeAdBlocker instance = VShotsYouTubeAdBlocker._();
  static bool shouldBlock(String url) => false;
  static const String cosmeticCss = '';
  static const String adSkipJs = '';
  static const List<String> adDomains = [];
  static const List<String> adPatterns = [];
}
