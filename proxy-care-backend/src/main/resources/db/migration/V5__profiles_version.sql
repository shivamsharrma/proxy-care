-- Optimistic locking for ProfileEntity (@Version); existing rows start at version 0.
alter table profiles add column version bigint not null default 0;
