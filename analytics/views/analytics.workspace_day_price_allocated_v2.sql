DROP VIEW IF EXISTS analytics.workspace_day_price_allocated_v2 CASCADE;

CREATE OR REPLACE VIEW analytics.workspace_day_price_allocated_v2 AS
 WITH day_totals AS (
         SELECT s_1."userId",
            s_1.marketplace,
            s_1.sku,
            s_1.order_date,
            sum(s_1.revenue) AS daily_revenue,
            sum(s_1.units) AS daily_units,
            sum(s_1.orders) AS daily_orders
           FROM analytics.workspace_day_price_sales_v2 s_1
          GROUP BY s_1."userId", s_1.marketplace, s_1.sku, s_1.order_date
        )
 SELECT s."userId",
    s."sellerConnectionId",
    s.marketplace,
    s."marketplaceId",
    s.sku,
    s.asin,
    s.order_date,
    s.price,
    s.currency_code,
    s.orders,
    s.units,
    s.revenue,
    s.profit_before_ads,
    s.has_complete_costs,
    COALESCE(a.ads_spend, 0::numeric) AS daily_ads_spend,
    COALESCE(a.impressions, 0::bigint) AS daily_impressions,
    COALESCE(a.clicks, 0::bigint) AS daily_clicks,
    COALESCE(a.ads_units, 0::bigint) AS daily_ads_units,
    COALESCE(a.ads_sales_revenue, 0::numeric) AS daily_ads_sales_revenue,
        CASE
            WHEN dt.daily_revenue > 0::numeric THEN COALESCE(a.ads_spend, 0::numeric) * s.revenue / dt.daily_revenue
            ELSE 0::numeric
        END AS ads_spend_allocated,
        CASE
            WHEN dt.daily_revenue > 0::numeric THEN COALESCE(a.impressions, 0::bigint)::numeric * s.revenue / dt.daily_revenue
            ELSE 0::numeric
        END AS impressions_allocated,
        CASE
            WHEN dt.daily_revenue > 0::numeric THEN COALESCE(a.clicks, 0::bigint)::numeric * s.revenue / dt.daily_revenue
            ELSE 0::numeric
        END AS clicks_allocated,
        CASE
            WHEN dt.daily_revenue > 0::numeric THEN COALESCE(a.ads_units, 0::bigint)::numeric * s.revenue / dt.daily_revenue
            ELSE 0::numeric
        END AS ads_units_allocated,
        CASE
            WHEN dt.daily_revenue > 0::numeric THEN COALESCE(a.ads_sales_revenue, 0::numeric) * s.revenue / dt.daily_revenue
            ELSE 0::numeric
        END AS ads_sales_revenue_allocated,
        CASE
            WHEN s.profit_before_ads IS NOT NULL THEN s.profit_before_ads -
            CASE
                WHEN dt.daily_revenue > 0::numeric THEN COALESCE(a.ads_spend, 0::numeric) * s.revenue / dt.daily_revenue
                ELSE 0::numeric
            END
            ELSE NULL::numeric
        END AS profit
   FROM analytics.workspace_day_price_sales_v2 s
     JOIN day_totals dt ON dt."userId" = s."userId" AND dt.marketplace = s.marketplace AND dt.sku = s.sku AND dt.order_date = s.order_date
     LEFT JOIN analytics.workspace_daily_ads_v2 a ON a."userId" = s."userId" AND a.marketplace = s.marketplace AND a.sku = s.sku AND a.order_date = s.order_date;
;
