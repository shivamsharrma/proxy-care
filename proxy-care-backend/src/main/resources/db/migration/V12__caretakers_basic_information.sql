-- C2 Basic information. Columns stay null until the step is first saved. Like the other value rules, sex,
-- marital_status, the age range and the email format are checked by the API only, so no check constraints
-- (decisions V10, OQ-22). The emergency contact holds the MobileNumber value object: both null or both set.
alter table caretakers
    add column full_name                      text,
    add column sex                            text,
    add column age                            smallint,
    add column email                          text,
    add column emergency_contact_country_code text,
    add column emergency_contact_number       text,
    add column residential_address            text,
    add column occupation                     text,
    add column marital_status                 text,
    -- The C2 form as last submitted when it failed validation (decision OQ-2); null once a save succeeds.
    add column basic_information_draft        jsonb;

-- C2 "This email is already in use": one caretaker per email, compared case-insensitively.
create unique index caretakers_email_key on caretakers (lower(email));
