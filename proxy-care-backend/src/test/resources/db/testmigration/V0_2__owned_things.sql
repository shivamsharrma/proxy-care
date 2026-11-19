-- Backs the ownership demo endpoint (AuthorizationTest).
create table test_support.owned_things (
    id      uuid primary key,
    user_id uuid not null
);
