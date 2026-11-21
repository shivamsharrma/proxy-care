---
name: uber-ride-adapter
description: Build or change the ride-provider integration (Uber, Rapido) behind a provider-neutral port in proxy-care-server's ride context — booking, status webhooks, fare, cancellation. Use for pickup-and-ride work.
---

# Ride provider adapter (Uber / Rapido)

Specs: `atdd/test-specs/pickup-and-ride/*.feature` (ride status, fare
payment, own transport option, live location/timeline).

## Shape
- Port `RideProvider` in `com.proxycare.ride.domain` — `quote`, `book`,
  `cancel`, `status` — speaking only domain types (`RideId`, `GeoPoint`,
  `Fare` in paise, `RideEvent`).
- `adapter.out.uber`, `adapter.out.rapido` implement it; their SDK/HTTP
  types never leave the adapter. Choose provider by config/feature flag.
- Anti-corruption mapping: provider statuses → domain `RideEvent`
  (`DRIVER_ASSIGNED`, `DRIVER_ARRIVING`, `TRIP_STARTED`, `TRIP_COMPLETED`,
  `CANCELLED`). Unknown statuses are logged and ignored, never crash.
- Webhooks `POST /webhooks/rides/<provider>`: verify signature, dedupe,
  apply via the ride aggregate (out-of-order safe), publish
  `proxycare.ride.trip.<event>.v1` via outbox.
- "Own transport" is a ride with provider `NONE` — same aggregate, no adapter call.
- On `TRIP_COMPLETED` with a fare, the payment context creates the
  `RIDE_TO_HOSPITAL` payment request (event-driven, not a direct call).

## Safety
- Sandbox credentials in non-prod; provider tokens in secrets only.
- Driver phone/plate and live location are PII: not in logs or Kafka.
- Provider outages: timeouts + circuit breaker; surface a domain failure the
  UI can show ("Book ride" retry / own transport).

## Tests
WireMock per provider (booking, errors, timeouts); webhook signature and
out-of-order sequences; mapping table test covering every provider status.
