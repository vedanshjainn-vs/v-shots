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
    expect(source, contains('generationGuardedJs'));

    // Guard against reintroducing the production regression: muting an ad
    // without capturing/restoring the content state.
    expect(
      source,
      isNot(contains('if(v && !v.muted){ v.muted = true; v.volume = 0; }')),
    );
  });
}
