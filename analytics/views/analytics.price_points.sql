DROP VIEW IF EXISTS analytics.price_points CASCADE;

CREATE OR REPLACE VIEW analytics.price_points AS
 SELECT "userId",
    marketplace,
    sku,
    round(price::numeric, 2) AS price,
    count(DISTINCT order_date) AS active_days,
    sum(quantity) AS total_units,
    round(sum(quantity)::numeric / NULLIF(count(DISTINCT order_date), 0)::numeric, 2) AS avg_daily_units,
    round(sum(revenue), 2) AS total_revenue,
    round(sum(row_profit), 2) AS total_profit,
    round(sum(row_profit) / NULLIF(sum(revenue), 0::numeric), 4) AS profit_margin,
    round(avg(price), 2) AS avg_price,
    round(sum(COALESCE(ads_spend, 0::numeric)), 2) AS ads_spend,
    sum(COALESCE(clicks, 0::bigint)) AS clicks,
    sum(COALESCE(impressions, 0::bigint)) AS impressions,
    round(sum(COALESCE(clicks, 0::bigint)) / NULLIF(sum(COALESCE(impressions, 0::bigint)), 0::numeric), 4) AS ctr,
    round(sum(COALESCE(ads_spend, 0::numeric)) / NULLIF(sum(revenue), 0::numeric), 4) AS tacos,
    round(1::numeric - stddev(quantity) / NULLIF(avg(quantity), 0::numeric), 4) AS price_performance
   FROM analytics.orders_enriched
  WHERE price > 0::numeric
  GROUP BY "userId", marketplace, sku, (round(price::numeric, 2));
;
