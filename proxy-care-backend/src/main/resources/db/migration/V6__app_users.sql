-- Labels equal the Sex enum names, as written by @Enumerated(STRING).
create type sex_type as enum ('FEMALE', 'MALE', 'OTHER');

-- Name, age and address rules live in SaveAppUserRequest only, so no check constraints (decision OQ-22).
-- The unique constraint on profile_id also indexes the lookup by owner.
create table app_users (
    id         uuid primary key default gen_random_uuid(),
    created_at timestamptz not null,
    updated_at timestamptz not null,
    version    bigint not null default 0,
    profile_id uuid not null unique references profiles (id) on delete cascade,
    full_name  text not null,
    sex        sex_type not null,
    age        smallint,
    address    text not null
);

-- RLS on with no policies: deny-all for anon/authenticated, so the apps can't bypass the API.
alter table app_users enable row level security;
