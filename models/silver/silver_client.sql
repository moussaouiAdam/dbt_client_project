-- =====================================================================
-- SILVER : nettoyage, standardisation, enrichissement, filtrage
-- Matérialisation : TABLE
-- On lit la couche bronze avec ref() : dbt connaît ainsi la dépendance
-- =====================================================================

with bronze as (

    select * from {{ ref('bronze_client') }}

),

nettoye as (

    select
        customer_id,

        -- Nettoyage : suppression des espaces + majuscules
        trim(upper(first_name))          as first_name,
        trim(upper(last_name))           as last_name,
        trim(upper(city))                as city,
        trim(upper(country))             as country,
        trim(postal_code)                as postal_code,
        trim(upper(preferred_language))  as preferred_language,
        trim(upper(gender))              as gender,
        trim(upper(marital_status))      as marital_status,
        trim(favourite_brand)            as favourite_brand,

        -- children_count est un VARCHAR (peut contenir "Undisclosed")
        try_to_number(children_count)    as children_count,

        -- Standardisation : email en minuscules
        lower(trim(e_mail))              as email,
        trim(phone_number)               as phone_number,

        -- Dates sécurisées : TRY_TO_DATE renvoie NULL au lieu d'une erreur
        try_to_date(to_varchar(sign_up_date))   as sign_up_date,
        try_to_date(to_varchar(birthday_date))  as birthday_date

    from bronze

)

select
    *,

    -- Enrichissement : âge et ancienneté d'inscription
    floor(datediff('day', birthday_date, current_date()) / 365.25)  as age,
    datediff('day', sign_up_date, current_date())                  as jours_inscription

from nettoye

-- Filtrage : on exclut les lignes sans identifiant
where customer_id is not null
