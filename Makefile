# ════════════════════════════════════════════════
# Project Lyra — Makefile
# ════════════════════════════════════════════════
#
# Common development commands.
# Usage: make <command>
# ════════════════════════════════════════════════

.PHONY: setup clean get build run dev stg prod test lint format codegen watch

# ── Setup ──────────────────────────────────────
setup:
	dart pub global activate flutterfire_cli
	flutter pub get
	dart run build_runner build --delete-conflicting-outputs

# ── Dependencies ───────────────────────────────
get:
	flutter pub get

upgrade:
	flutter pub upgrade --major-versions

# ── Clean ──────────────────────────────────────
clean:
	flutter clean
	flutter pub get

# ── Code Generation ────────────────────────────
codegen:
	dart run build_runner build --delete-conflicting-outputs

codegen-watch:
	dart run build_runner watch --delete-conflicting-outputs

codegen-clean:
	dart run build_runner clean

# ── Localization ───────────────────────────────
l10n:
	flutter gen-l10n

# ── Build ──────────────────────────────────────
build-dev:
	flutter build apk --debug --flavor development --dart-define=FLAVOR=development

build-stg:
	flutter build apk --staging --flavor staging --dart-define=FLAVOR=staging

build-prod:
	flutter build appbundle --release --flavor production --dart-define=FLAVOR=production

# ── Run ────────────────────────────────────────
dev:
	flutter run --debug --flavor development --dart-define=FLAVOR=development

stg:
	flutter run --profile --flavor staging --dart-define=FLAVOR=staging

prod:
	flutter run --release --flavor production --dart-define=FLAVOR=production

# ── Testing ────────────────────────────────────
test:
	flutter test

test-unit:
	flutter test test/unit/

test-widget:
	flutter test test/widget/

test-integration:
	flutter test integration_test/

test-coverage:
	flutter test --coverage
	genhtml coverage/lcov.info -o coverage/html
	open coverage/html/index.html

# ── Linting ────────────────────────────────────
lint:
	dart analyze lib/

lint-fix:
	dart fix --apply

# ── Formatting ─────────────────────────────────
format:
	dart format lib/ test/ --set-exit-if-changed

format-fix:
	dart format lib/ test/

# ── Analyze ────────────────────────────────────
analyze:
	dart analyze lib/ --fatal-infos --fatal-warnings

# ── Dependency Graph ───────────────────────────
deps:
	dart pub deps

# ── Full CI Pipeline ───────────────────────────
ci:
	make clean
	make get
	make codegen
	make lint
	make test
	make build-prod
