# Testing

How tests are organized and written in the Proxy Care client. Run them with
`make test` (all), `flutter test test/core/network` (a folder) or
`flutter test --tags golden` (goldens only). CI runs everything on every
push; nothing touches the network.

## Layout

`test/` mirrors `lib/`: the test for `lib/core/network/dio_factory.dart` is
`test/core/network/dio_factory_test.dart`.

| Folder | Contents |
| --- | --- |
| `core/`, `shared/`, `features/` | Unit and widget tests, mirroring `lib/` |
| `app_test.dart` | The root widget |
| `integration/` | The real bootstrap, router, networking and root widget together, with mocked edges |
| `architecture/` | Import rules between layers |
| `helpers/` | Reusable test utilities (below) |
| `fixtures/` | Test data builders (`testEnv`, …) |
| `mocks/` | mocktail mocks and recording doubles |

Golden images sit next to their test in `goldens/`.

## Tools

`flutter_test`, `mocktail`, Riverpod provider overrides, and a fake Dio
`HttpClientAdapter` (`helpers/fake_http_adapter.dart`). No other test
packages: add one only when these cannot express a test.

## Helpers

| Need | Use |
| --- | --- |
| A configured container | `createTestContainer(env:, overrides:)` (`helpers/provider_container.dart`): wired like the app, disposed after the test |
| Test configuration | `testEnv(...)` (`fixtures/env_fixtures.dart`): a valid development `Env`; override only what the test cares about |
| HTTP responses | `FakeHttpAdapter` with `respondJson`, `dataBody`, `pageMeta`, `respondProblem`, `problemBody`, `fieldError`; it records every attempt (`requests`) |
| The networking stack | `NetworkHarness` (`helpers/network_harness.dart`) |
| Token storage | `FakeSecureKeyValueStore` (`helpers/auth_fakes.dart`), with switchable read, write and delete failures |
| A session | `FakeAuthenticationSession` (`emit`, `token`, `tokenAfterRefresh`, `refreshes`), `MockGoTrueClient`, `fakeSession`, `fakeJwt` |
| The router | `RouterHarness.pump`, `TestRouteModule`, `deliverPlatformLink`, `signedIn()` (`helpers/router_harness.dart`) |
| Themed widgets | `pumpThemed` and `contrastRatio` (`helpers/pump_themed.dart`) |
| Goldens | `goldenTest` (`helpers/golden.dart`) |
| Assertions | `isSuccessWith`, `isFailureOf<F>`, `throwsAppException<E>` (`helpers/matchers.dart`) |
| Logs and errors | `RecordingLogger`, `MockErrorReporter` (`mocks/core_mocks.dart`) |

**Fake repositories.** When a feature adds a repository interface, its fake
lives in `test/features/<feature>/fakes.dart`: a hand-written class that
implements the interface over an in-memory map, with switchable failures
(returning a `Failure`, as the real one would). No repository exists yet.

## Rules

- **Test behaviour, not implementation.** Assert what a caller can observe:
  return values, state, requests sent, navigation, what is rendered and
  announced. Don't verify private calls or call order unless order is the
  behaviour (interceptor ordering).
- **Fakes over mocks.** Use a fake for anything stable you own (storage,
  sessions, HTTP). Use a mocktail mock only for a third-party class you
  cannot fake (`GoTrueClient`, `Connectivity`) or to verify a single
  reported error.
- **Override providers, don't reach inside.** Replace dependencies with
  `overrides:`; build the rest exactly as the app does.
- **Cover failure and concurrency.** For each component: the error paths
  (timeouts, 401/403/5xx, rejected refresh, storage failures, invalid
  input) and, where shared state exists, concurrent use (concurrent 401s
  sharing one refresh).
- **Deterministic.** No real network, clock or randomness in assertions:
  inject clocks and delays (`retryDelay`, `LoggingInterceptor` clock), use
  fixed dates, await streams explicitly (`Future<void>.delayed(Duration.zero)`
  for one turn), and use `tester.runAsync` only for real asynchronous I/O
  (Dio) inside widget tests.
- **No secrets, even fake ones that look real,** outside `auth_fakes.dart`.
- **No product screens.** Tests use test-only routes (`TestRouteModule`)
  until features exist.

## Widget tests

Widget tests cover the root app, the theme, design-system components, their
accessibility semantics and other reusable primitives (`test/shared`). For a
component, check the documented sizes, colors and states with
`tester.getSize`, the rendered widgets' properties and `contrastRatio`, and
its semantics (labels, roles, button/header flags) with `tester.getSemantics`
or `find.bySemanticsLabel`.

## Integration tests

`test/integration/` runs the real `bootstrap()` and `ProxyCareApp` with
three edges replaced: the authentication session (fake), the HTTP adapter
and the route modules. They cover start-up, the router, deep links (cold
start and running), the authentication guards and the session lifecycle
(token, refresh, expiry, cleanup). They run with `flutter test` in CI,
without a device. Device-level tests (the `integration_test` package) will
be added in `integration_test/` with the Android and iOS targets.

## Golden tests

Goldens cover documented design-system components only
(`test/shared/widgets/design_system_golden_test.dart`): one image per
component family, showing the variants and states the design system
(`claude/proxycare-design-system.md`, mapped in
`docs/design-system-mapping.md`) specifies.

- Text renders as Ahem blocks: goldens check colors, shapes, borders,
  spacing and sizes. Type is tested against the type scale in unit tests.
- Images are blessed only by the **Bless goldens** workflow (Actions → Bless
  goldens → Run workflow, on your feature branch; it refuses `main`). It
  renders on the same runner and Flutter version as CI and commits the
  images to the branch as "Bless goldens".
- Review every changed image against the design system before merging, and
  revert the "Bless goldens" commit if one is wrong. Never bless to make
  a failing test pass.
- Goldens are skipped on macOS and Windows, which render slightly
  differently.
