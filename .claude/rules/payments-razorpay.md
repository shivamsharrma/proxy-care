---
paths:
  - "proxy-care-server/**/payment/**"
  - "proxy-care-client/lib/features/*payment*/**"
  - "proxy-care-client/lib/features/**/payment*"
  - "atdd/test-specs/**/*payment*.feature"
---
# Payments (Razorpay)

Who pays: the sponsoring **user** (family) pays payment requests; the
**caretaker never pays with their own money** (see specs tagged `@payments`).

## Money
- Integer paise (`long`/`int`) end to end; INR only. Display via the rupee
  formatter. No floating point anywhere money flows.

## Flow
1. Server creates the Razorpay **order** for a payment request (amount from
   the server's record, never the client) with `receipt = paymentRequestId`.
2. Client opens Razorpay Checkout with `key_id` + `order_id` only.
3. Client sends `razorpay_order_id`, `razorpay_payment_id`,
   `razorpay_signature` to the server.
4. Server verifies `HMAC_SHA256(order_id + "|" + payment_id, key_secret)` in
   constant time, then marks the request PAID.
5. The **webhook** (`payment.captured`, `payment.failed`, `refund.*`) is the
   authoritative backstop: verify `X-Razorpay-Signature` over the **raw body**
   with the webhook secret, dedupe by event id, apply idempotently.

## Rules
- `key_secret` and webhook secret live only in server secrets (AWS Secrets
  Manager). The client never sees them.
- Payment request states: `REQUESTED → PAID | FAILED` (+ refund states).
  Transitions are idempotent; a late `failed` never overrides `PAID`.
- The client's success callback only triggers a refresh — UI shows PAID
  only after the server says so.
- Emit `proxycare.payment.request.<state>.v1` via the outbox.
- Never log card, UPI VPA, or full payment payloads.
- Tests use Razorpay test-mode fixtures and computed signatures; never live keys.
