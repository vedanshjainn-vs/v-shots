import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/browser/vshots_ad_block_engine.dart';
import 'package:v_shots/core/browser/vshots_youtube_ad_blocker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await VShotsAdBlockEngine.instance.initialize();
    await VShotsAdBlockEngine.instance.setEnabled(true);
  });

  test('YouTube watch and media URLs are never blocked', () {
    final engine = VShotsAdBlockEngine.instance;
    expect(
      engine.shouldBlock('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      isFalse,
    );
    expect(
      engine.shouldBlock('https://googlevideo.com/videoplayback?id=1'),
      isFalse,
    );
    expect(
      engine.shouldBlock('https://i.ytimg.com/vi/abc/hqdefault.jpg'),
      isFalse,
    );
  });

  test('legacy YouTube ad-blocker helper is disabled', () {
    expect(
      VShotsYouTubeAdBlocker.shouldBlock(
        'https://www.youtube.com/api/stats/ads',
      ),
      isFalse,
    );
    expect(VShotsYouTubeAdBlocker.cosmeticCss, isEmpty);
    expect(VShotsYouTubeAdBlocker.adSkipJs, isEmpty);
  });
}
