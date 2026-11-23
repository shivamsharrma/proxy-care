# Architecture

A single Spring Boot API shared by the Proxy Care User and Caretaker apps. Supabase provides Postgres, phone-OTP
sign-in and storage. This service is the only writer of business data. How to build and run it: [README.md](README.md).

```
Flutter apps ──(Supabase access token)──▶ this API ──▶ Supabase Postgres
      │                                      ▲
      └──(phone OTP)──▶ Supabase Auth ──keys─┘
```

## Layers

```
com.proxycare
├── features/<feature>/          Business features, one package each, split by layer
├── infrastructure/<capability>/ Calls we make to vendors (payments, maps, rides), behind our own interfaces
├── common/                      Cross-cutting: security, errors, API shapes, web filters, persistence base,
│                                model/ (value enums shared by several features, e.g. Sex)
└── config/                      App-wide wiring that belongs to no single feature
```

A feature, using `user` as the example:

```
features/user/
├── controller/          HTTP only
├── dto/
│   ├── request/         Incoming bodies, validated
│   └── response/        Outgoing bodies, never an entity
├── service/             IUserService (what others depend on) and UserService
├── repository/
├── entity/
├── mapper/              Entity ↔ DTO
├── event/               Published after something happened
├── listener/            Handlers for events
├── exception/
├── enums/
└── constants/
```

A feature creates only the sub-packages it needs.

An infrastructure capability, using `payment` with Razorpay as the example:

```
infrastructure/payment/
├── gateway/
│   └── IPaymentGateway                  The interface features depend on, in business terms
├── model/
│   ├── CreateOrderCommand               Input, with no vendor names
│   └── PaymentOrder                     Output, with no vendor names
├── exception/
│   └── PaymentDeclinedException         Only for failures the app must react to differently
│
└── razorpay/                            One vendor, hidden from features
    ├── config/
    │   ├── RazorpayConfig               Builds the vendor client, with timeouts
    │   └── RazorpayProperties           The vendor's keys and URLs
    ├── gateway/
    │   └── RazorpayPaymentGateway       Implements IPaymentGateway; the only class that calls Razorpay
    ├── mapper/
    │   └── RazorpayMapper               Our models ↔ vendor DTOs
    └── dto/
        ├── request/
        │   └── RazorpayOrderRequest     The vendor's request JSON
        └── response/
            └── RazorpayOrderResponse    The vendor's response JSON
```

A second vendor is a sibling of `razorpay/` that implements the same interface. Any other vendor failure becomes
the standard external-service error.

Dependencies point one way: `features` → `infrastructure` interfaces → `common` → `config`. Never the reverse.

- **Features** talk to each other only through a service interface or events, never another feature's tables.
- **Within a feature:** controller → service interface → repository. Controllers handle HTTP only; entities
  never leave the service.
- **Vendors** are hidden behind a capability interface (e.g. a payment gateway). Swapping a vendor touches no
  feature, and vendor failures never leak past it.

## Request flow

1. A trace id is assigned, and every log line and error body carries it.
2. One access log line is written per request.
3. Oversized bodies are rejected and API responses are marked not cacheable.
4. The Supabase token is verified and the caller's roles are loaded.
5. The feature runs.
6. Any failure becomes the standard error body.

## Decisions

- **Auth is Supabase's, verification is ours.** The backend never sees OTPs or passwords. It is stateless and
  verifies each token against Supabase's public keys. Roles live in our database, so changes apply on the next
  request.
- **Deny by default.** Only `/api/**` is reachable, and only with a valid token. Health and info are public. Making
  any other path public is an explicit, tested decision.
- **Ownership comes from the token.** Whose data to touch is never taken from the request. Someone else's resource
  is a 404, not a 403.
- **One error contract.** Every error, including 401 and 403, has the same JSON body with a stable `code`. The apps
  switch on `code` and show their own English/Hindi text. Codes are never renamed or reused.
- **The database is locked to everyone but us.** Row-level security is on for every table with no policies, so
  Supabase's public keys can't read or write anything. Flyway owns the schema, and migrations are forward-only.
- **Personal data is never logged.** This covers phones, OTPs, IDs, bank details, health notes, location and
  tokens. Logs hold only fields chosen explicitly.
- **Time and money are explicit.** Time comes from an injected clock and is stored in UTC. Money is integer paise.
- **Tests run against real infrastructure.** Integration tests share one Spring context and a real PostGIS
  container. The database is never mocked.
