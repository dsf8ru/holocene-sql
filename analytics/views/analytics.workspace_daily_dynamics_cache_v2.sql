DROP MATERIALIZED VIEW IF EXISTS analytics.workspace_daily_dynamics_cache_v2 CASCADE;

CREATE MATERIALIZED VIEW analytics.workspace_daily_dynamics_cache_v2 AS
 SELECT "userId",
    marketplace,
    sku,
    order_date,
    max(currency_code) AS currency_code,
    sum(revenue) AS revenue,
    sum(profit) AS profit,
    sum(ads_spend_allocated) AS ads_spend,
        CASE
            WHEN sum(units) = 0::numeric THEN 0::numeric
            ELSE sum(revenue) / sum(units)
        END AS price
   FROM analytics.workspace_day_price_allocated_v2
  GROUP BY "userId", marketplace, sku, order_date;
;
