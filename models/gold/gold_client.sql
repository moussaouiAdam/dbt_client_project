-- =====================================================================
-- GOLD : jointure clients x commandes, agrégation, segmentation business
-- Matérialisation : TABLE
-- =====================================================================

with clients as (

    select * from {{ ref('silver_client') }}

),

-- Une ligne par commande (seulement les commandes de membres fidélité)
commandes as (

    select
        customer_id,
        order_id,
        order_ts,
        order_total
    from {{ source('raw_pos', 'order_header') }}
    where customer_id is not null

),

-- On agrège le détail PAR COMMANDE avant la jointure,
-- sinon order_total serait compté une fois par article (doublons)
articles as (

    select
        order_id,
        sum(quantity) as nb_articles
    from {{ source('raw_pos', 'order_detail') }}
    group by order_id

),

-- Agrégation par client
commandes_par_client as (

    select
        c.customer_id,
        count(distinct c.order_id)      as total_orders,
        sum(c.order_total)              as total_spent,
        sum(coalesce(a.nb_articles, 0)) as total_items,
        min(c.order_ts)                 as first_order_ts,
        max(c.order_ts)                 as last_order_ts
    from commandes c
    left join articles a
        on c.order_id = a.order_id
    group by c.customer_id

)

select
    cl.customer_id,
    cl.first_name,
    cl.last_name,
    cl.email,
    cl.city,
    cl.country,
    cl.age,
    cl.jours_inscription,

    cpc.total_orders,
    cpc.total_spent,
    cpc.total_items,
    round(cpc.total_spent / nullif(cpc.total_orders, 0), 2) as panier_moyen,
    cpc.first_order_ts,
    cpc.last_order_ts,

    -- Segmentation business
    case
        when cpc.total_spent > 10000 then 'PLATINUM'
        when cpc.total_spent > 5000  then 'GOLD'
        when cpc.total_spent > 1000  then 'SILVER'
        else 'BRONZE'
    end as client_segment

from clients cl
-- inner join : on ne garde que les clients ayant passé au moins une commande
inner join commandes_par_client cpc
    on cl.customer_id = cpc.customer_id
