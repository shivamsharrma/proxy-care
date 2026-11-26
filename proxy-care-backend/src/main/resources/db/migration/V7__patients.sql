-- Labels equal the Relation and MobilityCategory enum names, as written by @Enumerated(STRING).
create type relation_type as enum ('FATHER', 'MOTHER', 'SPOUSE', 'GRANDPARENT', 'SIBLING', 'OTHER');
create type mobility_category as enum ('AMBULATORY', 'WHEELCHAIR', 'BEDRIDDEN');

-- Name, age, mobile, address and health-notes rules live in SavePatientRequest only, so no check
-- constraints (decision OQ-22). The mobile columns hold the MobileNumber value object: both null or both set.
-- Deleting the owning app_users row (which cascades from profiles) removes its patients with it.
create table patients (
    id                    uuid primary key default gen_random_uuid(),
    created_at            timestamptz not null,
    updated_at            timestamptz not null,
    version               bigint not null default 0,
    user_id               uuid not null references app_users (id) on delete cascade,
    relation              relation_type not null,
    full_name             text not null,
    age                   smallint not null,
    sex                   sex_type not null,
    mobile_country_code   text,
    mobile_number         text,
    lives_at_user_address boolean not null,
    address               text not null,
    mobility              mobility_category not null,
    health_notes          text,
    deleted_at            timestamptz
);

-- The family list reads an owner's live patients; soft-deleted rows stay out of the index.
create index patients_user_idx on patients (user_id) where deleted_at is null;

-- RLS on with no policies: deny-all for anon/authenticated, so the apps can't bypass the API.
alter table patients enable row level security;
