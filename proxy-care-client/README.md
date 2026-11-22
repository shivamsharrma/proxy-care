# Proxy Care client

Flutter client foundation for **Proxy Care**, a service where families book a
vetted caretaker to accompany a family member to hospital visits (OPD,
diagnostics, day-care procedures, admission and discharge), and caretakers
run the visit.

This is the **starter foundation**: configuration, architecture,
dependency injection, networking, error handling, Supabase authentication,
routing, the design system, cross-cutting services, tests and CI. It
contains **no application screens and no business features**. The app
starts, validates its configuration and shows a blank router placeholder.
The only screen is the development-only widget showcase (below).

## Contents

- [Supported platforms](#supported-platforms)
- [Toolchain](#toolchain) and [dependencies](#dependencies)
- [Architecture overview](#architecture-overview) and [folder structure](#folder-structure)
- [Environment configuration](#environment-configuration)
- [Local development](#local-development) and [build commands](#build-commands)
- [API integration](#api-integration), [error handling](#error-handling),
  [authentication](#authentication), [secure storage](#secure-storage)
- [Routing](#routing) and [deep links](#deep-links)
- [State management](#state-management)
- [Design system](#design-system)
- [Testing](#testing) and [continuous integration](#continuous-integration)
- [Android configuration](#android-configuration) and [iOS configuration](#ios-configuration)
- [MVP decisions](#mvp-decisions)

Detailed documents: [ARCHITECTURE.md](ARCHITECTURE.md),
[AUTHENTICATION.md](AUTHENTICATION.md), [SECURITY.md](SECURITY.md),
[TESTING.md](TESTING.md), [docs/feature-guide.md](docs/feature-guide.md),
[docs/navigation.md](docs/navigation.md),
[docs/deep-linking.md](docs/deep-linking.md),
[docs/observability.md](docs/observability.md),
[docs/design-system-mapping.md](docs/design-system-mapping.md).

## Supported platforms

| Platform | Status |
| --- | --- |
| Android | Supported. CI builds a release APK and App Bundle (debug-key signed). |
| iOS | Supported. CI builds an unsigned release build. |
| Web | Supported (development and the widget showcase). CI builds a release bundle. |

One codebase builds two apps, chosen by `APP_VARIANT` (`user` or
`caretaker`): the User app `com.proxycare.user` ("proxy-care") and the
Caretaker app `com.proxycare.caretaker` ("proxy-caretaker"). Each registers
only its own routes (`lib/app_routes.dart`); this is a UX boundary, not a
security one, because the server checks roles. On Android the variant is
also a product flavor; iOS still has one placeholder bundle ID
(`com.proxycare.client`). See the platform sections before any store
release.

## Toolchain

| Tool | Version |
| --- | --- |
| Flutter | **3.50.0** (stable), pinned in all workflows |
| Dart | 3.14 (bundled with Flutter 3.50.0) |
| Android | Android Gradle Plugin 9.3.1, Gradle 9.5.0, Kotlin 2.4.20, JDK **21**; compile/target/min SDK from the Flutter defaults |
| iOS | Xcode (latest stable on the CI runner), iOS 15.0 minimum |

`pubspec.yaml` requires Dart `^3.14.0` and Flutter `>=3.50.0`.

## Dependencies

Versions are the ones resolved in the committed `pubspec.lock`.

| Package | Version | Purpose |
| --- | --- | --- |
| `flutter_riverpod` | 3.5.0 | State management and dependency injection |
| `go_router` | 18.1.4 | Declarative routing, deep links |
| `dio` | 5.11.1 | HTTP client |
| `supabase_flutter` | 2.18.3 | Supabase Auth (identity provider) |
| `flutter_secure_storage` | 11.2.0 | Secure session storage (Keystore / Keychain / WebCrypto) |
| `connectivity_plus` | 7.3.2 | Network connection status (not reachability) |
| `freezed_annotation` | 3.1.0 | Immutable models (Freezed) |
| `json_annotation` | 4.12.0 | JSON serialization |
| `logger` | 2.8.0 | Console output behind `AppLogger` |
| `intl` | 0.20.3 | Date, number and currency formatting; localizations |
| `material_ui` | 1.11.0 | Material widgets (Flutter 3.50 moves Material to this package) |
| `flutter_localizations` | SDK | Localization delegates |

Development: `build_runner` 2.17.1, `freezed` 4.0.3, `json_serializable`
6.15.2, `mocktail` 1.0.5, `flutter_lints` 6.0.0, `flutter_test` (SDK).
Riverpod code generation is not used; providers are written by hand.

`pubspec.lock` is committed. `make get` updates it; commit the change with
the `pubspec.yaml` change that caused it. CI fails if the lockfile or any
generated file is out of date. Dependency rules are in
[SECURITY.md](SECURITY.md#dependency-security).

## Architecture overview

Feature-first Clean Architecture with three layers per feature
(presentation → domain ← data) on top of a shared `core` (infrastructure)
and `shared` (models, design-system widgets). Domain code is pure Dart.
Riverpod is the only dependency-injection mechanism; `bootstrap()` builds
one `ProviderContainer`. Architecture tests enforce the import rules.
Details: [ARCHITECTURE.md](ARCHITECTURE.md).

## Folder structure

```text
proxy-care-client/
├── android/ ios/ web/       Platform projects
├── assets/fonts/            Bundled Noto Sans Devanagari (OFL)
├── config/env/              Non-secret compile-time configuration per environment
├── docs/                    Feature guide, navigation, deep links, observability,
│                            design-system mapping
├── lib/
│   ├── main.dart            Entry point: bootstrap, then runApp
│   ├── app.dart             Root widget: theme, localization, router
│   ├── app_routes.dart      The list of feature route modules
│   ├── core/                Infrastructure:
│   │   ├── auth/            Session abstraction, Supabase adapter, authorization
│   │   ├── config/          Env parsing and validation
│   │   ├── connectivity/    Network connection status
│   │   ├── di/              Providers, container, bootstrap
│   │   ├── error/           Exceptions, failures, error mapper, reporters
│   │   ├── formatting/      Date/time rules, formatters
│   │   ├── l10n/            ARB strings and generated localizations
│   │   ├── lifecycle/       App lifecycle phases
│   │   ├── logging/         AppLogger with redaction
│   │   ├── network/         ApiClient, Dio factory, interceptors
│   │   ├── notifications/   Push notification interfaces
│   │   ├── observability/   Analytics and performance interfaces
│   │   ├── platform/        Platform information
│   │   ├── router/          The single GoRouter, guards, deep links
│   │   ├── security/        Secure storage, redaction, session cleanup
│   │   └── theme/           Design tokens, ThemeData, breakpoints
│   ├── features/            One folder per feature (data/domain/presentation);
│   │                        auth/ (empty layers) and the dev-only widget_showcase/
│   └── shared/              Result type, design-system widgets
├── test/                    Mirrors lib/; integration/, helpers/, fixtures/, mocks/
├── tool/                    check_env.dart, GitHub Pages redirect
├── Makefile                 Developer commands
└── pubspec.yaml
```

## Environment configuration

Configuration is compile-time (`--dart-define-from-file=config/env/<env>.json`)
and validated at start-up by `Env.fromEnvironment()`, which throws an
`EnvConfigException` listing every problem.

| Define | Values | Default |
| --- | --- | --- |
| `APP_ENV` | `development`, `staging`, `production` | `development` in debug builds and tests only; **required** in release builds and config files |
| `API_BASE_URL` | Absolute `http`/`https` URL, no query or fragment | `http://localhost:8080`, development only |
| `APP_NAME` | Any text | `Proxy Care` |
| `ENABLE_LOGGING` | `true` / `false` | `false` in production, otherwise `true` |
| `FEATURE_FLAGS` | Comma-separated snake_case names | none |
| `SUPABASE_URL` | Supabase project URL | required in staging and production; optional in development (signed out) |
| `SUPABASE_PUBLISHABLE_KEY` | Publishable key (`sb_publishable_…`); secret and service-role keys are rejected | as above, together with `SUPABASE_URL` |

Staging and production need an `https` `API_BASE_URL` (production may not
point to a local host) and the Supabase settings; a release build never
falls back to development. `config/env/*.json` holds **non-sensitive**
values only: `--dart-define` values are readable from the app binary.
`staging.json` and `production.json` are deliberately incomplete until the
URLs and keys exist, so those builds fail validation. Check a file with
`make check-env ENV=production`.

## Local development

Prerequisites:

| For | Install |
| --- | --- |
| All | Flutter 3.50.0 (`flutter --version`), `make`, `jq` (used by CI checks) |
| Android | Android Studio or the command-line tools with an SDK and the NDK Flutter requests, **JDK 21** (`flutter doctor` must show the Android toolchain) |
| iOS | macOS, Xcode with command-line tools, CocoaPods only if Flutter asks for it |
| Web | Chrome |

```sh
cd proxy-care-client
make get        # flutter pub get
make gen        # build_runner + flutter gen-l10n
make analyze
make test
make run-user   # or run-caretaker: Android, --flavor + APP_VARIANT
# iOS, web: flutter run --dart-define=APP_VARIANT=user \
#   --dart-define-from-file=config/env/development.json   # add -d <device>
```

The development config points at a backend on `http://localhost:8080`; on
the Android emulator use `http://10.0.2.2:8080` in a local copy of the
config. Plain http is allowed in Android debug builds only. Without
Supabase settings the app runs signed out.

Generated files (`*.g.dart`, `*.freezed.dart`, `lib/core/l10n/generated/`)
are committed: after changing an annotated model or an ARB file run
`make gen` and `make format`, and commit the result. Never edit them.

## Build commands

| Command | What it does |
| --- | --- |
| `make get` / `make get-locked` | `flutter pub get` (updates the lockfile) / with `--enforce-lockfile` |
| `make gen` | `dart run build_runner build --delete-conflicting-outputs`, then `flutter gen-l10n` |
| `make format` / `make format-check` | `dart format .` / fail if anything is unformatted |
| `make analyze` | `flutter analyze` (strict settings) |
| `make test` | `flutter test` |
| `make goldens` | Regenerate golden images (Linux; see TESTING.md) |
| `make check-env [ENV=…]` | Validate `config/env/<ENV>.json` |
| `make run-user` / `make run-caretaker [ENV=…]` | Validate, then `flutter run` that app's Android flavor |
| `make build-android [ENV=…] [VARIANT=…]` | Validate, then `flutter build apk --release` and `flutter build appbundle --release` for the `VARIANT` flavor (`build-android-user`, `build-android-caretaker`) |
| `make build-ios [ENV=…] [VARIANT=…]` | Validate, then `flutter build ios --release --no-codesign` (macOS; `build-ios-user`, `build-ios-caretaker`) |
| `make build-web [ENV=…] [VARIANT=…]` | Validate, then `flutter build web --release` |
| `make build-showcase [BASE_HREF=…]` | Web build of the widget showcase |

`ENV` defaults to `development`, `VARIANT` to `user`. Outputs: `build/app/outputs/` (Android),
`build/ios/iphoneos/Runner.app` (iOS), `build/web/`.

## API integration

Repositories call the backend through `ApiClient` (`apiClientProvider`),
never Dio directly. Requests go to `<API_BASE_URL>/api/v1`. The client
reads bare JSON success bodies (a 2xx is a success) with a typed decoder,
maps the backend's `ApiError` bodies to
exceptions, exposes `ETag` and sends `If-Match` (not enforced by the
backend today; a version clash is 409 `CONCURRENT_MODIFICATION`), sends
JSON, supports multipart uploads, downloads, page-number pagination, idempotency
keys (not enforced by the backend today) and cancellation, and throws only
`AppException`s. Interceptors, in
order: correlation ID, logging (redacted), authentication (bearer token,
one replay after a 401), retry (GET only on 502/503/504, 429 with
`Retry-After`, and transient connection errors; bounded backoff that
honours `Retry-After`; the backend sends no `Retry-After` today). Details:
ARCHITECTURE.md, "Networking".

## Error handling

Infrastructure errors become `AppException`s in the data layer
(`ErrorMapper` reads the backend's `ApiError` body and `ErrorCode`
names, falling back to the HTTP status for an unknown code); repositories
return
`Result<T>` with typed `AppFailure`s (`guardResult`); presentation maps
failures to localized messages (`failureMessage`). Uncaught errors go to
the `ErrorReporter` and a privacy-safe `CrashReporter` (no-op until a
vendor is added). Details: ARCHITECTURE.md, "Errors".

## Authentication

Supabase Auth issues sessions; the Spring Boot API validates its JWTs. The
SDK owns refresh, rotation and lifecycle; the app maps its events to
`AuthenticationState` (initializing, authenticated, unauthenticated,
session expired) and exposes the session to Dio only through
`AccessTokenProvider`. No sign-in screens exist yet. Details:
[AUTHENTICATION.md](AUTHENTICATION.md).

## Secure storage

The whole Supabase session is stored as one entry through
`SecureKeyValueStore` (`flutter_secure_storage`): Android Keystore with
AES-GCM, iOS Keychain (`first_unlock_this_device`, not synced), WebCrypto
on web (weaker, documented). Nothing is written to SharedPreferences.
Details: [SECURITY.md](SECURITY.md).

## Routing

One `GoRouter` assembled from feature `RouteModule`s listed in
`lib/app_routes.dart`. Every route declares `RouteAccess` (public,
guest-only, authenticated with optional roles, permissions and feature);
pure guards redirect and preserve the intended destination. Identity goes
in path parameters, never in extras. Details:
[docs/navigation.md](docs/navigation.md).

## Deep links

go_router handles links at cold start and while running; the deep-link
policy accepts only `https` links on configured hosts, and guards apply as
for any navigation. Android App Links and iOS Universal Links are wired
with the reserved placeholder host `app-links.invalid`; replace it when a
domain is owned. Details: [docs/deep-linking.md](docs/deep-linking.md).

## State management

Riverpod 3: top-level `Provider`s for services (typed as interfaces),
`Notifier` / `AsyncNotifier` controllers for screen state, overrides for
tests and environment-specific implementations. Widgets read controllers;
business rules live in domain use cases or repositories, never in widgets.
Conventions: ARCHITECTURE.md, "Dependency injection" and
[docs/feature-guide.md](docs/feature-guide.md).

## Design system

The UI follows the Proxy Care Design System
(`claude/proxycare-design-system.md` in the Proxy Care project), the single
source of truth: tokens and `ThemeData` in `lib/core/theme/`, components in
`lib/shared/widgets/` (`PcButton`, `PcTextField`, `PcCard`, …), mapped in
[docs/design-system-mapping.md](docs/design-system-mapping.md). Light theme
only, in two densities: standard (family app) and comfortable (caretaker
app).

**Widget showcase.** `/widget-showcase` shows every component with its
variants and states. It is a development preview, registered only when
`FEATURE_FLAGS` contains `widget_showcase` and `APP_ENV` is not
`production` (`config/env/showcase.json`), and is published to GitHub
Pages by `pages.yml`.

## Testing

`flutter test` runs unit, widget, integration (`test/integration/`,
mocked backend) and golden tests (`--tags golden`, Linux only); nothing
touches the network. Layout, helpers and rules:
[TESTING.md](TESTING.md).

## Continuous integration

`.github/workflows/ci.yml` runs on pull requests and pushes to `main`
touching `proxy-care-client/`, with Flutter 3.50.0:

| Job | Runner | Steps |
| --- | --- | --- |
| Web | Ubuntu | get, gen, format; fail if the lockfile, generated files or formatting changed; analyze; test; config checks (release configs never fall back to development); `make build-web` |
| Android | Ubuntu, JDK 21 | get (locked), gen, format check, analyze, test, `make build-android-user` and `build-android-caretaker` (APK + App Bundle) |
| iOS | macOS, latest stable Xcode | get (locked), gen, format check, analyze, test, `make build-ios-user` and `build-ios-caretaker` (no code signing) |

No signing credentials are used and nothing is deployed to a store. Other
workflows: `pages.yml` (widget showcase on GitHub Pages) and `goldens.yml`
(bless golden images on a feature branch).

## Android configuration

- **Flavors** (dimension `app`): `user` = `com.proxycare.user`, label
  "proxy-care"; `caretaker` = `com.proxycare.caretaker`, label
  "proxy-caretaker" (`manifestPlaceholders["appName"]` → `android:label="${appName}"`). The Kotlin namespace stays
  `com.proxycare.proxy_care_client`. Every build needs `--flavor` and the
  matching `--dart-define=APP_VARIANT`. IDs cannot change after publishing.
- **Permissions:** `INTERNET`; `ACCESS_NETWORK_STATE` comes from
  `connectivity_plus`.
- **Backups off:** `allowBackup="false"`, `fullBackupContent="false"` and
  `data_extraction_rules.xml` exclude all data from cloud backup and device
  transfer (Keystore-encrypted storage cannot be restored elsewhere).
- **Deep links:** `flutter_deeplinking_enabled` and an `autoVerify` App
  Links intent filter for `https://${appLinkHost}`; set the host with
  `-PappLinkHost=<domain>` (default `app-links.invalid`).
- **Signing:** release builds are signed with the debug key so CI needs no
  credentials. For a store release, create an upload key outside the
  repository, add a release `signingConfig` that reads it from a
  git-ignored `key.properties` or CI secrets, and enable Play App Signing.
  Never commit keystores or passwords.
- **Before release:** app icon, display name check, `versionCode` /
  `versionName` from `pubspec.yaml`, R8 and obfuscation decision, Data
  Safety form (see SECURITY.md).

## iOS configuration

- **Bundle ID** `com.proxycare.client` (placeholder), display name "Proxy
  Care", minimum iOS 15.0. Both apps build from the `Runner` scheme with
  only `APP_VARIANT` set. Still to do in Xcode: `Debug-`/`Release-`/
  `Profile-` `user` and `caretaker` build configurations, `user` and
  `caretaker` schemes, `PRODUCT_BUNDLE_IDENTIFIER` `com.proxycare.user` /
  `com.proxycare.caretaker` and display names "proxy-care" /
  "proxy-caretaker"; then add `--flavor` to `make build-ios`.
- **Keychain:** `flutter_secure_storage` with
  `first_unlock_this_device`, not synchronized. No extra entitlement is
  needed for the app's own Keychain items. Keychain items survive
  uninstall; clearing them on the first launch after a reinstall is pending
  (SECURITY.md).
- **Deep links:** `FlutterDeepLinkingEnabled` in `Info.plist`;
  `Runner.entitlements` declares Associated Domains with the placeholder
  `applinks:app-links.invalid`. Signing for a device needs the Associated
  Domains capability on the App ID, or the entry removed until a domain
  exists.
- **Signing:** CI builds with `--no-codesign`. Set the development team and
  provisioning in Xcode (never commit certificates or profiles).
- **Before release:** app icon, privacy manifest (`PrivacyInfo.xcprivacy`)
  and App Store privacy labels, export-compliance key.

## MVP decisions

| Decision | Status |
| --- | --- |
| Commit `pubspec.lock` | Implemented; CI checks it |
| Commit generated files; CI fails if regeneration changes them | Implemented |
| Non-sensitive config in `config/env/*.json`; production never falls back to development | Implemented |
| Android and iOS | Implemented in Milestone 10 (web kept); placeholder IDs |
| Native platform typography; bundle Noto Sans Devanagari only | Implemented |
| Flutter's built-in Material icons | Implemented |
| Provisional breakpoints: compact < 600dp, tablet ≥ 600dp, 720dp max content width | Implemented in `PcBreakpoints` |
| Light theme only | Implemented |
| Backend `ApiError` bodies, `ErrorCode` names and `PageResponse` pages (`com.proxycare.common.api.ApiError`, `common.exception.ErrorCode`, `common.api.PageResponse`) | Implemented in `BackendErrorParser` and `ErrorMapper` |
| Vendor-independent crash reporter, no-op for the MVP (Crashlytics is LL-05) | Implemented |
| Localized user-facing error messages (ARB, English) | Implemented in `core/l10n` |
