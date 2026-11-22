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
#   make run [ENV=...] [VARIANT=...]
#                                 Run the VARIANT app (Android device)
#   make run-user [ENV=...]       Run the User app (Android device)
#   make run-caretaker [ENV=...]  Run the Caretaker app (Android device)
#   make build-web [ENV=...] [VARIANT=...]
#                                 Validate config, then release web build
#   make build-android [ENV=...] [VARIANT=...]
#                                 Validate config, then release APK and App
#                                 Bundle (debug-key signed; needs Android SDK
#                                 and JDK 21)
#   make build-android-user, make build-android-caretaker [ENV=...]
#   make build-ios [ENV=...] [VARIANT=...]
#                                 Validate config, then unsigned release iOS
#                                 build (macOS with Xcode only)
#   make build-ios-user, make build-ios-caretaker [ENV=...]
#   make goldens                  Regenerate golden images (Linux; see
#                                 TESTING.md)
#   make build-showcase [BASE_HREF=/repo/]
#                                 Release web build of the widget showcase
#                                 (config/env/showcase.json) at BASE_HREF
#
# ENV defaults to development. Other environments read config/env/<ENV>.json,
# e.g. `make build-web ENV=production` uses config/env/production.json.
#
# VARIANT (user or caretaker; default user) picks the app. The default is a
# Makefile convenience only: the app itself never defaults and fails at
# start-up without APP_VARIANT, so CI passes VARIANT explicitly. It sets the
# APP_VARIANT define and, on Android, the product flavor (application ID and
# app name). iOS has no per-variant schemes yet, so iOS builds set only
# APP_VARIANT (README, "iOS configuration").
#
# pubspec.lock and generated files are committed: after `make get` or
# `make gen`, commit what changed.

FLUTTER ?= flutter
DART ?= dart
ENV ?= development
DEFINES_FILE ?= config/env/$(ENV).json
BASE_HREF ?= /
VARIANT ?= user
VARIANT_DEFINE = --dart-define=APP_VARIANT=$(VARIANT)

.PHONY: get get-locked gen format format-check analyze test check-env build-web \
	build-android build-ios build-showcase goldens run run-user run-caretaker \
	build-android-user build-android-caretaker build-ios-user \
	build-ios-caretaker

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

run: check-env
	$(FLUTTER) run --flavor $(VARIANT) $(VARIANT_DEFINE) \
		--dart-define-from-file=$(DEFINES_FILE)

run-user run-caretaker: run-%:
	$(MAKE) run VARIANT=$*

build-web: check-env
	$(FLUTTER) build web --release $(VARIANT_DEFINE) \
		--dart-define-from-file=$(DEFINES_FILE)

build-android: check-env
	$(FLUTTER) build apk --release --flavor $(VARIANT) $(VARIANT_DEFINE) \
		--dart-define-from-file=$(DEFINES_FILE)
	$(FLUTTER) build appbundle --release --flavor $(VARIANT) $(VARIANT_DEFINE) \
		--dart-define-from-file=$(DEFINES_FILE)

build-android-user build-android-caretaker: build-android-%:
	$(MAKE) build-android VARIANT=$*

build-ios: check-env
	$(FLUTTER) build ios --release --no-codesign $(VARIANT_DEFINE) \
		--dart-define-from-file=$(DEFINES_FILE)

build-ios-user build-ios-caretaker: build-ios-%:
	$(MAKE) build-ios VARIANT=$*

# The widget showcase is a development preview: it never uses a staging or
# production config (WidgetShowcaseRoutes refuses production anyway).
build-showcase:
	$(DART) run tool/check_env.dart config/env/showcase.json
	$(FLUTTER) build web --release \
		--dart-define-from-file=config/env/showcase.json \
		--dart-define=APP_VARIANT=user \
		--base-href $(BASE_HREF)
