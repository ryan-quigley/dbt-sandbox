with

source as (

    select *
    from {{ source('ecom', 'customers') }}
    -- Removing customers selectively breaks test in orders and order_items
    -- where id not in (
    --     select id
    --     from {{ ref('seed_exclude_customers') }}
    -- )
),

renamed as (

    select

        ----------  ids
        id as customer_id,

        ---------- text
        name as customer_name

    from source

)

select * from renamed
