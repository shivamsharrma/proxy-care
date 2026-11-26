-- Columns are named after their type, like the Java fields: MobilityCategory mobilityCategory -> mobility_category.
alter table patients rename column mobility to mobility_category;
