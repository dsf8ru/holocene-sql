DROP VIEW IF EXISTS analytics.daily_sku CASCADE;

CREATE OR REPLACE VIEW analytics.daily_sku AS
 SELECT "userId",
    order_date,
    marketplace,
    sku,
    sum(quantity) AS units_sold,
    round(avg(price), 2) AS avg_price,
    round(sum(revenue), 2) AS revenue,
    round(sum(row_profit), 2) AS total_profit,
    round(sum(row_profit) / NULLIF(sum(revenue), 0::numeric), 4) AS profit_margin,
    round(sum(COALESCE(ads_spend, 0::numeric)), 2) AS ads_spend,
    sum(COALESCE(clicks, 0::bigint)) AS clicks,
    sum(COALESCE(impressions, 0::bigint)) AS impressions,
    round(sum(COALESCE(clicks, 0::bigint)) / NULLIF(sum(COALESCE(impressions, 0::bigint)), 0::numeric), 4) AS ctr
   FROM analytics.orders_enriched
  GROUP BY "userId", order_date, marketplace, sku;
;
