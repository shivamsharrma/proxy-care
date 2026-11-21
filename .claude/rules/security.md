# Security

- **Secrets:** never read, print, or commit `.env*`, `*.pem`, `*.p12`,
  `*.jks`, `*.keystore`, `key.properties`, `google-services.json`,
  `GoogleService-Info.plist`, `~/.aws/*`, or anything under `secrets/`.
  Hooks block this; don't try to work around them. Need a value? Ask the user.
- `proxy-care-client/config/env/*.json` is committed and holds only public
  values (API URL, Supabase URL + publishable key, Razorpay `key_id`).
- Backend secrets (DB password, Razorpay, Uber, Maps keys) arrive only as
  environment variables (`proxy-care-backend/README.md` table); the app fails
  to start when a required one is missing. Placeholders go in `.env.example`.
- **AuthZ on the server.** The client hides UI; the server enforces. Every
  booking/payment/ride endpoint checks the caller owns or is assigned to the
  resource (mirror `*_access_control.feature`). The caller comes only from
  the verified token (`ISecurityIdentityProvider`), never from the request;
  someone else's resource is a 404.
- **Database:** RLS is on with no policies on every table, so Supabase's
  public keys can read or write nothing; only the backend's dedicated
  Postgres role touches data. Never the `service_role` key in the backend.
- **Input:** validate at the boundary (Bean Validation / domain factories);
  parameterized queries only; no string-built SQL or JPQL.
- **PII:** patient names, phone numbers, addresses, medical purposes, pickup
  codes, live location — never in logs, analytics, crash reports, Kafka
  payloads beyond ids, or URLs. Redact via the client's redacting logger.
- **Mobile:** no cleartext traffic except the documented local-debug
  exception; backups disabled; deep links validated before navigation.
- **Dependencies:** no new package without checking maintenance, licence and
  transitive tree; no telemetry SDKs without a decision.
- Destructive or outward-facing actions (deploys, migrations on shared DBs,
  refunds, `gh pr merge`) require explicit human approval each time.
