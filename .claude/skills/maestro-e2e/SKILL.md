---
name: maestro-e2e
description: Write and run Maestro YAML E2E flows that map 1:1 to Gherkin scenarios for the Proxy Care app (Android/iOS). Use when writing E2E tests, translating a .feature scenario into a flow, or running E2E locally.
---

# Maestro E2E

Mapping rules: `.claude/rules/testing-standards.md` (§ Maestro ↔ Gherkin).

## Layout
```text
proxy-care-client/maestro/
├── _shared/                 subflows: login_as.yaml, open_screen.yaml, seed.yaml
├── config.yaml              flows: ["**"], excludeTags: [wip]
└── <feature>/<spec-stem>/<scenario-slug>.yaml
```
`<scenario-slug>` = scenario title lowercased, non-alphanumerics → `-`.

## Translating a scenario
```yaml
appId: com.proxycare.client
name: "P9a shows the fare and that the request was sent"
tags: [regression, caretaker-app, pickup-and-ride, P9a, payments, smoke, happy-path]
# spec: atdd/test-specs/pickup-and-ride/05_caretaker_ride_payment.feature
env:
  BOOKING: PC-2481
---
- runFlow: { file: ../../_shared/seed.yaml, env: { FIXTURE: p9a_requested } }   # Background + Given
- runFlow: { file: ../../_shared/login_as.yaml, env: { USER: anita.verma } }
- launchApp
- runFlow: { file: ../../_shared/open_screen.yaml, env: { SCREEN: P9a } }        # When
- assertVisible: "₹340"                                                          # Then
- assertVisible: "Sunil Yadav"
- assertVisible: "Payment request sent to Rohan"
- assertVisible: { id: "remind-family-button", enabled: true }
```
- Given → seed + login (never click through other screens to set up state).
- When → taps/inputs by `id:` (Semantics identifier) or exact ARB text.
- Then → `assertVisible` / `assertNotVisible`; "enabled/disabled" via `enabled:`.
- Scenario Outline → one flow per Examples row, or a parameterized flow
  driven by `env` from a wrapper per row.
- Realtime changes ("changes to Rohan paid"): seed the transition via the
  seed endpoint, then `extendedWaitUntil: { visible: "Rohan paid", timeout: 10000 }`
  — no `waitForAnimationToEnd` loops or fixed sleeps.

## Running
- Build + install a debug app with a test config, start emulator/simulator.
- `maestro test maestro/<feature>/ --include-tags smoke`
- `maestro test --format junit --output build/maestro.xml maestro/`
- `maestro check-syntax <flow>` for a quick validity check without a device.
- If no device is available, say E2E was NOT RUN.
