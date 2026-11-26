-- 05_add_family_member.feature: the "Lives at my address" toggle is gone; every patient's address is typed in.
-- Existing rows keep the address that was copied into them, so nothing else changes.
alter table patients drop column lives_at_user_address;
