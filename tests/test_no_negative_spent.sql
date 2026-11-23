-- =====================================================================
-- Test personnalisé (singular test)
-- Règle : un test dbt RÉUSSIT quand la requête ne renvoie AUCUNE ligne.
-- Ici, on cherche les clients dont le total dépensé n'est pas > 0.
-- =====================================================================

select
    customer_id,
    total_spent
from {{ ref('gold_client') }}
where total_spent <= 0
