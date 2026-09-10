import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/observing/error_reporting.dart';

void main() {
  // Save/restore so the global hooks installed by the bootstrap don't
  // leak into other test suites in the same run.
  late FlutterExceptionHandler originalOnError;

  setUp(() {
    FlutterError.onError = originalOnError = FlutterError.presentError;
  });

  tearDown(() {
    FlutterError.onError = originalOnError;
  });

  test(
    'initializeErrorReporting completes without throwing even when '
    'Firebase native layer is unavailable (test env) — never blocks boot',
    () async {
      // In a unit test there is no native Firebase: initializeApp() must
      // fail, and the bootstrap must swallow it and still return normally.
      await initializeErrorReporting();
    },
  );

  test('installs framework error hook before Firebase init result is known',
      () async {
    final before = FlutterError.onError;
    await initializeErrorReporting();
    expect(FlutterError.onError, isNotNull);
    // A NEW hook was installed (bootstrap always replaces it first thing).
    expect(identical(FlutterError.onError, before), isFalse);
  });

  test(
      'reporting a framework error after bootstrap never throws '
      '(recursion-safe record path)', () async {
    await initializeErrorReporting();
    // The hook chain: presentError (console) + Crashlytics record (which
    // will fail in test env and be swallowed by _record).
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('probe error from test'),
        library: 'v_shots test',
      ),
    );
  });
}
