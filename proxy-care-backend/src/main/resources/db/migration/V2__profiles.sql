create type app_role as enum ('USER', 'CARETAKER', 'ADMIN');

create table profiles (
    id                 uuid primary key references auth.users (id) on delete cascade,
    roles              app_role[] not null,
    phone              text not null unique,
    preferred_language text not null default 'en' check (preferred_language in ('en', 'hi')),
    created_at         timestamptz not null default now()
);

-- RLS on with no policies: deny-all for anon/authenticated, so the apps can't bypass the API.
alter table profiles enable row level security;
