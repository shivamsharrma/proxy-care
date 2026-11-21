create table profiles (
  id                 uuid primary key references auth.users(id) on delete cascade,
  roles              app_role[] not null check (cardinality(roles) between 1 and 2),
  phone              text not null unique check (phone ~ '^[+]91[6-9][0-9]{9}$'),
  preferred_language text not null default 'en' check (preferred_language in ('en','hi')),
  languages                 text[] not null default '{}',     -- {'hi','en','pa'}
  created_at         timestamptz not null default now()
);

create table app_users (
  id                   uuid primary key references profiles(id) on delete cascade,
  full_name            text not null check (char_length(full_name) between 2 and 80),
  sex                  sex_type not null,
  age                  smallint check (age between 18 and 110),
  address              text not null check (char_length(address) <= 300),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create table patients (
  app_users.id
  id              uuid primary key default gen_random_uuid(),
  full_name       text not null check (char_length(full_name) between 2 and 80),
  age             smallint not null check (age between 0 and 120),
  sex             sex_type not null,
  mobile          text check (mobile ~ '^[+]91[6-9][0-9]{9}$'),   -- receives pickup code
  address         text not null check (char_length(address) <= 300),
  location        geography(Point,4326) not null,
  mobility        mobility_category not null,
  health_notes    text check (char_length(health_notes) <= 1000),
  relation        relation_type not null,	
  created_by      uuid not null references app_users(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);


create table caretakers (
  id                        uuid primary key references profiles(id) on delete cascade,
  full_name                 text check (char_length(full_name) between 2 and 80),
  sex                       sex_type,
  age                       smallint check (age between 18 and 70),
  email                     text check (email ~* '^[^@ ]+@[^@ ]+[.][^@ ]+$'),
  emergency_contact         text check (emergency_contact ~ '^[+]91[6-9][0-9]{9}$'),
  residential_address       text check (char_length(residential_address) <= 300),
  occupation                text,
  marital_status            text check (marital_status in ('SINGLE','MARRIED')),
  photo_file_id             uuid references files(id),
  kyc_status                kyc_status not null default 'IN_PROGRESS',
  kyc_step                  smallint not null default 2 check (kyc_step between 1 and 5),
  hyperverge_transaction_id text unique,
  aadhaar_last4             char(4),
  aadhaar_verified_at       timestamptz,
  pan_masked                text check (pan_masked ~ '^[A-Z]{5}[*]{4}[A-Z]$'),
  pan_verified_at           timestamptz,
  vkyc_slot_at              timestamptz,
  approved_at               timestamptz,
  rejected_reason           text,
  is_online                 boolean not null default false check (not is_online or kyc_status = 'APPROVED'),
  last_location             geography(Point,4326),
  last_location_at          timestamptz,
  rating_avg                numeric(2,1) check (rating_avg between 1 and 5),
  rating_count              integer not null default 0,
  visit_count               integer not null default 0,
  razorpayx_contact_id      text unique, A contact is the person: the caretaker’s name, phone and email.
  razorpayx_fund_account_id text unique, A fund account is where the money goes: one specific bank account or UPI handle under that contact.
  bank_account_last4        char(4),
  bank_ifsc                 text check (bank_ifsc ~ '^[A-Z]{4}0[A-Z0-9]{6}$'),
  bank_name                 text,
  bank_branch               text,
  bank_validation_status    text check (bank_validation_status in ('PENDING','VALID','FAILED')),
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);
create index caretakers_dispatch_gix on caretakers using gist (last_location)
  where is_online and kyc_status = 'APPROVED';

// For Push Notification
create table device_tokens (
  profile_id uuid not null references profiles(id) on delete cascade,
  fcm_token  text primary key,
  platform   text not null check (platform in ('android','ios')),
  updated_at timestamptz not null default now()
);


-- ---------- Catalogue and pricing ----------
create table hospitals (
  id                   uuid primary key default gen_random_uuid(),
  google_place_id      text not null unique,
  name                 text not null,
  address              text not null,
  location             geography(Point,4326) not null,
  created_at           timestamptz not null default now()
);


create table pricing_rules (
  mobility           mobility_category primary key,
  hourly_wage_paise  integer not null check (hourly_wage_paise > 0),
  block_hours        smallint not null default 3,
  margin_paise       integer not null default 40000,
  platform_fee_paise integer not null default 9900,
  updated_at         timestamptz not null default now()
);

create sequence booking_code_seq start 2481;

create table bookings (
  id                        uuid primary key default gen_random_uuid(),
  code                      text not null unique default ('PC-' || nextval('booking_code_seq')),
  user_id                   uuid not null references app_users(id),
  patient_id                uuid not null references patients(id),
  caretaker_id              uuid references caretakers(id),
  hospital_id               uuid not null references hospitals(id),
  state                     booking_state not null default 'WAITING',
  visit_date                date not null,
  pickup_at                 timestamptz not null,
  purposes                  visit_purpose[] not null check (cardinality(purposes) between 1 and 5),
  department                text,
  doctor_name               text,
  pre_booked                boolean not null,
  appointment_at            timestamptz,
  instructions              text check (char_length(instructions) <= 1000),
  -- price snapshot, frozen at confirm time
  mobility                  mobility_category not null,
  hourly_wage_paise         integer not null,
  block_hours               smallint not null,
  margin_paise              integer not null,
  platform_fee_paise        integer not null,
  -- execution
  actual_minutes            integer not null,
  settlement_status         settlement_status not null,
  caretaker_payout_id  uuid references payouts(id),
  pickup_otp_attempts       smallint not null default 0,
  payments_frozen           boolean not null default false,
  location_sharing          boolean not null default false,
  handover_checklist        string,
  en_route_at               timestamptz,
  cancelled_at              timestamptz,
  cancelled_by              uuid references profiles(id),
  cancellation_refund_paise integer,
  idempotency_key           text not null unique, (FOR LATER)
  entity_version_id         integer not null default 1,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
);

create table bookings_state (
  booking_id
  state,    	           Enum(UNASSIGNED, ASSIGNED,ARRIVED_PICKUP/HOSPITAL_REACHED)		  
  created_at 	           timestamptz
)

create index bookings_user_idx      on bookings (user_id, visit_date desc);
create index bookings_caretaker_idx on bookings (caretaker_id, visit_date desc);
alter table files add constraint files_booking_fk foreign key (booking_id) references bookings(id);

 -- readable by sponsor only, never by caretaker
create table booking_secrets (                   
  booking_id  uuid primary key references bookings(id) on delete cascade,
  pickup_code char(4) not null check (pickup_code ~ '^[0-9]{4}$')
);

create table booking_offers (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid not null references bookings(id) on delete cascade,
  caretaker_id  uuid not null references caretakers(id),
  status        offer_status not null default 'SENT',
  distance_m    integer not null,
  locality      text not null,                 -- shown before accept; full address hidden
  earning_paise integer not null,
  expires_at    timestamptz not null,
  responded_at  timestamptz,
  created_at    timestamptz not null default now(),
  unique (booking_id, caretaker_id)
);

create table booking_services (
  id           uuid primary key default gen_random_uuid(),
  booking_id   uuid not null references bookings(id) on delete cascade,
  type         visit_purpose not null,
  detail       text,
  status       service_status not null default 'PENDING',
  started_at   timestamptz,
  completed_at timestamptz,
  unique (booking_id, type),
  check (status <> 'STARTED' or started_at is not null),
  check (status <> 'COMPLETED' or completed_at is not null)
);

create table rides (
  id                  uuid primary key default gen_random_uuid(),
  booking_id          uuid not null references bookings(id) on delete cascade,
  mode                ride_mode not null, (COMMERCIAL, PERSONAL)
  provider            ride_provider,
  provider_ride_id    text unique,
  vehicle_type        Enum(CAR, BIKE, AUTO),
  driver_name         text,
  driver_phone_masked text,
  vehicle_plate       text,
  ride_pin            text,
  fare_estimate_paise integer,
  final_fare_paise    integer,
  status              ride_status,
  paid                boolean not null default false,
  started_at          timestamptz,
  completed_at        timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
);
create unique index rides_one_active_per_leg on rides (booking_id, leg)
  where status is null or status not in ('CANCELLED','FAILED');


create table hospital_bills (
  id                  uuid primary key default gen_random_uuid(),
  booking_id          uuid not null references bookings(id) on delete cascade,
  qr_payload          text not null,       -- upi://pay?pa=...&pn=...&mc=8062&am=500.00
  payee_vpa           text not null,
  merchant_name       text not null,
  mcc                 char(4),
  amount_paise        integer not null check (amount_paise > 0),
  description         text not null check (char_length(description) <= 200),
  image_file_id       uuid references files(id),
  checks              boolean not null,      -- {"qr_readable":true,"merchant_matches_hospital":true,"mcc_is_hospital":true}
  status              bill_status not null,
  payout_id
  verified_at         timestamptz,
  disputed_at         timestamptz,
  created_by          uuid not null references caretakers(id),
  created_at          timestamptz not null default now()
);

create table disputes (
  id                 uuid primary key default gen_random_uuid(),
  ticket_no          text not null unique default ('DS-' || nextval('dispute_no_seq')),
  booking_id         uuid not null references bookings(id),
  hospital_bill_id   uuid references hospital_bills(id),
  raised_by          uuid not null references profiles(id),
  reason             dispute_reason not null,
  details            text check (char_length(details) <= 2000),
  photo_file_id      uuid references files(id),
  status             dispute_status not null default 'OPEN',
  freshdesk_ticket_id bigint unique,
  created_at         timestamptz not null default now(),
  resolved_at        timestamptz
);

create table ratings (
  booking_id   uuid primary key references bookings(id),
  user_id      uuid not null references app_users(id),
  caretaker_id uuid not null references caretakers(id),
  stars        smallint not null check (stars between 1 and 5),
  created_at   timestamptz not null default now()
);

create table webhook_events (                       -- idempotency for every inbound webhook
  provider     text not null check (provider in ('RAZORPAY','RAZORPAYX','HYPERVERGE','UBER','FRESHDESK')),
  event_id     text not null,
  event_type   text not null,
  payload      jsonb not null,
  received_at  timestamptz not null default now(),
  processed_at timestamptz,
  error        text,
  primary key (provider, event_id)
);
