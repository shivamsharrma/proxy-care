-- preferred_language now holds the PreferredLanguage enum name (EN, HI) as written by @Enumerated(STRING).
update profiles set preferred_language = upper(preferred_language);
alter table profiles alter column preferred_language set default 'EN';
