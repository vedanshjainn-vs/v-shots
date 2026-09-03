from pathlib import Path
import re

ROOT = Path('.')


def patch_main():
    p = ROOT / 'lib/main.dart'
    text = p.read_text()
    replacement = '''void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final bootTimer = Stopwatch()..start();

  // Startup safety: render Flutter before any optional service/plugin work.
  // A network, notification, ads, auth, or AudioService failure must never
  // leave the Android launch surface black.
  runApp(const VShotsApp());
  unawaited(_bootstrapAfterFirstFrame(bootTimer));
}

Future<void> _bootstrapAfterFirstFrame(Stopwatch bootTimer) async {
  try {
    await Future.wait([
      LocalLibrary.instance.initialize(),
      SignalStore.instance.initialize(),
      PersonalizationStore.instance.initialize(),
      AdFreeManager.instance.init(),
      AppVersion.load(),
    ]).timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('[Boot] local bootstrap degraded: $e');
  }

  unawaited(_bootstrapCloudServices());
  unawaited(_bootstrapAudio());
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  debugPrint('[Boot] first Flutter frame rendered at ${bootTimer.elapsedMilliseconds}ms');
}

Future<void> _bootstrapCloudServices() async {
  try {
    await SupabaseService.initialize().timeout(const Duration(seconds: 6));
  } catch (e) {
    debugPrint('[Boot] Supabase unavailable: $e');
  }
  try {
    await RemoteConfigService.instance.init().timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('[Boot] Remote config unavailable: $e');
  }
  try {
    await NotificationService.instance.initialize().timeout(const Duration(seconds: 6));
    await SmartNotificationService.instance.initialize().timeout(const Duration(seconds: 6));
  } catch (e) {
    debugPrint('[Boot] Notifications unavailable: $e');
  }
  try {
    await AuthService.instance.initializeGoogleSignIn().timeout(const Duration(seconds: 6));
  } catch (e) {
    debugPrint('[Boot] Google Sign-In unavailable: $e');
  }
  try {
    await ConsentManager.instance.initialize().timeout(const Duration(seconds: 6));
    ConsentManager.instance.onStatusChanged =
        () => VShotsLevelPlay.instance.syncConsent();
    unawaited(VShotsLevelPlay.instance.initialize());
  } catch (e) {
    debugPrint('[Boot] Ads/consent unavailable: $e');
  }
  try {
    await MusicRegionProfile.initialize().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('[Boot] Region profile unavailable: $e');
  }
}

Future<void> _bootstrapAudio() async {
  try {
    audioHandler = await AudioService.init(
      builder: () => VShotsAudioHandler(audioPlayer),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.vshots.live.channel.audio',
        androidNotificationChannelName: 'V Shots playback',
        androidNotificationChannelDescription:
            'Media playback controls for V Shots',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: true,
        androidNotificationClickStartsActivity: true,
      ),
    );
    audioHandler?.onSkipNext = VShotsPlaybackManager.instance.next;
    audioHandler?.onSkipPrevious = VShotsPlaybackManager.instance.previous;
    audioHandler?.onTrackCompleted = VShotsPlaybackManager.instance.next;
    debugPrint('[Boot] AudioService ready');
  } catch (e) {
    debugPrint('[Boot] AudioService unavailable: $e');
  }
  try {
    unawaited(AppUpdateService.instance.checkForUpdate());
  } catch (e) {
    debugPrint('[Boot] update check unavailable: $e');
  }
}
'''
    pattern = re.compile(r"void main\(\) async \{.*?\n\}\n\n(?=// ═+\n// APP ROOT)", re.DOTALL)
    text, count = pattern.subn(replacement + '\n', text, count=1)
    if count == 0:
        raise SystemExit('main() anchor not found')

    old_delay = "    Future.delayed(const Duration(seconds: 2), () {\n      if (!mounted) return;"
    new_delay = "    Future.delayed(const Duration(seconds: 2), () async {\n      if (!mounted) return;\n      try {\n        await Future.wait([\n          LocalLibrary.instance.initialize(),\n          SignalStore.instance.initialize(),\n          PersonalizationStore.instance.initialize(),\n        ]).timeout(const Duration(seconds: 2));\n      } catch (e) {\n        debugPrint('[Splash] local state wait degraded: $e');\n      }\n      if (!mounted) return;"
    if old_delay in text:
        text = text.replace(old_delay, new_delay, 1)
    p.write_text(text)


def patch_main_shell():
    p = ROOT / 'lib/main.dart'
    text = p.read_text()
    anchor = '    audioHandler?.onTrackCompleted = VShotsPlaybackManager.instance.next;\n'
    if anchor not in text or 'late-audio-bind' in text:
        return
    insertion = anchor + '''    // AudioService is initialized after first paint. Bind callbacks when it
    // becomes ready so a fast navigation to MainShell does not lose controls.
    unawaited(() async {
      for (var i = 0; i < 50 && audioHandler == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted || audioHandler == null) return; // late-audio-bind
      audioHandler?.onSkipNext = VShotsPlaybackManager.instance.next;
      audioHandler?.onSkipPrevious = VShotsPlaybackManager.instance.previous;
      audioHandler?.onTrackCompleted = VShotsPlaybackManager.instance.next;
    }());
'''
    text = text.replace(anchor, insertion, 1)
    p.write_text(text)


if __name__ == '__main__':
    patch_main()
    patch_main_shell()
    print('Startup recovery patch applied: first Flutter frame is independent of optional services.')
