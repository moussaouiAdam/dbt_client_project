-- =====================================================================
-- BRONZE : copie brute de la table source, sans aucune transformation
-- Matérialisation : VIEW (définie dans dbt_project.yml)
-- =====================================================================

select *
from {{ source('raw_customer', 'customer_loyalty') }}
