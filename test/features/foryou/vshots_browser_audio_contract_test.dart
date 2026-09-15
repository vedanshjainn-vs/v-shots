import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native browser keeps ad mute separate from content audio', () {
    final source = File(
      'android/app/src/main/kotlin/com/vshots/live/'
      'VShotsBrowserPlatformView.kt',
    ).readAsStringSync();

    expect(source, contains('PLAYING_WITH_AUDIO'));
    expect(source, contains('PLAYING_MUTED_AD'));
    expect(source, contains('PLAYING_MUTED_CONTENT'));
    expect(source, contains('__vshotsAdAudioSnapshot'));
    expect(source, contains('YT_RESTORE_AD_AUDIO_JS'));
    expect(source, contains('YT_VALIDATE_CONTENT_AUDIO_JS'));
    expect(source, contains('v.muted = !!snapshot.muted'));
    expect(source, contains('contentAudioValidationRequested'));
    expect(source, contains("document.querySelector('.ytp-unmute')"));
    expect(source, contains('explicit play:'));
    expect(source.split('contentAudioValidated = true').length - 1, 2);
    expect(source, isNot(contains('.videoAdUi, .ytp-ad-player-overlay')));
    expect(source, contains('generationGuardedJs'));
    expect(source, contains('SOURCE_TOUCHSCREEN'));
    expect(source, contains('window.innerWidth'));

    // YouTube must be rendered through the official video-only embed surface,
    // never as a watch webpage with its own transport/header chrome.
    expect(source, contains('youtubePlayerSurfaceUrl'));
    expect(source, contains('https://www.youtube.com/embed/\$id'));
    expect(source, contains('controls=0'));
    expect(source, contains('rel=0'));
    expect(source, contains('disablekb=1'));
    expect(source, contains('loadUrl(playbackUrl, additionalHeaders)'));
    expect(source, contains('"Referer"'));
    expect(source, contains('appContext.packageName'));
    expect(source, contains('Error 153'));
    expect(source, isNot(contains('loadUrl(url)')));

    // Generic video touches are consumed; only the exact trusted unmute
    // gesture is allowed to reach YouTube.
    expect(
      source,
      contains('override fun dispatchTouchEvent(event: MotionEvent)'),
    );
    expect(
      source,
      contains('override fun onTouchEvent(event: MotionEvent)'),
    );
    expect(source, contains('trustedTouchInFlight'));
    expect(source, contains('return true'));

    // Guard against reintroducing the production regression: muting an ad
    // without capturing/restoring the content state.
    expect(
      source,
      isNot(contains('if(v && !v.muted){ v.muted = true; v.volume = 0; }')),
    );
  });

  test('premium shell constrains the embed and owns the sound action', () {
    final source = File(
      'lib/features/foryou/discovery_browser_sheet.dart',
    ).readAsStringSync();

    expect(source, contains('AspectRatio('));
    expect(source, contains('_videoAspectRatio = 16 / 9'));
    expect(source, contains('YouTube controls are disabled'));
    expect(
      source,
      contains("label: Text(busy ? 'Enabling…' : 'Enable Sound')"),
    );
    expect(source, contains("'Enable Sound'"));
  });
}
