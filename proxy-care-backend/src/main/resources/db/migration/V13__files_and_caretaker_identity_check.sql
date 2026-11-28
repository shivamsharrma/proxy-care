-- File records. The Caretaker app uploads the C4 photo straight to the private Storage bucket caretaker-photos
-- under <owner id>/; the backend stores only the record. kind is text holding the FileKind enum name, checked by
-- the API only (decisions V10, OQ-22). The unique constraint on storage_path also indexes lookups by path.
create table files (
    id           uuid primary key default gen_random_uuid(),
    created_at   timestamptz not null,
    updated_at   timestamptz not null,
    version      bigint not null default 0,
    owner_id     uuid not null references profiles (id) on delete cascade,
    kind         text not null,
    file_name    text not null,
    mime_type    text not null,
    size_bytes   integer not null,
    storage_path text not null unique
);

-- The caretaker's photo is found by owner and kind.
create index files_owner_kind_idx on files (owner_id, kind);

-- RLS on with no policies: deny-all for anon/authenticated, so the apps can't bypass the API.
alter table files enable row level security;

-- C4 Photo & identity check: the photo record and the video KYC call the caretaker picked (any future time,
-- decision OQ-5).
alter table caretakers
    add column photo_file_id uuid references files (id) on delete set null,
    add column vkyc_slot_at  timestamptz;

create index caretakers_photo_file_idx on caretakers (photo_file_id);
