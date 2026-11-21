---
name: kafka-event
description: Add or change a Kafka event in proxy-care-server — topic, envelope, outbox publisher, idempotent consumer, DLT, schema evolution and tests. Use whenever a context publishes or consumes an event.
---

# Kafka event

Rules: `.claude/rules/kafka-messaging.md`.

## Add an event
1. Name: `proxycare.<context>.<entity>.<event>.v1`; add a `NewTopic` bean
   (partitions per env config, replication ≥ 3 in prod) and its `.dlt`.
2. Payload record in the publishing context's `domain/event` package — ids,
   states, amounts in paise; **no PII**.
3. Publish through the outbox: insert `outbox_event` row in the same
   transaction as the aggregate change; relay publishes with key = aggregate
   id and the envelope headers (`eventId`, `eventType`, `schemaVersion`, `traceId`).
4. Consumer in `adapter.in.kafka` of the receiving context:
   - dedupe by `eventId` (`processed_event` table, unique key) in the same
     transaction as its side effect;
   - ignore stale events by aggregate version/state;
   - `DefaultErrorHandler` with backoff → `DeadLetterPublishingRecoverer`.
5. Tests (Testcontainers Kafka): publish → consumed effect; duplicate
   delivery → one effect; poison message → lands in DLT; rollback of the
   business transaction → no event.

## Change an event
- Additive optional field: same topic, bump `schemaVersion` minor; consumers
  must tolerate absence.
- Breaking change: new `.v2` topic, dual-publish until all consumers migrate,
  document the removal date in the PR.
