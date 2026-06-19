DROP VIEW IF EXISTS analytics.dashboard_profit_by_sku_v2 CASCADE;

CREATE OR REPLACE VIEW analytics.dashboard_profit_by_sku_v2 AS
 WITH bounds AS (
         SELECT daily_sku_fact_v2."userId",
            daily_sku_fact_v2.marketplace,
            max(daily_sku_fact_v2.report_date) AS period_end,
            max(daily_sku_fact_v2.report_date) - '59 days'::interval AS period_start
           FROM analytics.daily_sku_fact_v2
          WHERE daily_sku_fact_v2.marketplace IS NOT NULL
          GROUP BY daily_sku_fact_v2."userId", daily_sku_fact_v2.marketplace
        ), period_rows AS (
         SELECT f_1."userId",
            f_1."sellerConnectionId",
            f_1.marketplace,
            f_1."marketplaceId",
            f_1.sku,
            f_1.asin,
            f_1.report_date,
            f_1.currency_code,
            f_1.units_sold,
            f_1.revenue,
            f_1.ads_impressions,
            f_1.ads_clicks,
            f_1.ads_spend,
            f_1.ads_units,
            f_1.ads_sales_revenue
           FROM analytics.daily_sku_fact_v2 f_1
             JOIN bounds b ON b."userId" = f_1."userId" AND b.marketplace = f_1.marketplace
          WHERE f_1.report_date >= b.period_start AND f_1.report_date <= b.period_end
        )
 SELECT "userId",
    "sellerConnectionId",
    marketplace,
    sku,
    max(asin) AS asin,
    max(currency_code) AS currency_code,
    sum(revenue) AS revenue,
    sum(units_sold) AS units_sold,
    sum(ads_spend) AS ads_spend,
    sum(ads_units) AS ads_units,
    sum(ads_sales_revenue) AS ads_sales_revenue,
    sum(revenue) - sum(ads_spend) AS contribution_after_ads,
    round(
        CASE
            WHEN sum(revenue) > 0::numeric THEN sum(ads_spend) / sum(revenue)
            ELSE NULL::numeric
        END, 4) AS tacos,
    round(
        CASE
            WHEN sum(ads_sales_revenue) > 0::numeric THEN sum(ads_spend) / sum(ads_sales_revenue)
            ELSE NULL::numeric
        END, 4) AS acos
   FROM period_rows f
  GROUP BY "userId", "sellerConnectionId", marketplace, sku;
;
