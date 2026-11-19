-- One row per (user, Idempotency-Key). Claim, action and stored response share one transaction,
-- so a failed action leaves no row behind. Rows older than 24h are deleted daily.
create table idempotency_keys (
    user_id         uuid not null,
    key             uuid not null,
    request_hash    text not null,
    response_status int,
    response_body   jsonb,
    created_at      timestamptz not null default now(),
    primary key (user_id, key)
);

create index idempotency_keys_created_at_idx on idempotency_keys (created_at);

alter table idempotency_keys enable row level security;
