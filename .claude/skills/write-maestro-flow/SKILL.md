---
name: write-maestro-flow
description: "Write and run Maestro YAML E2E flows that map 1:1 to Gherkin scenarios for the Proxy Care app (Android, iOS). Use when turning a .feature scenario into a flow, adding E2E coverage, or running E2E locally."
---

# Write a Maestro flow

Mapping rules (path, header, Given/When/Then, Outlines, selectors):
`.claude/rules/testing.md` → Maestro ↔ Gherkin mapping. This skill adds the
layout, a worked example and how to run.

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
appId: com.proxycare.caretaker   # each flow names its app: com.proxycare.user or com.proxycare.caretaker
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
- `id:` is the widget's `Semantics(identifier:)`; `text:` is the exact ARB text.
- Realtime changes ("changes to Rohan paid"): seed the transition via the
  seed endpoint, then `extendedWaitUntil: { visible: "Rohan paid", timeout: 10000 }`
  — no `waitForAnimationToEnd` loops or fixed sleeps.

## Running
- Build + install a debug app with a test config, start emulator/simulator.
- Smoke run: `testing.md` → Commands (E2E).
- `maestro test --format junit --output build/maestro.xml maestro/`
- `maestro check-syntax <flow>` for a quick validity check without a device.
- No device → E2E is NOT RUN (`testing.md` → Rules).
