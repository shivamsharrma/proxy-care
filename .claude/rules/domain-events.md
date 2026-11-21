---
paths:
  - "proxy-care-backend/**/event/**"
  - "proxy-care-backend/**/listener/**"
  - "proxy-care-backend/**/*Event*.java"
  - "proxy-care-backend/**/*Listener*.java"
---
# Domain events

Events are how one feature reacts to something that happened in another
(`proxy-care-backend/ARCHITECTURE.md` → Layers). They are in-process Spring
application events; there is no message broker yet.

## Publishing
- An event is a record in the publishing feature's `event/` package, named in
  the past tense: `<Thing><Happened>Event` (e.g. `PaymentRequestPaidEvent`).
- Payload: ids and the new state only (`bookingId`, `paymentRequestId`,
  status, amount in paise). Never personal data: no names, phones, addresses,
  medical purposes, pickup codes or location.
- The service publishes it with `ApplicationEventPublisher` after the state
  change, inside the same `@Transactional` method. Controllers and
  repositories never publish.

## Listening
- Listeners live in the **consuming** feature's `listener/` package
  (`<Feature><Event>Listener`) and call that feature's own service; they
  don't touch the publisher's tables.
- Default to `@TransactionalEventListener` (`AFTER_COMMIT`), so nothing reacts
  to a change that rolled back. Use `@EventListener` only when the reaction
  must be part of the publisher's transaction, and say why in a comment.
- Listeners are idempotent: the same event handled twice leaves the same state.
  A failure in an after-commit listener doesn't undo the publisher, so log it
  (ids only) and make the work retryable.

## Tests
- Integration test (`extends IntegrationTest`): perform the action, assert the
  consuming feature's observable state; cover a rolled-back publisher producing
  no reaction and a duplicate event being harmless.