#!/usr/bin/env bash
# ════════════════════════════════════════════════
# V Shots — BrowserStack App Automate Espresso runner
# ════════════════════════════════════════════════
# Uploads the app + androidTest APK, starts an Espresso cold-launch build on a
# real device, polls it, and reports pass/fail with the crash trace if the app
# dies at startup. The v2 build endpoint reports terminal status as
# `passed` / `failed` (not `done`), with tests under
# device[].sessions[].testcases.data[].testcases[].
#
# Requires env: BROWSERSTACK_USERNAME, BROWSERSTACK_ACCESS_KEY,
#               APP_APK, TEST_APK  (paths)
# ════════════════════════════════════════════════
set -euo pipefail

: "${BROWSERSTACK_USERNAME:?BROWSERSTACK_USERNAME required}"
: "${BROWSERSTACK_ACCESS_KEY:?BROWSERSTACK_ACCESS_KEY required}"
: "${APP_APK:?APP_APK required}"
: "${TEST_APK:?TEST_APK required}"

BASE="https://api-cloud.browserstack.com"
AUTH="$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY"

# ---------------------------------------------------------------------------
# 1. Upload app APK
# ---------------------------------------------------------------------------
echo "==> Uploading app APK: $APP_APK"
APP_RES=$(curl -sS -u "$AUTH" -X POST "$BASE/app-automate/upload" \
  -F "file=@$APP_APK" -F "custom_id=v-shots-coldlaunch-app")
echo "app upload: $APP_RES"
APP_URL=$(echo "$APP_RES" | grep -o '"app_url":"[^"]*"' | cut -d'"' -f4)
if [ -z "$APP_URL" ]; then
  echo "::error::No app_url returned."; exit 1
fi

# ---------------------------------------------------------------------------
# 2. Upload test suite APK
# ---------------------------------------------------------------------------
echo "==> Uploading test APK: $TEST_APK"
TEST_RES=$(curl -sS -u "$AUTH" -X POST "$BASE/app-automate/espresso/v2/test-suite" \
  -F "file=@$TEST_APK")
echo "test-suite upload: $TEST_RES"
TEST_URL=$(echo "$TEST_RES" | grep -o '"test_suite_url":"[^"]*"' | cut -d'"' -f4)
if [ -z "$TEST_URL" ]; then
  TEST_URL=$(echo "$TEST_RES" | grep -o '"test_suite_id":"[^"]*"' | cut -d'"' -f4)
fi
if [ -z "$TEST_URL" ]; then
  echo "::error::No test_suite_url returned."; exit 1
fi

# ---------------------------------------------------------------------------
# 3. Start the Espresso build
# ---------------------------------------------------------------------------
echo "==> Starting Espresso build"
# devices value is <devicename>-<osversion>, e.g. 'Xiaomi Redmi Note 11-11.0'.
DEVICE="${BROWSERSTACK_DEVICE:-Xiaomi Redmi Note 11-11.0}"
PAYLOAD=$(python3 -c "
import json,sys
print(json.dumps({
  'devices': [sys.argv[1]],
  'app': sys.argv[2],
  'testSuite': sys.argv[3],
  'name': 'V Shots cold launch smoke'
}))
" "$DEVICE" "$APP_URL" "$TEST_URL")

BUILD_RES=$(curl -sS -u "$AUTH" -X POST "$BASE/app-automate/espresso/v2/build" \
  -H "Content-Type: application/json" -d "$PAYLOAD")
echo "build start: $BUILD_RES"
BUILD_ID=$(echo "$BUILD_RES" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get('build_id') or d.get('build_id') or '')
except Exception as e:
    print('')
")
if [ -z "$BUILD_ID" ] || [ "$BUILD_ID" = "None" ]; then
  echo "::error::No build_id returned. Build may not have started."
  curl -sS -u "$AUTH" "$BASE/app-automate/espresso/v2/builds" | head -c 2000
  exit 1
fi

# ---------------------------------------------------------------------------
# 4. Poll the build until it reaches a terminal state
# ---------------------------------------------------------------------------
echo "==> Polling build $BUILD_ID"
for i in $(seq 1 60); do
  RES=$(curl -sS -u "$AUTH" "$BASE/app-automate/espresso/v2/builds/$BUILD_ID")
  STATUS=$(echo "$RES" | python3 -c "
import sys,json
try: print(json.load(sys.stdin).get('status',''))
except Exception: print('')
")
  echo "[$i] status=$STATUS"
  case "$STATUS" in
    passed|failed)
      echo "$RES" > espresso_result.json
      echo "=== ESPRESSO RESULT ==="
      python3 -c "
import json
d=json.load(open('espresso_result.json'))
print('build status:', d.get('status'))
print('duration:', d.get('duration'), 's')
tests=[]
for dev in d.get('devices',[]):
    for s in dev.get('sessions',[]):
        for cl in s.get('testcases',{}).get('data',[]):
            for t in cl.get('testcases',[]):
                t = dict(t)
                t['_device'] = dev.get('device', '')
                t['_session'] = s.get('status', '')
                tests.append(t)
passed=[t for t in tests if t.get('status')=='passed']
failed=[t for t in tests if t.get('status')!='passed']
print('total tests:', len(tests))
print('passed:', len(passed), 'failed:', len(failed))
for f in failed:
    print('  FAILED:', f.get('name'), '|', f.get('status'), '| dev', f.get('_device'))
    print('   error:', (f.get('error') or '(none)')[:2500])
# exit non-zero if any test failed, else success
sys.exit(1 if failed else 0)
"
      exit $?
      ;;
  esac
  sleep 30
done

echo "::error::Timed out waiting for Espresso build to finish."
exit 1
