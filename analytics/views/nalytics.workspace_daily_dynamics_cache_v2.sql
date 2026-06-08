DROP MATERIALIZED VIEW IF EXISTS analytics.workspace_daily_dynamics_cache_v2;

CREATE MATERIALIZED VIEW analytics.workspace_daily_dynamics_cache_v2 AS
SELECT
  "userId",
  marketplace,
  sku,
  order_date,
  MAX(currency_code)::text AS currency_code,
  SUM(revenue)::numeric AS revenue,
  SUM(profit)::numeric AS profit,
  SUM(ads_spend_allocated)::numeric AS ads_spend,
  CASE
    WHEN SUM(units) = 0 THEN 0
    ELSE SUM(revenue) / SUM(units)
  END AS price
FROM analytics.workspace_day_price_allocated_v2
GROUP BY
  "userId",
  marketplace,
  sku,
  order_date;

CREATE INDEX idx_workspace_daily_dynamics_cache_v2_main
ON analytics.workspace_daily_dynamics_cache_v2 ("userId", marketplace, sku, order_date);
