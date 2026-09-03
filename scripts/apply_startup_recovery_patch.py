from pathlib import Path
import re

ROOT = Path('.')


def patch_main():
    p = ROOT / 'lib/main.dart'
    text = p.read_text()

    # The current branch already uses the post-frame startup architecture.
    # Never rewrite an already-normalized main.dart; recovery must be safe to
    # run repeatedly after other runtime/notification patches.
    if 'Future<void> _bootstrapAfterFirstFrame(' in text and 'void main() {' in text:
        print('Startup recovery: post-frame bootstrap already present; skipping main rewrite.')
        return

    if "import 'core/recommendation/music_region_profile.dart';" not in text:
        anchor_import = "import 'core/recommendation/recommendation_engine.dart';"
        if anchor_import in text:
            text = text.replace(
                anchor_import,
                "import 'core/recommendation/music_region_profile.dart';\n" + anchor_import,
                1,
            )

    replacement = '''void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final bootTimer = Stopwatch()..start();
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
  try { await SupabaseService.initialize().timeout(const Duration(seconds: 6)); } catch (e) { debugPrint('[Boot] Supabase unavailable: $e'); }
  try { await RemoteConfigService.instance.init().timeout(const Duration(seconds: 4)); } catch (e) { debugPrint('[Boot] Remote config unavailable: $e'); }
  try {
    await NotificationService.instance.initialize().timeout(const Duration(seconds: 6));
    SmartNotificationService.instance.initialize();
  } catch (e) { debugPrint('[Boot] Notifications unavailable: $e'); }
  try { await AuthService.instance.initializeGoogleSignIn().timeout(const Duration(seconds: 6)); } catch (e) { debugPrint('[Boot] Google Sign-In unavailable: $e'); }
  try {
    await ConsentManager.instance.initialize().timeout(const Duration(seconds: 6));
    ConsentManager.instance.onStatusChanged = () => VShotsLevelPlay.instance.syncConsent();
    unawaited(VShotsLevelPlay.instance.initialize());
  } catch (e) { debugPrint('[Boot] Ads/consent unavailable: $e'); }
  try { await MusicRegionProfile.initialize().timeout(const Duration(seconds: 5)); } catch (e) { debugPrint('[Boot] Region profile unavailable: $e'); }
}

Future<void> _bootstrapAudio() async {
  try {
    audioHandler = await AudioService.init(
      builder: () => VShotsAudioHandler(audioPlayer),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.vshots.live.channel.audio',
        androidNotificationChannelName: 'V Shots playback',
        androidNotificationChannelDescription: 'Media playback controls for V Shots',
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
  } catch (e) { debugPrint('[Boot] AudioService unavailable: $e'); }
  try { unawaited(AppUpdateService.instance.checkForUpdate()); } catch (e) { debugPrint('[Boot] update check unavailable: $e'); }
}
'''
    pattern = re.compile(r"void main\(\) async \{.*?\n\}\n\n(?=// ═+\n// APP ROOT)", re.DOTALL)
    text, count = pattern.subn(replacement + '\n', text, count=1)
    if count == 0:
        raise SystemExit('main() anchor not found in legacy startup architecture')
    p.write_text(text)


def patch_main_shell():
    p = ROOT / 'lib/main.dart'
    text = p.read_text()
    shell_start = text.find('class _MainShellState extends State<MainShell>')
    if shell_start < 0:
        raise SystemExit('MainShellState anchor not found')
    prefix = text[:shell_start]
    shell = text[shell_start:]
    anchor = '    audioHandler?.onTrackCompleted = VShotsPlaybackManager.instance.next;\n'
    if anchor not in shell or 'late-audio-bind' in shell:
        return
    insertion = anchor + '''    // AudioService may initialize after MainShell paints. Rebind callbacks
    // once the handler becomes available so notification controls are reliable.
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
    shell = shell.replace(anchor, insertion, 1)
    p.write_text(prefix + shell)


if __name__ == '__main__':
    patch_main()
    patch_main_shell()
    print('Startup recovery patch applied: idempotent post-frame startup.')
