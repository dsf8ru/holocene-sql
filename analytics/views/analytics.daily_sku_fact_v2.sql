DROP VIEW IF EXISTS analytics.daily_sku_fact_v2 CASCADE;

CREATE OR REPLACE VIEW analytics.daily_sku_fact_v2 AS
 WITH sales AS (
         SELECT orders."userId",
            orders."sellerConnectionId",
            orders.marketplace,
            orders."marketplaceId",
            orders.sku,
            max(orders.asin) AS asin,
            orders.order_date AS report_date,
            max(orders.currency_code) AS currency_code,
            sum(orders.quantity) AS units_sold,
            sum(orders.price * orders.quantity::numeric) AS revenue
           FROM raw.orders
          WHERE orders.sku IS NOT NULL AND orders.order_date IS NOT NULL AND orders.quantity IS NOT NULL AND orders.price IS NOT NULL
          GROUP BY orders."userId", orders."sellerConnectionId", orders.marketplace, orders."marketplaceId", orders.sku, orders.order_date
        ), ads AS (
         SELECT ads."userId",
            ads."sellerConnectionId",
            ads.marketplace,
            ads.sku,
            max(ads.asin) AS asin,
            ads.report_date,
            sum(ads.impressions) AS ads_impressions,
            sum(ads.clicks) AS ads_clicks,
            sum(ads.ads_spend) AS ads_spend,
            sum(ads.ads_units) AS ads_units,
            sum(ads.ads_sales_revenue) AS ads_sales_revenue
           FROM raw.ads
          WHERE ads."userId" IS NOT NULL AND ads."userId" <> ''::text AND ads.sku IS NOT NULL AND ads.report_date IS NOT NULL
          GROUP BY ads."userId", ads."sellerConnectionId", ads.marketplace, ads.sku, ads.report_date
        )
 SELECT COALESCE(s."userId", a."userId") AS "userId",
    COALESCE(s."sellerConnectionId", a."sellerConnectionId") AS "sellerConnectionId",
    COALESCE(s.marketplace, a.marketplace) AS marketplace,
    s."marketplaceId",
    COALESCE(s.sku, a.sku) AS sku,
    COALESCE(s.asin, a.asin) AS asin,
    COALESCE(s.report_date, a.report_date) AS report_date,
    s.currency_code,
    COALESCE(s.units_sold, 0::bigint) AS units_sold,
    COALESCE(s.revenue, 0::numeric) AS revenue,
    COALESCE(a.ads_impressions, 0::bigint) AS ads_impressions,
    COALESCE(a.ads_clicks, 0::bigint) AS ads_clicks,
    COALESCE(a.ads_spend, 0::numeric) AS ads_spend,
    COALESCE(a.ads_units, 0::bigint) AS ads_units,
    COALESCE(a.ads_sales_revenue, 0::numeric) AS ads_sales_revenue
   FROM sales s
     FULL JOIN ads a ON a."userId" = s."userId" AND COALESCE(a."sellerConnectionId", ''::text) = COALESCE(s."sellerConnectionId", ''::text) AND a.marketplace = s.marketplace AND a.sku = s.sku AND a.report_date = s.report_date;
;
