# Developer commands for the Proxy Care client. Run from this directory.
#
#   make get                      Resolve dependencies (updates pubspec.lock)
#   make get-locked               Resolve exactly what pubspec.lock pins
#   make gen                      Code generation (build_runner, gen-l10n)
#   make format                   Format Dart sources
#   make format-check             Fail if any Dart source is not formatted
#   make analyze                  Static analysis (strict)
#   make test                     Run all tests
#   make check-env [ENV=...]      Validate config/env/$(ENV).json
#   make build-web [ENV=...]      Validate config, then release web build
#   make build-android [ENV=...]  Validate config, then release APK and App
#                                 Bundle (debug-key signed; needs Android SDK
#                                 and JDK 21)
#   make build-ios [ENV=...]      Validate config, then unsigned release iOS
#                                 build (macOS with Xcode only)
#   make goldens                  Regenerate golden images (Linux; see
#                                 TESTING.md)
#   make build-showcase [BASE_HREF=/repo/]
#                                 Release web build of the widget showcase
#                                 (config/env/showcase.json) at BASE_HREF
#
# ENV defaults to development. Other environments read config/env/<ENV>.json,
# e.g. `make build-web ENV=production` uses config/env/production.json.
#
# pubspec.lock and generated files are committed: after `make get` or
# `make gen`, commit what changed.

FLUTTER ?= flutter
DART ?= dart
ENV ?= development
DEFINES_FILE ?= config/env/$(ENV).json
BASE_HREF ?= /

.PHONY: get get-locked gen format format-check analyze test check-env build-web \
	build-android build-ios build-showcase goldens

get:
	$(FLUTTER) pub get

get-locked:
	$(FLUTTER) pub get --enforce-lockfile

gen:
	$(DART) run build_runner build --delete-conflicting-outputs
	$(FLUTTER) gen-l10n

# Regenerates golden images. Linux only (CI's "Bless goldens" workflow);
# review every changed image before committing it.
goldens:
	$(FLUTTER) test --update-goldens --tags golden

format:
	$(DART) format .

format-check:
	$(DART) format --output=none --set-exit-if-changed .

analyze:
	$(FLUTTER) analyze

test:
	$(FLUTTER) test

check-env:
	$(DART) run tool/check_env.dart $(DEFINES_FILE)

build-web: check-env
	$(FLUTTER) build web --release --dart-define-from-file=$(DEFINES_FILE)

build-android: check-env
	$(FLUTTER) build apk --release --dart-define-from-file=$(DEFINES_FILE)
	$(FLUTTER) build appbundle --release --dart-define-from-file=$(DEFINES_FILE)

build-ios: check-env
	$(FLUTTER) build ios --release --no-codesign \
		--dart-define-from-file=$(DEFINES_FILE)

# The widget showcase is a development preview: it never uses a staging or
# production config (WidgetShowcaseRoutes refuses production anyway).
build-showcase:
	$(DART) run tool/check_env.dart config/env/showcase.json
	$(FLUTTER) build web --release \
		--dart-define-from-file=config/env/showcase.json \
		--base-href $(BASE_HREF)
