---
paths:
  - "proxy-care-server/**/kafka/**"
  - "proxy-care-server/**/*Event*.java"
  - "proxy-care-server/**/*Consumer*.java"
  - "proxy-care-server/**/*Producer*.java"
  - "proxy-care-server/**/events/**"
---
# Kafka messaging

- **Topics:** `proxycare.<context>.<entity>.<event>.v<major>`, e.g.
  `proxycare.payment.request.paid.v1`. Declared as `NewTopic` beans; never
  auto-created.
- **Keys:** the aggregate id (`bookingId` for booking/ride/payment events) so
  one booking's events stay ordered on one partition.
- **Envelope:** `eventId` (UUID), `eventType`, `occurredAt` (UTC),
  `aggregateId`, `schemaVersion`, `traceId`, `payload`. Payloads carry ids
  and state, not PII.
- **Publishing:** transactional outbox. Write the event row in the same DB
  transaction as the state change; a relay publishes it. Never call
  `KafkaTemplate.send` inside `@Transactional` business code.
- **Consuming:** idempotent. Record processed `eventId`s (unique constraint)
  and skip duplicates. Handle out-of-order events by comparing aggregate
  version/state.
- **Failures:** bounded retries with backoff, then a dead-letter topic
  `<topic>.dlt`. A DLT message raises an alert; never swallow and ack.
- **Schema evolution:** additive and backward-compatible within a major
  version. Removing/renaming a field means a new `.v<n+1>` topic and a
  dual-publish period.
- **Tests:** Testcontainers Kafka; assert on consumed messages, cover
  duplicate delivery and poison messages.
