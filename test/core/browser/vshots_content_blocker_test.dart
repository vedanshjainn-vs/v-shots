// ═════════════════════════════════════════════════════════════════════════════
// V Shots — VShotsContentBlocker tests (domain-agnostic ad/tracker blocking)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/browser/vshots_content_blocker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VShotsContentBlocker blocker;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    blocker = VShotsContentBlocker(
      essentialHosts: const [
        'youtube.com',
        'googlevideo.com',
        'ytimg.com',
        'google.com',
      ],
    );
    await blocker.initialize();
    await blocker.setEnabled(true);
  });

  test('known ad domain → BLOCK', () {
    expect(blocker.shouldBlock('https://ad.doubleclick.net/pixel'), isTrue);
    expect(blocker.shouldBlock('https://googlesyndication.com/x'), isTrue);
    expect(blocker.shouldBlock('https://static.pubmatic.com/x'), isTrue);
  });

  test('known tracker domain → BLOCK', () {
    expect(blocker.shouldBlock('https://www.google-analytics.com/collect'),
        isTrue);
    expect(blocker.shouldBlock('https://connect.facebook.net/pixel'), isTrue);
  });

  test('normal website resource → ALLOW (first-party safety)', () {
    expect(blocker.shouldBlock('https://example.com/style.css'), isFalse);
    expect(blocker.shouldBlock('https://news-site.com/article'), isFalse);
  });

  test('legitimate CDN → ALLOW', () {
    expect(blocker.shouldBlock('https://cdn.jsdelivr.net/lib.js'), isFalse);
    expect(blocker.shouldBlock('https://cdnjs.cloudflare.com/x.js'), isFalse);
  });

  test('media resource → ALLOW', () {
    expect(
        blocker.shouldBlock('https://googlevideo.com/videoplayback'), isFalse);
    expect(
        blocker.shouldBlock('https://ytimg.com/vi/abc/hqdefault.jpg'), isFalse);
  });

  test('essential host → ALLOW even if listed', () {
    // youtube.com/google.com are essential AND (google.com) could look
    // first-party — verify the essential allowlist wins over any rule.
    expect(blocker.isAllowed('https://www.youtube.com/watch?v=abc'), isTrue);
    expect(blocker.isAllowed('https://accounts.google.com/'), isTrue);
  });

  test('user allowlisted domain → ALLOW (persisted)', () async {
    await blocker.allowHost('ads.legitimate-site.com');
    expect(blocker.isAllowed('https://ads.legitimate-site.com/x'), isTrue);
  });

  test('malformed / empty URL → safe (never block)', () {
    expect(blocker.shouldBlock(''), isFalse);
    expect(blocker.shouldBlock('not a url'), isFalse);
    expect(blocker.shouldBlock('   '), isFalse);
  });

  test('blocker OFF → everything allowed', () async {
    await blocker.setEnabled(false);
    expect(blocker.shouldBlock('https://ad.doubleclick.net/pixel'), isFalse);
    expect(blocker.shouldBlock('https://www.google-analytics.com/collect'),
        isFalse);
  });

  test('rule matching is host-exact/suffix, not substring', () {
    // "criteo.com" must NOT match "notcriteo.com" or "criteo.com.evil.net".
    expect(blocker.shouldBlock('https://criteo.com/x'), isTrue);
    expect(blocker.shouldBlock('https://notcriteo.com/x'), isFalse);
    expect(blocker.shouldBlock('https://criteo.com.evil.net/x'), isFalse);
  });

  test('allowlist precedence: essential wins over blocklist', () {
    // google.com is essential; doubleclick.net is not — precedence must be
    // deterministic (allow > block).
    expect(blocker.isAllowed('https://google.com/'), isTrue);
    expect(blocker.shouldBlock('https://doubleclick.net/x'), isTrue);
  });

  test('recordBlocked classifies ads vs trackers', () {
    final b = VShotsContentBlocker();
    final adsBefore = b.blockedAds;
    final trackersBefore = b.blockedTrackers;
    b.recordBlocked('ad.doubleclick.net'); // ad
    b.recordBlocked('www.google-analytics.com'); // tracker
    expect(b.blockedAds, adsBefore + 1);
    expect(b.blockedTrackers, trackersBefore + 1);
  });

  test('enabled flag persists across instances', () async {
    await blocker.setEnabled(false);
    final b2 = VShotsContentBlocker();
    await b2.initialize();
    expect(b2.enabled, isFalse);
    await b2.setEnabled(true); // reset for other tests
  });
}
