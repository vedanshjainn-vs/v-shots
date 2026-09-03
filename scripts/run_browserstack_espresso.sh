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
# 3+4. Start the Espresso build and poll it, retrying on infra session errors.
# ---------------------------------------------------------------------------
DEVICE="${BROWSERSTACK_DEVICE:-Xiaomi Redmi Note 11-11.0}"
# Retry up to 3 attempts: BrowserStack sometimes errors the session before any
# test runs ("Could not start a session : Something went wrong during test
# execution"), which is infra, not an app crash. We reuse the already-uploaded
# app/test-suite so retries are cheap. We only ever exit 0 on a real pass.
max_attempts=3
attempt=1
final_status_code=1
while [ "$attempt" -le "$max_attempts" ]; do
  echo "=== Attempt $attempt/$max_attempts ==="
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
    echo "  ::warning::No build_id returned; retrying."
    attempt=$((attempt+1)); sleep 15; continue
  fi

  # Poll the build until it reaches a terminal state.
  echo "  ==> Polling build $BUILD_ID"
  sess_error=0
  for i in $(seq 1 60); do
    RES=$(curl -sS -u "$AUTH" "$BASE/app-automate/espresso/v2/builds/$BUILD_ID")
    STATUS=$(echo "$RES" | python3 -c "
import sys,json
try: print(json.load(sys.stdin).get('status',''))
except Exception: print('')
")
    echo "  [$i] status=$STATUS"
    case "$STATUS" in
      passed|failed|error|done)
        echo "$RES" > espresso_result.json
        echo "  === ESPRESSO RESULT ==="
        # The v2 build response exposes per-session testcase counts but NOT the
        # individual testcase data — that lives on the per-session detail
        # endpoint. Judge pass/fail from session statuses here, then fetch the
        # failing session's testcase detail for the crash trace.
        python3 -c "
import json
d=json.load(open('espresso_result.json'))
print('  build status:', d.get('status'))
print('  duration:', d.get('duration'), 's')
sessed=0; failed_sessions=[]
for dev in d.get('devices',[]):
    for s in dev.get('sessions',[]):
        sessed+=1
        tc=s.get('testcases',{})
        print(('    DEVICE %s | session %s | testcases %s' % (
            dev.get('device',''), s.get('status',''),
            json.dumps(tc.get('status', tc)))))
        if s.get('status') != 'passed':
            failed_sessions.append((dev.get('device',''), s.get('id',''), s.get('status','')))
print('  sessions:', sessed)
if d.get('status') != 'passed' or failed_sessions:
    print('  FAILED_SESSIONS:', failed_sessions)
    raise SystemExit(1)
raise SystemExit(0)
"
        status_code=$?
        # Distinguish a genuine crash/fail of the app (no retry) from an infra
        # session error with zero testcases (retry).
        if [ "$status_code" != "0" ]; then
          run_tests=$(python3 -c "
import json
d=json.load(open('espresso_result.json'))
n=0
for dev in d.get('devices',[]):
    for s in dev.get('sessions',[]):
        n += (s.get('testcases',{}) or {}).get('count', 0) or 0
print(n)
")
          sess_err=$(python3 -c "
import json
d=json.load(open('espresso_result.json'))
print(d.get('status') == 'error')
")
          echo "    ran tests: $run_tests | build error: $sess_err"
          if [ "$sess_err" = "True" ] && [ "$run_tests" -eq 0 ]; then
            echo "    ::warning::Infra session error (no tests ran); will retry."
            sess_error=1
            break   # stop polling this errored build; retry with a new one
          fi
          if [ "$sess_error" != "1" ]; then
            echo "    --- Fetching failing session testcase details ---"
            python3 -c "
import json
d=json.load(open('espresso_result.json'))
for dev in d.get('devices',[]):
    for s in dev.get('sessions',[]):
        if s.get('status') != 'passed':
            print(d.get('session_id','') or s.get('id',''))
" | while read -r sid; do
              [ -z "$sid" ] && continue
              curl -sS -u "$AUTH" "$BASE/app-automate/espresso/v2/builds/$BUILD_ID/sessions/$sid" \
                | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
except Exception as e:
    print('  (could not parse session detail)'); raise SystemExit(0)
print('    session status:', d.get('status'))
print('    session error:', json.dumps(d.get('error')))
for cl in d.get('testcases',{}).get('data',[]):
    for t in cl.get('testcases',[]):
        print('    TEST', t.get('name'), '|', t.get('status'))
        print('      error:', (t.get('error') or '(none)')[:2500])
"
            done
            final_status_code=$status_code
            exit "$status_code"
          fi
        else
          final_status_code=0
          echo "    PASSED on-device."
          exit 0
        fi
        ;;
    esac
    sleep 30
  done
  if [ "$sess_error" = "1" ]; then
    echo "  Retrying after infra session error."
  else
    echo "  ::warning::Timed out polling this attempt; retrying."
  fi
  attempt=$((attempt+1))
  sleep 10
done

echo "::error::Timed out waiting for Espresso build to finish (all attempts)."
exit "$final_status_code"
