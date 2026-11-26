-- User decision 2026-11-26: no Postgres enum types. Enum columns are text holding the Java enum name written by
-- @Enumerated(STRING); like the other value rules, valid values are checked by the API only (decision OQ-22).
alter table profiles alter column roles type text[] using roles::text[];

alter table app_users alter column sex type text using sex::text;

alter table patients
    alter column relation type text using relation::text,
    alter column sex type text using sex::text,
    alter column mobility_category type text using mobility_category::text;

drop type app_role;
drop type sex_type;
drop type relation_type;
drop type mobility_category;
