# Proxy Care: entity design

Target Postgres schema for the backend. Behaviour comes from the `.feature` specs in
`atdd/test-specs/`; entity fields and enum values come from
`proxy-care-ui-ux-state-for-api-design.md` §1–§2. Where a limit appears in a spec, the
column check matches it.

**Conventions**
- Money is an `integer` count of paise. Columns end in `_paise`.
- Time is `timestamptz`. Every mutable table has `created_at` and `updated_at`.
- Every table has RLS enabled with no policies; only the backend's own role reads and
  writes (`.claude/rules/auth-and-rls.md`). The `alter table ... enable row level security`
  lines are left out below.
- Phone numbers are stored as `+91` followed by 10 digits starting with 6–9.
- PII columns (names, phones, addresses, health notes, KYC and bank data, pickup codes,
  location) never appear in logs or event payloads.

**Status against migrations:** `V1__extensions.sql` and `V2__profiles.sql` are applied.
`profiles` in V2 does not yet have the `roles` cardinality check or the `phone` format check.

---

## 1. Enums

```sql
create type app_role          as enum ('USER', 'CARETAKER', 'ADMIN');           -- applied in V2
create type sex_type          as enum ('FEMALE', 'MALE', 'OTHER');
create type relation_type     as enum ('FATHER', 'MOTHER', 'SPOUSE', 'GRANDPARENT', 'SIBLING', 'OTHER');
create type mobility_category as enum ('AMBULATORY', 'WHEELCHAIR', 'BEDRIDDEN');
create type kyc_status        as enum ('IN_PROGRESS', 'SUBMITTED', 'APPROVED', 'REJECTED');
create type marital_status    as enum ('SINGLE', 'MARRIED');
create type bank_validation   as enum ('PENDING', 'VALID', 'FAILED');

create type visit_purpose     as enum ('OPD', 'DIAGNOSTICS', 'DAY_CARE', 'ADMISSION_DISCHARGE', 'EMERGENCY');
create type booking_state     as enum ('PAYMENT_PENDING', 'WAITING', 'ASSIGNED', 'IN_PROGRESS',
                                       'COMPLETED', 'SETTLED', 'CANCELLED');
create type visit_stage       as enum ('HEADING_TO_PICKUP', 'PICKED_UP', 'RIDE_TO_HOSPITAL',
                                       'OWN_TRANSPORT_TO_HOSPITAL', 'AT_HOSPITAL', 'RIDE_HOME',
                                       'OWN_TRANSPORT_HOME', 'HANDOVER', 'COMPLETED_PAYOUT_PENDING');
create type offer_status      as enum ('SENT', 'ACCEPTED', 'DECLINED', 'EXPIRED', 'WITHDRAWN');
create type service_status    as enum ('PENDING', 'STARTED', 'COMPLETED');
create type cancellation_case as enum ('MORE_THAN_8H', 'WITHIN_8H', 'NO_SHOW');

create type ride_leg          as enum ('TO_HOSPITAL', 'TO_HOME');
create type ride_mode         as enum ('COMMERCIAL', 'PERSONAL');               -- ride partner / own transport
create type ride_provider     as enum ('UBER', 'RAPIDO');
create type vehicle_type      as enum ('CAR', 'BIKE', 'AUTO');
create type ride_status       as enum ('RIDE_PARTNER_ASSIGNED', 'RIDE_PARTNER_ARRIVED',
                                       'TRIP_STARTED', 'TRIP_COMPLETED', 'CANCELLED');

create type payment_request_type   as enum ('RIDE_TO_HOSPITAL', 'RIDE_HOME', 'HOSPITAL_BILL', 'CARETAKER_FEE');
create type payment_request_payee  as enum ('HOSPITAL', 'RIDE_PARTNER', 'PROXY_CARE');
create type payment_request_status as enum ('REQUESTED', 'PAYING', 'PAID', 'FAILED', 'DISPUTED');
create type payment_status         as enum ('CREATED', 'PAID', 'FAILED');
create type refund_status          as enum ('PENDING', 'PROCESSED', 'FAILED');
create type bill_status            as enum ('QR_MISMATCH', 'PAYMENT_REQUESTED', 'PAID_BILL_PENDING',
                                            'BILL_ATTACHED', 'DISPUTED');
create type bill_amount_source     as enum ('QR', 'MANUAL');
create type earning_status         as enum ('ON_HOLD', 'AWAITING_FEE', 'IN_WALLET', 'WITHDRAWN');
create type withdrawal_status      as enum ('PENDING', 'PROCESSED', 'FAILED');

create type dispute_reason    as enum ('FAMILY_UNPAID', 'VISIT_TIME_DISPUTED', 'BILL_AMOUNT_WRONG', 'OTHER');
create type dispute_status    as enum ('OPEN', 'RESOLVED');
create type file_kind         as enum ('BOOKING_ATTACHMENT', 'CARETAKER_PHOTO', 'HOSPITAL_BILL_QR',
                                       'HOSPITAL_FINAL_BILL', 'DISPUTE_PHOTO');
create type webhook_provider  as enum ('RAZORPAY', 'RAZORPAYX', 'HYPERVERGE', 'UBER', 'RAPIDO', 'FRESHDESK');
```

---

## 2. Identity and people

There are two apps, and one account (one mobile number) can hold both roles. A role is added
when the person first verifies their OTP in that app. Each role has its own row keyed on
`profiles.id`, and each app's profile is entered separately: signing up in the second app
pre-fills nothing from the first role.

```sql
create table profiles (
  id                 uuid primary key references auth.users (id) on delete cascade,
  roles              app_role[] not null check (cardinality(roles) between 1 and 2),
  phone              text not null unique check (phone ~ '^[+]91[6-9][0-9]{9}$'),
  preferred_language text not null default 'en' check (preferred_language in ('en', 'hi')),
  created_at         timestamptz not null default now()
);

-- Family member who books (User app). Screen 04.
create table app_users (
  id         uuid primary key references profiles (id) on delete cascade,
  full_name  text not null check (char_length(full_name) between 2 and 50),
  sex        sex_type not null,
  age        smallint check (age between 18 and 120),                  -- optional
  address    text not null check (char_length(address) <= 300),
  location   geography(Point, 4326),                                   -- set by "use current location"
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Patient (family member) a User books for. Screen 05.
-- "Lives at my address" copies the User's address and location at save time.
create table patients (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references app_users (id),
  relation     relation_type not null,
  full_name    text not null check (char_length(full_name) between 2 and 80),
  age          smallint not null check (age between 0 and 120),
  sex          sex_type not null,
  mobile       text check (mobile ~ '^[+]91[6-9][0-9]{9}$'),          -- optional; receives the pickup code
  address      text not null check (char_length(address) <= 300),
  location     geography(Point, 4326) not null,
  mobility     mobility_category not null,
  health_notes text check (char_length(health_notes) <= 500),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
create index patients_user_idx on patients (user_id) where deleted_at is null;

-- Caretaker (Caretaker app). Screens C1-C6. Columns stay null until their KYC step is done.
create table caretakers (
  id                        uuid primary key references profiles (id) on delete cascade,
  -- C2 Basic information
  full_name                 text check (char_length(full_name) between 2 and 80),
  sex                       sex_type,
  age                       smallint check (age between 18 and 70),
  email                     text check (email ~* '^[^@ ]+@[^@ ]+[.][^@ ]+$'),
  emergency_contact         text check (emergency_contact ~ '^[+]91[6-9][0-9]{9}$'),
  residential_address       text check (char_length(residential_address) <= 300),
  occupation                text check (char_length(occupation) <= 100),
  marital_status            marital_status,
  languages                 text[] not null default '{}',              -- e.g. {hi,en,pa}
  -- C4 Photo & identity check (video KYC via HyperVerge)
  photo_file_id             uuid,                                      -- fk added after files
  vkyc_slot_at              timestamptz,
  hyperverge_transaction_id text unique,
  -- C3 Aadhaar & PAN: not in the MVP; columns kept for when it is integrated
  aadhaar_last4             char(4) check (aadhaar_last4 ~ '^[0-9]{4}$'),
  aadhaar_verified_at       timestamptz,
  pan_masked                text check (pan_masked ~ '^[A-Z]{5}[*]{4}[A-Z]$'),
  pan_verified_at           timestamptz,
  -- C5 Payout account (verified by a Rs 1 test deposit through RazorpayX)
  razorpayx_contact_id      text unique,                               -- the person: name, phone, email
  razorpayx_fund_account_id text unique,                               -- the bank account under that contact
  bank_account_holder_name  text check (char_length(bank_account_holder_name) between 2 and 80),
  bank_account_last4        char(4) check (bank_account_last4 ~ '^[0-9]{4}$'),
  bank_ifsc                 text check (bank_ifsc ~ '^[A-Z]{4}0[A-Z0-9]{6}$'),
  bank_name                 text,
  bank_branch               text,
  bank_validation_status    bank_validation,
  -- KYC progress
  kyc_status                kyc_status not null default 'IN_PROGRESS',
  kyc_step                  smallint not null default 2 check (kyc_step between 1 and 5),  -- step 1 (mobile) is done at sign-up
  approved_at               timestamptz,
  rejected_reason           text,
  -- Dispatch
  is_online                 boolean not null default false check (not is_online or kyc_status = 'APPROVED'),
  last_location             geography(Point, 4326),
  last_location_at          timestamptz,
  -- Read model counters
  rating_avg                numeric(2, 1) check (rating_avg between 1 and 5),
  rating_count              integer not null default 0,
  visit_count               integer not null default 0,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);
create unique index caretakers_email_key on caretakers (lower(email));        -- C2 "email already in use"
create index caretakers_dispatch_gix on caretakers using gist (last_location)
  where is_online and kyc_status = 'APPROVED';

-- Push notification tokens; one profile can have several devices and both apps.
create table device_tokens (
  fcm_token  text primary key,
  profile_id uuid not null references profiles (id) on delete cascade,
  platform   text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);
create index device_tokens_profile_idx on device_tokens (profile_id);
```

---

## 3. Files

Uploads (booking attachments, caretaker photo, bill QR images, final bills, dispute photos).
JPG, PNG or PDF, at most 10 MB (B3).

```sql
create table files (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null references profiles (id),
  booking_id   uuid,                                                   -- fk added after bookings
  kind         file_kind not null,
  file_name    text not null check (char_length(file_name) <= 255),
  mime_type    text not null check (mime_type in ('image/jpeg', 'image/png', 'application/pdf')),
  size_bytes   integer not null check (size_bytes between 1 and 10485760),
  storage_path text not null unique,
  created_at   timestamptz not null default now()
);

alter table caretakers add constraint caretakers_photo_fk foreign key (photo_file_id) references files (id);
```

---

## 4. Catalogue and pricing

```sql
create table hospitals (
  id              uuid primary key default gen_random_uuid(),
  google_place_id text not null unique,
  name            text not null,
  address         text not null,
  location        geography(Point, 4326) not null,
  created_at      timestamptz not null default now()
);

-- Price = hourly wage x block hours + margin + platform fee.
create table pricing_rules (
  mobility           mobility_category primary key,
  hourly_wage_paise  integer not null check (hourly_wage_paise > 0),
  block_hours        smallint not null default 3 check (block_hours > 0),
  margin_paise       integer not null default 40000 check (margin_paise >= 0),
  platform_fee_paise integer not null default 9900 check (platform_fee_paise >= 0),
  updated_at         timestamptz not null default now()
);
```

---

## 5. Bookings

```sql
create sequence booking_code_seq start 2481;

create table bookings (
  id                  uuid primary key default gen_random_uuid(),
  code                text not null unique default ('PC-' || nextval('booking_code_seq')),
  user_id             uuid not null references app_users (id),
  patient_id          uuid not null references patients (id),
  caretaker_id        uuid references caretakers (id),                -- set on first accept
  hospital_id         uuid not null references hospitals (id),
  state               booking_state not null default 'PAYMENT_PENDING',
  stage               visit_stage,                                    -- while ASSIGNED / IN_PROGRESS
  visit_date          date not null,
  pickup_at           timestamptz not null,
  purposes            visit_purpose[] not null check (cardinality(purposes) between 1 and 5),
  department          text check (char_length(department) <= 100),
  instructions        text check (char_length(instructions) <= 1000), -- includes doctor name / appointment
  -- price snapshot, frozen at confirm time
  mobility            mobility_category not null,
  hourly_wage_paise   integer not null,
  block_hours         smallint not null,
  margin_paise        integer not null,
  platform_fee_paise  integer not null,
  -- execution
  en_route_at         timestamptz,                                    -- caretaker starts trip to pickup
  picked_up_at        timestamptz,                                    -- pickup code verified; billable time starts
  completed_at        timestamptz,                                    -- Visit Completed; billable time ends (see §8)
  location_sharing    boolean not null default false,
  payments_frozen     boolean not null default false,
  handover_checklist  jsonb,                                          -- D5: {"patient_inside":true,"papers":true,"medicines":true,"belongings":true}
  idempotency_key     text unique,                                    -- repeat Confirm & Pay taps
  version             integer not null default 1,                     -- optimistic locking
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  check (state in ('PAYMENT_PENDING', 'WAITING') or caretaker_id is not null or state = 'CANCELLED'),
  check (completed_at is null or picked_up_at is not null)
);
create index bookings_user_idx      on bookings (user_id, visit_date desc);
create index bookings_caretaker_idx on bookings (caretaker_id, visit_date desc);

alter table files add constraint files_booking_fk foreign key (booking_id) references bookings (id);

-- Audit trail of state and stage changes; drives the U2 visit timeline.
create table booking_events (
  id         bigint generated always as identity primary key,
  booking_id uuid not null references bookings (id) on delete cascade,
  state      booking_state not null,
  stage      visit_stage,
  actor_id   uuid references profiles (id),                           -- null for system changes
  created_at timestamptz not null default now()
);
create index booking_events_booking_idx on booking_events (booking_id, created_at);

-- Readable by the booking's User only, never by the caretaker.
-- Verification has no attempt limit and never blocks the caretaker.
create table booking_secrets (
  booking_id  uuid primary key references bookings (id) on delete cascade,
  pickup_code char(4) not null check (pickup_code ~ '^[0-9]{4}$')
);

-- Dispatch: one offer per nearby caretaker; the first accept wins.
create table booking_offers (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid not null references bookings (id) on delete cascade,
  caretaker_id  uuid not null references caretakers (id),
  status        offer_status not null default 'SENT',
  distance_m    integer not null check (distance_m >= 0),
  locality      text not null,                                        -- shown before accept; full address hidden
  earning_paise integer not null check (earning_paise >= 0),
  expires_at    timestamptz not null,
  responded_at  timestamptz,
  created_at    timestamptz not null default now(),
  unique (booking_id, caretaker_id)
);

-- One service per selected purpose.
create table booking_services (
  id           uuid primary key default gen_random_uuid(),
  booking_id   uuid not null references bookings (id) on delete cascade,
  type         visit_purpose not null,
  detail       text check (char_length(detail) <= 200),
  status       service_status not null default 'PENDING',
  started_at   timestamptz,
  completed_at timestamptz,
  unique (booking_id, type),
  check (status = 'PENDING' or started_at is not null),
  check (status <> 'COMPLETED' or completed_at is not null)
);

-- Cancellation is designed only from WAITING (B5).
create table cancellations (
  booking_id          uuid primary key references bookings (id),
  cancelled_by        uuid not null references profiles (id),
  policy_case         cancellation_case not null,
  hours_before_pickup numeric(6, 2) not null,
  paid_paise          integer not null check (paid_paise >= 0),
  deduction_paise     integer not null check (deduction_paise >= 0),
  deduction_reason    text not null,
  refund_paise        integer not null check (refund_paise >= 0),
  created_at          timestamptz not null default now(),
  check (paid_paise = deduction_paise + refund_paise)
);
```

---

## 6. Payments

Every charge the User pays goes through the gateway (Razorpay). The booking charge is a
payment with no payment request; every later charge is a payment request the User approves.
Paid status is decided by the server from the verified gateway signature or webhook, never
by the client.

```sql
create table payment_requests (
  id           uuid primary key default gen_random_uuid(),
  booking_id   uuid not null references bookings (id),
  type         payment_request_type not null,
  payee        payment_request_payee not null,
  amount_paise integer not null check (amount_paise > 0),
  description  text not null check (char_length(description) <= 200),
  requested_by uuid references profiles (id),                         -- null for system-created CARETAKER_FEE
  status       payment_request_status not null default 'REQUESTED',
  paid_at      timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  check (status <> 'PAID' or paid_at is not null),
  check (status <> 'DISPUTED' or type = 'HOSPITAL_BILL')
);
create index payment_requests_booking_idx on payment_requests (booking_id);

create table payments (
  id                  uuid primary key default gen_random_uuid(),
  booking_id          uuid not null references bookings (id),
  payment_request_id  uuid references payment_requests (id),          -- null for the booking charge
  amount_paise        integer not null check (amount_paise > 0),      -- copied from the server record
  razorpay_order_id   text not null unique,
  razorpay_payment_id text unique,
  method              text,                                           -- upi, card, netbanking
  status              payment_status not null default 'CREATED',
  paid_at             timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index payments_booking_idx on payments (booking_id);
-- At most one successful payment per booking charge and per payment request.
create unique index payments_one_paid_booking_charge on payments (booking_id)
  where status = 'PAID' and payment_request_id is null;
create unique index payments_one_paid_request on payments (payment_request_id)
  where status = 'PAID';

-- Refunds go to the User's bank / original payment method.
create table refunds (
  id                 uuid primary key default gen_random_uuid(),
  booking_id         uuid not null references bookings (id),
  payment_id         uuid not null references payments (id),
  amount_paise       integer not null check (amount_paise > 0),
  reason             text not null check (reason in ('CANCELLATION', 'DIAGNOSTICS_PRO_RATE')),
  razorpay_refund_id text unique,
  status             refund_status not null default 'PENDING',
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
```

---

## 7. Rides

A ride is optional on both legs. `COMMERCIAL` is booked through a ride partner; `PERSONAL`
is own transport (P7b) and has no provider fields.

```sql
create table rides (
  id                  uuid primary key default gen_random_uuid(),
  booking_id          uuid not null references bookings (id) on delete cascade,
  leg                 ride_leg not null,
  mode                ride_mode not null,
  provider            ride_provider,
  provider_ride_id    text unique,
  vehicle_type        vehicle_type,
  driver_name         text,
  driver_phone_masked text,
  vehicle_plate       text,
  ride_pin            text,
  fare_estimate_paise integer check (fare_estimate_paise >= 0),
  final_fare_paise    integer check (final_fare_paise >= 0),
  status              ride_status,
  payment_request_id  uuid references payment_requests (id),
  started_at          timestamptz,
  completed_at        timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  check (mode = 'PERSONAL' or provider is not null),
  check (mode = 'COMMERCIAL' or (provider is null and provider_ride_id is null and status is null))
);
-- One active ride per leg; a cancelled ride can be rebooked on the same leg.
create unique index rides_one_active_per_leg on rides (booking_id, leg)
  where status is distinct from 'CANCELLED';
```

---

## 8. Hospital

Once the User pays a bill (`PAID_BILL_PENDING`), the caretaker must attach the hospital's
final bill (H4), which moves it to `BILL_ATTACHED`.

**Visit Completed rule:** the caretaker cannot mark the visit complete while any of the
booking's bills is `PAID_BILL_PENDING`. Leave hospital is not blocked. The service checks
this before setting `bookings.completed_at`; the index below makes the check cheap.

```sql
create table hospital_bills (
  id                        uuid primary key default gen_random_uuid(),
  booking_id                uuid not null references bookings (id) on delete cascade,
  qr_payload                text not null,                            -- upi://pay?pa=...&pn=...&mc=8062&am=500.00
  payee_vpa                 text not null,
  merchant_name             text not null,
  mcc                       char(4),
  qr_readable               boolean not null,
  merchant_matches_hospital boolean not null,
  mcc_is_hospital           boolean not null,
  amount_paise              integer not null check (amount_paise > 0),
  amount_source             bill_amount_source not null,              -- QR amount is read-only; MANUAL when the QR has none
  description               text not null check (char_length(description) <= 200),
  qr_image_file_id          uuid references files (id),
  status                    bill_status not null,
  payment_request_id        uuid unique references payment_requests (id),  -- null when QR_MISMATCH
  final_bill_file_id        uuid references files (id),                -- H4; photo or PDF
  final_bill_uploaded_at    timestamptz,
  created_by                uuid not null references caretakers (id),
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  check (status = 'QR_MISMATCH' or payment_request_id is not null),
  check (status <> 'BILL_ATTACHED' or (final_bill_file_id is not null and final_bill_uploaded_at is not null))
);
create index hospital_bills_booking_idx on hospital_bills (booking_id);
create index hospital_bills_final_bill_pending_idx on hospital_bills (booking_id)
  where status = 'PAID_BILL_PENDING';                                  -- Visit Completed rule
```

---

## 9. Settlement

```sql
-- One earning per completed visit; the wallet balance is the sum of IN_WALLET earnings.
create table caretaker_earnings (
  booking_id         uuid primary key references bookings (id),
  caretaker_id       uuid not null references caretakers (id),
  block_paise        integer not null check (block_paise >= 0),
  extra_time_paise   integer not null default 0 check (extra_time_paise >= 0),
  bill_number        text unique,                                     -- generated when the fee is paid
  status             earning_status not null default 'ON_HOLD',
  added_to_wallet_at timestamptz,
  withdrawal_id      uuid,                                            -- fk added after caretaker_withdrawals
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  check (status not in ('IN_WALLET', 'WITHDRAWN') or added_to_wallet_at is not null),
  check (status <> 'WITHDRAWN' or withdrawal_id is not null)
);
create index caretaker_earnings_caretaker_idx on caretaker_earnings (caretaker_id, status);

-- Manual "Withdraw to bank" through a RazorpayX payout.
create table caretaker_withdrawals (
  id                  uuid primary key default gen_random_uuid(),
  caretaker_id        uuid not null references caretakers (id),
  amount_paise        integer not null check (amount_paise > 0),
  bank_account_last4  char(4) not null,
  razorpayx_payout_id text unique,
  utr                 text,
  status              withdrawal_status not null default 'PENDING',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

alter table caretaker_earnings add constraint caretaker_earnings_withdrawal_fk
  foreign key (withdrawal_id) references caretaker_withdrawals (id);

create sequence dispute_no_seq start 1001;

-- Raised by the User on a hospital bill (H5) or by the caretaker on settlement (F5).
create table disputes (
  id                  uuid primary key default gen_random_uuid(),
  ticket_no           text not null unique default ('DS-' || nextval('dispute_no_seq')),
  booking_id          uuid not null references bookings (id),
  hospital_bill_id    uuid references hospital_bills (id),
  raised_by           uuid not null references profiles (id),
  reason              dispute_reason not null,
  details             text check (char_length(details) <= 2000),
  photo_file_id       uuid references files (id),
  status              dispute_status not null default 'OPEN',
  freshdesk_ticket_id bigint unique,
  created_at          timestamptz not null default now(),
  resolved_at         timestamptz
);

create table ratings (
  booking_id   uuid primary key references bookings (id),
  user_id      uuid not null references app_users (id),
  caretaker_id uuid not null references caretakers (id),
  stars        smallint not null check (stars between 1 and 5),
  created_at   timestamptz not null default now()
);
```

---

## 10. Integration

```sql
-- Idempotency for every inbound webhook: a repeated (provider, event_id) is ignored.
create table webhook_events (
  provider     webhook_provider not null,
  event_id     text not null,
  event_type   text not null,
  payload      jsonb not null,                                        -- ids only; no PII stored here
  received_at  timestamptz not null default now(),
  processed_at timestamptz,
  error        text,
  primary key (provider, event_id)
);
```

---

## 11. Open questions

1. **Caretaker skills** (e.g. "Wheelchair trained") and **weekly earnings** are shown in the UI
   but have no source; not modelled yet.
