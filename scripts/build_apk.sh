#!/bin/bash
# ════════════════════════════════════════════════
# V Shots — Build & Validate Script
# ════════════════════════════════════════════════
#
# This script:
# 1. Builds the APK
# 2. Validates it compiles
# 3. Reports success/failure
# ════════════════════════════════════════════════

set -e

echo "=========================================="
echo "V Shots — Build & Validate"
echo "=========================================="

# Step 1: Clean
echo ""
echo "[1/5] Cleaning..."
flutter clean

# Step 2: Get dependencies
echo ""
echo "[2/5] Getting dependencies..."
flutter pub get

# Step 3: Analyze
echo ""
echo "[3/5] Analyzing code..."
flutter analyze --no-fatal-infos --no-fatal-warnings || true

# Step 4: Build Debug APK
echo ""
echo "[4/5] Building Debug APK..."
flutter build apk --debug

# Step 5: Build Release APK
echo ""
echo "[5/5] Building Release APK..."
flutter build apk --release

echo ""
echo "=========================================="
echo "BUILD COMPLETE"
echo "=========================================="
echo "Debug APK: build/app/outputs/flutter-apk/app-debug.apk"
echo "Release APK: build/app/outputs/flutter-apk/app-release.apk"
echo ""

# Check file sizes
ls -lh build/app/outputs/flutter-apk/*.apk
