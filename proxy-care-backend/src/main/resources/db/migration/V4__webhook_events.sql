-- Inbound webhooks, stored once per (provider, event id) after their signature is verified.
create table webhook_events (
    provider     text not null check (provider in ('RAZORPAY', 'RAZORPAYX', 'UBER')),
    event_id     text not null,
    event_type   text,
    payload      jsonb not null,
    received_at  timestamptz not null default now(),
    processed_at timestamptz,
    error        text,
    primary key (provider, event_id)
);

alter table webhook_events enable row level security;
