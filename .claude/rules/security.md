# Security

- **Secrets:** never read, print, or commit `.env*` (except `.env.example`),
  `*.pem`, `*.p12`, `*.jks`, `*.keystore`, `key.properties`,
  `google-services.json`, `GoogleService-Info.plist`, `~/.aws/*`, or anything
  under `secrets/`. Hooks block this; don't work around them. Need a value?
  Ask the user.
- **Client keys:** `proxy-care-client/config/env/*.json` is committed and holds
  only public values (API URL, Supabase URL + publishable key, Razorpay
  `key_id`). Never a Supabase `service_role` key or Razorpay `key_secret` in
  the client.
- **Backend secrets** (DB password, Razorpay, Uber, Maps keys) arrive only as
  environment variables (`proxy-care-backend/README.md` table); the app fails
  to start when a required one is missing. Placeholders go in `.env.example`.
- **Never trust the client** for authorization or payment success — the server
  decides. Every booking/payment/ride endpoint checks the caller owns or is
  assigned to the resource (mirror `*_access_control.feature`). The caller
  comes only from the verified token (`ISecurityIdentityProvider`), never from
  the request; someone else's resource is a 404.
- **Database:** the backend connects as its own Postgres role; every table has
  RLS on with no policies (sole exception: the `caretaker-photos` Storage
  bucket, `auth-and-rls.md` → Schema and RLS); the `service_role` key is never used anywhere
  (mechanics: `auth-and-rls.md`).
- **Input:** validate at the boundary (Bean Validation / domain factories);
  parameterized queries only — no string-built SQL or JPQL.
- **PII:** patient names, phone numbers, addresses, medical purposes, pickup
  codes, live location, OTPs, identity documents, bank details, tokens —
  never in logs, analytics, crash reports, error messages, event payloads
  (ids only), or URLs. Log chosen fields only; on the client use the
  redacting logger.
- **Mobile:** no cleartext traffic except the documented local-debug
  exception; backups disabled; deep links validated before navigation.
- **Dependencies:** no new package without checking maintenance, licence and
  transitive tree, and telling the user first; no telemetry SDKs without a
  decision.
