CREATE OR REPLACE VIEW analytics.workspace_day_price_allocated_v2 AS
WITH day_totals AS (
  SELECT
    s."userId",
    s.marketplace,
    s.sku,
    s.order_date,
    SUM(s.revenue) AS daily_revenue,
    SUM(s.units) AS daily_units,
    SUM(s.orders) AS daily_orders
  FROM analytics.workspace_day_price_sales_v2 s
  GROUP BY
    s."userId",
    s.marketplace,
    s.sku,
    s.order_date
)
SELECT
  s."userId",
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

  COALESCE(a.ads_spend, 0) AS daily_ads_spend,
  COALESCE(a.impressions, 0) AS daily_impressions,
  COALESCE(a.clicks, 0) AS daily_clicks,
  COALESCE(a.ads_units, 0) AS daily_ads_units,
  COALESCE(a.ads_sales_revenue, 0) AS daily_ads_sales_revenue,

  CASE
    WHEN dt.daily_revenue > 0
    THEN COALESCE(a.ads_spend, 0) * s.revenue / dt.daily_revenue
    ELSE 0
  END AS ads_spend_allocated,

  CASE
    WHEN dt.daily_revenue > 0
    THEN COALESCE(a.impressions, 0)::numeric * s.revenue / dt.daily_revenue
    ELSE 0
  END AS impressions_allocated,

  CASE
    WHEN dt.daily_revenue > 0
    THEN COALESCE(a.clicks, 0)::numeric * s.revenue / dt.daily_revenue
    ELSE 0
  END AS clicks_allocated,

  CASE
    WHEN dt.daily_revenue > 0
    THEN COALESCE(a.ads_units, 0)::numeric * s.revenue / dt.daily_revenue
    ELSE 0
  END AS ads_units_allocated,

  CASE
    WHEN dt.daily_revenue > 0
    THEN COALESCE(a.ads_sales_revenue, 0) * s.revenue / dt.daily_revenue
    ELSE 0
  END AS ads_sales_revenue_allocated,

  CASE
    WHEN s.profit_before_ads IS NOT NULL
    THEN s.profit_before_ads -
      CASE
        WHEN dt.daily_revenue > 0
        THEN COALESCE(a.ads_spend, 0) * s.revenue / dt.daily_revenue
        ELSE 0
      END
    ELSE NULL
  END AS profit
FROM analytics.workspace_day_price_sales_v2 s
JOIN day_totals dt
  ON dt."userId" = s."userId"
 AND dt.marketplace = s.marketplace
 AND dt.sku = s.sku
 AND dt.order_date = s.order_date
LEFT JOIN analytics.workspace_daily_ads_v2 a
  ON a."userId" = s."userId"
 AND a.marketplace = s.marketplace
 AND a.sku = s.sku
 AND a.order_date = s.order_date;
