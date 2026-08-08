#!/bin/bash
# ════════════════════════════════════════════════
# V Shots — Smoke Test
# ════════════════════════════════════════════════
#
# Tests basic app functionality:
# 1. Build succeeds
# 2. APK exists
# 3. Code analysis passes
# 4. Tests pass
# ════════════════════════════════════════════════

set -e

echo "=========================================="
echo "V Shots — Smoke Test Suite"
echo "=========================================="
echo ""

# Track results
PASS=0
FAIL=0
RESULTS=""

# Function to record result
record() {
    if [ $1 -eq 0 ]; then
        PASS=$((PASS + 1))
        RESULTS="${RESULTS}\n✅ $2: PASS"
    else
        FAIL=$((FAIL + 1))
        RESULTS="${RESULTS}\n❌ $2: FAIL"
    fi
}

# ═══════════════════════════════════════════════
# TEST 1: Flutter Analyze
# ═══════════════════════════════════════════════
echo "[1/4] Running Flutter Analyze..."
if flutter analyze --no-fatal-infos 2>&1; then
    record 0 "ANALYZER"
else
    record 1 "ANALYZER"
fi

# ═══════════════════════════════════════════════
# TEST 2: Flutter Test
# ═══════════════════════════════════════════════
echo ""
echo "[2/4] Running Flutter Tests..."
if flutter test 2>&1; then
    record 0 "TESTS"
else
    record 1 "TESTS"
fi

# ═══════════════════════════════════════════════
# TEST 3: Build Debug APK
# ═══════════════════════════════════════════════
echo ""
echo "[3/4] Building Debug APK..."
if flutter build apk --debug 2>&1; then
    record 0 "BUILD_DEBUG"
else
    record 1 "BUILD_DEBUG"
fi

# ═══════════════════════════════════════════════
# TEST 4: Build Release APK
# ═══════════════════════════════════════════════
echo ""
echo "[4/4] Building Release APK..."
if flutter build apk --release 2>&1; then
    record 0 "BUILD_RELEASE"
else
    record 1 "BUILD_RELEASE"
fi

# ═══════════════════════════════════════════════
# RESULTS
# ═══════════════════════════════════════════════
echo ""
echo "=========================================="
echo "SMOKE TEST RESULTS"
echo "=========================================="
echo -e "$RESULTS"
echo ""
echo "PASSED: $PASS"
echo "FAILED: $FAIL"
echo ""

if [ $FAIL -gt 0 ]; then
    echo "❌ SMOKE TEST FAILED"
    exit 1
else
    echo "✅ SMOKE TEST PASSED"
    exit 0
fi
