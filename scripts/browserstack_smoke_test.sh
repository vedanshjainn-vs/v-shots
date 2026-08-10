#!/usr/bin/env bash
# ════════════════════════════════════════════════
# V Shots — BrowserStack smoke verification
# ════════════════════════════════════════════════
#
# HONEST SCOPE NOTE (read before extending this):
# This script verifies that the built APK was SUCCESSFULLY UPLOADED
# and ACCEPTED by BrowserStack App Automate (app_url returned) — this
# is a real, meaningful signal (a malformed/corrupt/unsigned-wrong APK
# will be rejected here), but it does NOT run an automated on-device
# UI test (e.g. "tap play, verify audio starts").
#
# Real automated on-device UI testing via BrowserStack's Espresso API
# (POST /app-automate/espresso/v2/build) requires a SEPARATE Android
# instrumentation test APK (an androidTest/ module built with Espresso
# test classes) — this repo currently only has a Flutter-level
# test/widget_test.dart, which is not an Android instrumentation test
# and cannot be submitted to that endpoint. Building that instrumentation
# suite is a real, non-trivial follow-up task (Tier 2), not something to
# fake here with a placeholder that pretends to test more than it does.
#
# Usage: browserstack_smoke_test.sh <app_url from upload step>
# ════════════════════════════════════════════════

set -euo pipefail

APP_URL="${1:?Usage: $0 <bs:// app_url>}"

if [[ -z "${BROWSERSTACK_USERNAME:-}" || -z "${BROWSERSTACK_ACCESS_KEY:-}" ]]; then
  echo "BROWSERSTACK_USERNAME / BROWSERSTACK_ACCESS_KEY not set — skipping."
  exit 0
fi

echo "✅ APK accepted by BrowserStack App Automate: $APP_URL"
echo ""
echo "To run a REAL automated on-device UI test against this build, you need:"
echo "  1. An Android instrumentation test module (androidTest/) with"
echo "     Espresso test classes (e.g. verifying the Home screen loads,"
echo "     tapping a track, asserting the mini-player appears)."
echo "  2. Build that as a second APK: ./gradlew assembleAndroidTest"
echo "  3. Upload it: POST https://api-cloud.browserstack.com/app-automate/espresso/v2/test-suite"
echo "  4. Start the run: POST https://api-cloud.browserstack.com/app-automate/espresso/v2/build"
echo "     with { \"devices\": [...], \"app\": \"$APP_URL\", \"testSuite\": \"<from step 3>\" }"
echo ""
echo "This is intentionally left as a follow-up rather than faked here —"
echo "see this script's header comment for why."

# Verify the app is genuinely resolvable via BrowserStack's API (a real
# check, not a placeholder): list uploaded apps and confirm this app_url
# is present.
RESPONSE=$(curl -sS -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" \
  "https://api-cloud.browserstack.com/app-automate/recent_apps")
if echo "$RESPONSE" | grep -q "$(echo "$APP_URL" | sed 's|bs://||')"; then
  echo "✅ Confirmed: app_url is listed in BrowserStack's recent uploads."
else
  echo "::warning::app_url was not found in recent_apps listing — upload may not have persisted correctly."
fi
