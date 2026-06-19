DROP VIEW IF EXISTS analytics.workspace_daily_ads_v2 CASCADE;

CREATE OR REPLACE VIEW analytics.workspace_daily_ads_v2 AS
 SELECT "userId",
    "sellerConnectionId",
    marketplace,
    sku,
    max(asin) AS asin,
    report_date AS order_date,
    sum(COALESCE(ads_spend, 0::numeric)) AS ads_spend,
    sum(COALESCE(impressions, 0)) AS impressions,
    sum(COALESCE(clicks, 0)) AS clicks,
    sum(COALESCE(ads_units, 0)) AS ads_units,
    sum(COALESCE(ads_sales_revenue, 0::numeric)) AS ads_sales_revenue
   FROM raw.ads ads
  WHERE "userId" IS NOT NULL AND marketplace IS NOT NULL AND sku IS NOT NULL AND report_date IS NOT NULL
  GROUP BY "userId", "sellerConnectionId", marketplace, sku, report_date;
;
