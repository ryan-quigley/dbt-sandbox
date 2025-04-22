with customer_metrics as (
    select
        customer_id,
        customer_name,
        customer_type,
        count_lifetime_orders,
        lifetime_spend_pretax,
        lifetime_spend,
        first_ordered_at,
        last_ordered_at,
        
        -- Calculate days since first order
        datediff('day', first_ordered_at, current_timestamp()) as days_since_first_order,
        
        -- Calculate days since last order
        datediff('day', last_ordered_at, current_timestamp()) as days_since_last_order,
        
        -- Calculate average order value
        lifetime_spend_pretax / nullif(count_lifetime_orders, 0) as avg_order_value,
        
        -- Calculate order frequency (orders per month)
        count_lifetime_orders::float / 
        nullif(datediff('month', first_ordered_at, greatest(last_ordered_at, current_timestamp())), 0) 
        as orders_per_month
    
    from {{ ref('customers') }}
    where count_lifetime_orders > 0  -- Exclude customers with no orders
),

loyalty_scoring as (
    select
        *,
        
        -- Scoring components (each normalized to 0-100 scale)
        least(count_lifetime_orders * 10, 100) as order_count_score,
        least((lifetime_spend_pretax / 1000) * 100, 100) as spend_score,
        least((orders_per_month * 25), 100) as frequency_score,
        case 
            when days_since_last_order <= 30 then 100
            when days_since_last_order <= 90 then 75
            when days_since_last_order <= 180 then 50
            when days_since_last_order <= 365 then 25
            else 0
        end as recency_score,
        
        -- Calculate overall loyalty score (weighted average)
        (
            (least(count_lifetime_orders * 10, 100) * 0.3) +  -- 30% weight on order count
            (least((lifetime_spend_pretax / 1000) * 100, 100) * 0.3) +  -- 30% weight on total spend
            (least((orders_per_month * 25), 100) * 0.2) +  -- 20% weight on frequency
            (case  -- 20% weight on recency
                when days_since_last_order <= 30 then 100
                when days_since_last_order <= 90 then 75
                when days_since_last_order <= 180 then 50
                when days_since_last_order <= 365 then 25
                else 0
            end * 0.2)
        ) as loyalty_score
    from customer_metrics
)

select
    customer_id,
    customer_name,
    customer_type,
    count_lifetime_orders,
    lifetime_spend_pretax,
    lifetime_spend,
    first_ordered_at,
    last_ordered_at,
    days_since_first_order,
    days_since_last_order,
    avg_order_value,
    orders_per_month,
    order_count_score,
    spend_score,
    frequency_score,
    recency_score,
    loyalty_score,
    
    -- Loyalty tier based on overall score
    case
        when loyalty_score >= 80 then 'Diamond'
        when loyalty_score >= 60 then 'Gold'
        when loyalty_score >= 40 then 'Silver'
        else 'Bronze'
    end as loyalty_tier

from loyalty_scoring 