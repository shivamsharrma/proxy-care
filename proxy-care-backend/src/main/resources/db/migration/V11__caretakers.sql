-- One row per caretaker profile, created when the CARETAKER role is added (PUT /profile/me).
-- Statuses are text holding the Java enum names, and like the other value rules they are checked by the API only,
-- so no check constraints (decisions V10, OQ-22). kyc_step is the KycStep stepNumber (1-4).
-- bank_verification_status stays null until the payout account is first submitted.
-- The unique constraint on profile_id also indexes the lookup by owner.
create table caretakers (
    id                        uuid primary key default gen_random_uuid(),
    created_at                timestamptz not null,
    updated_at                timestamptz not null,
    version                   bigint not null default 0,
    profile_id                uuid not null unique references profiles (id) on delete cascade,
    status                    text not null,
    onboarding_status         text not null,
    video_verification_status text not null,
    bank_verification_status  text,
    kyc_step                  smallint not null,
    rejected_reason           text
);

-- RLS on with no policies: deny-all for anon/authenticated, so the apps can't bypass the API.
alter table caretakers enable row level security;
