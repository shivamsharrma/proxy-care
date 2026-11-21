---
name: razorpay-integration
description: Implement Razorpay payment-request flows for Proxy Care — server order creation, client Checkout, signature verification, webhooks, refunds, and tests in test mode. Use for any payment request, fare, bill or refund work.
---

# Razorpay integration

Rules: `.claude/rules/payments-razorpay.md` (read first — money in paise,
caretaker never pays, server decides PAID).

## Server (`com.proxycare.payment`)
- Port `PaymentGateway` { `createOrder(paymentRequestId, amountPaise)`,
  `fetchPayment(id)`, `refund(...)` }; `adapter.out.razorpay` implements it
  with the Razorpay Java SDK or plain HTTP (basic auth `key_id:key_secret`
  from config/secrets).
- `POST /api/v1/payment-requests/{id}/order` → `{orderId, amount, currency, keyId}`;
  only the sponsoring user may call it; reuse an existing open order.
- `POST /api/v1/payment-requests/{id}/verify` with the three
  `razorpay_*` fields → verify HMAC (constant-time) → PAID (idempotent).
- `POST /webhooks/razorpay` (no JWT): verify `X-Razorpay-Signature` on the
  raw request bytes with the webhook secret; store event id; handle
  `payment.captured`, `payment.failed`, `order.paid`, `refund.processed`.
- Outbox event `proxycare.payment.request.paid.v1` (and failed/refunded).
- Reconciliation job: requests stuck in REQUESTED with a Razorpay order →
  fetch status and apply.

## Client
- Payment flow behind a `PaymentCheckout` service interface in `core/services`
  (plugin adapter in data layer) so widget tests fake it.
- After Checkout success: call verify, then refresh/await realtime PAID —
  show "processing" until the server confirms. Failure/cancel → stay
  REQUESTED with a retry.
- Only `key_id` from the server response; nothing payment-secret in config.

## Tests
- Signature fixtures computed in-test with a fake secret constant.
- WireMock for Razorpay API; webhook tests with tampered signature/body → 400.
- Client: fake `PaymentCheckout` returning success/failure/cancel.
- Maestro: test-mode only; seed requests via backend seed, assert texts from specs.
