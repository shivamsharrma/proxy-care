-- C5 Payout account: one row per penny-drop attempt, kept as history (a resubmit after FAILED adds a row).
-- status (PENDING/VERIFIED/FAILED) and failure_reason (DEPOSIT_FAILED/NAME_MISMATCH/NAME_VERIFICATION_UNAVAILABLE)
-- are text holding the Java enum names, checked by the API only (decisions V10, OQ-22).
-- account_number_encrypted is base64(iv || ciphertext || tag), AES-256-GCM with BANK_ACCOUNT_ENCRYPTION_KEY; the
-- plain number is never stored. vendor_requested_at stays null until BankVerificationJob has asked RazorpayX;
-- next_check_at is when the job next looks at a PENDING attempt.
create table bank_verification_requests (
    id                        uuid primary key default gen_random_uuid(),
    created_at                timestamptz not null,
    updated_at                timestamptz not null,
    version                   bigint not null default 0,
    caretaker_id              uuid not null references caretakers (id) on delete cascade,
    status                    text not null,
    failure_reason            text,
    account_holder_name       text not null,
    account_number_encrypted  text not null,
    account_last4             text not null,
    ifsc                      text not null,
    bank_name                 text not null,
    bank_branch               text not null,
    razorpayx_contact_id      text,
    razorpayx_fund_account_id text,
    razorpayx_validation_id   text unique,
    vendor_requested_at       timestamptz,
    next_check_at             timestamptz not null
);

-- The caretaker's latest attempt.
create index bank_verification_requests_caretaker_idx on bank_verification_requests (caretaker_id, created_at desc);
-- The job's due PENDING attempts.
create index bank_verification_requests_due_idx on bank_verification_requests (next_check_at) where status = 'PENDING';

-- RLS on with no policies: deny-all for anon/authenticated, so the apps can't bypass the API.
alter table bank_verification_requests enable row level security;

-- Webhook deliveries already handled, so a redelivered event changes nothing. provider is text holding the
-- WebhookProvider enum name. The unique constraint also indexes the lookup.
create table webhook_events (
    id         uuid primary key default gen_random_uuid(),
    created_at timestamptz not null,
    updated_at timestamptz not null,
    version    bigint not null default 0,
    provider   text not null,
    event_id   text not null,
    unique (provider, event_id)
);

-- RLS on with no policies: deny-all for anon/authenticated, so the apps can't bypass the API.
alter table webhook_events enable row level security;
