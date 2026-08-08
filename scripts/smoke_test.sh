#!/bin/bash
# ════════════════════════════════════════════════
# V Shots — Smoke Test Script
# ════════════════════════════════════════════════
#
# Tests the APK on a connected device or emulator.
# ════════════════════════════════════════════════

set -e

APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
PACKAGE="com.vshots.live"
TIMEOUT=15

echo "=========================================="
echo "V Shots — Smoke Test"
echo "=========================================="

# Check if APK exists
if [ ! -f "$APK_PATH" ]; then
    echo "❌ APK not found at $APK_PATH"
    echo "Run 'flutter build apk --debug' first"
    exit 1
fi

echo "✅ APK found: $(ls -lh $APK_PATH | awk '{print $5}')"

# Check if device is connected
DEVICE_COUNT=$(adb devices | grep -c "device$")
if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "⚠️  No device connected"
    echo "Connect a device or start an emulator"
    exit 0
fi

echo "✅ Device connected"

# Clear app data
echo ""
echo "[1/5] Clearing app data..."
adb shell pm clear $PACKAGE 2>/dev/null || true

# Install APK
echo "[2/5] Installing APK..."
adb install -r "$APK_PATH"

# Launch app
echo "[3/5] Launching app..."
adb shell am start -n $PACKAGE/.MainActivity

# Wait and check
echo "[4/5] Waiting $TIMEOUT seconds..."
sleep $TIMEOUT

# Check if app is running
RUNNING=$(adb shell pidof $PACKAGE)
if [ -n "$RUNNING" ]; then
    echo "✅ App is running (PID: $RUNNING)"
else
    echo "❌ App is NOT running"
    echo ""
    echo "=== CRASH LOGS ==="
    adb logcat -d -t 50 | grep -E "FATAL|AndroidRuntime|Exception|Error" | tail -20
    exit 1
fi

# Capture logs
echo "[5/5] Capturing logs..."
adb logcat -d -t 100 | grep -E "Flutter|Dart|$PACKAGE" | tail -20

echo ""
echo "=========================================="
echo "SMOKE TEST PASSED"
echo "=========================================="
