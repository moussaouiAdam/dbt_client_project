-- =====================================================================
-- À exécuter UNE SEULE FOIS dans Snowflake (worksheet), avant dbt.
-- Ton script Tasty Bytes donne au rôle tasty_data_engineer seulement
-- USAGE sur la base : il ne peut pas créer de nouveaux schémas.
-- Or dbt doit créer DBT_ADAM_BRONZE, DBT_ADAM_SILVER, DBT_ADAM_GOLD.
-- =====================================================================

USE ROLE sysadmin;   -- propriétaire de la base frostbyte_tasty_bytes

GRANT CREATE SCHEMA ON DATABASE frostbyte_tasty_bytes TO ROLE tasty_data_engineer;

-- Vérification
SHOW GRANTS TO ROLE tasty_data_engineer;
