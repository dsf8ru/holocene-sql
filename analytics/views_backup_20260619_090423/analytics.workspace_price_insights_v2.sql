CREATE OR REPLACE VIEW analytics.workspace_price_insights_v2 AS
WITH price_points AS (
  SELECT
    a."userId",
    a."sellerConnectionId",
    a.marketplace,
    a."marketplaceId",
    a.sku,
    MAX(a.asin) AS asin,
    MAX(a.currency_code) AS currency_code,
    a.price,

    COUNT(DISTINCT a.order_date) AS days_seen,
    SUM(a.orders) AS orders,
    SUM(a.units) AS units,
    SUM(a.revenue) AS revenue,
    SUM(a.profit_before_ads) AS profit_before_ads,
    SUM(a.ads_spend_allocated) AS ads_spend,
    SUM(a.profit) AS profit,

    SUM(a.impressions_allocated) AS impressions,
    SUM(a.clicks_allocated) AS clicks,
    SUM(a.ads_units_allocated) AS ads_units,
    SUM(a.ads_sales_revenue_allocated) AS ads_sales_revenue,

    AVG(a.units) AS avg_daily_units,
    AVG(a.revenue) AS avg_daily_revenue,
    AVG(a.profit) AS avg_daily_profit,
    AVG(a.ads_spend_allocated) AS avg_daily_ads_spend,
    STDDEV_SAMP(a.units) AS stddev_daily_units
  FROM analytics.workspace_day_price_allocated_v2 a
  GROUP BY
    a."userId",
    a."sellerConnectionId",
    a.marketplace,
    a."marketplaceId",
    a.sku,
    a.price
),

scored_base AS (
  SELECT
    pp.*,
    CASE
      WHEN pp.days_seen < 2 THEN 0::numeric
      WHEN pp.avg_daily_units IS NULL OR pp.avg_daily_units = 0 THEN 0::numeric
      ELSE GREATEST(
        0::numeric,
        LEAST(
          1::numeric,
          1::numeric - COALESCE(pp.stddev_daily_units, 0) / NULLIF(pp.avg_daily_units, 0)
        )
      )
    END AS confidence_per_price
  FROM price_points pp
),

scored AS (
  SELECT
    s.*,

    s.revenue / NULLIF(s.days_seen, 0) AS revenue_per_day,
    s.profit / NULLIF(s.days_seen, 0) AS profit_per_day,
    s.ads_spend / NULLIF(s.days_seen, 0) AS ads_spend_per_day,
    s.ads_sales_revenue / NULLIF(s.days_seen, 0) AS ads_sales_per_day,

    s.clicks / NULLIF(s.impressions, 0) AS ctr,
    s.ads_spend / NULLIF(s.clicks, 0) AS cpc,
    s.ads_sales_revenue / NULLIF(s.ads_spend, 0) AS roas,
    s.ads_spend / NULLIF(s.ads_sales_revenue, 0) AS acos,
    s.ads_spend / NULLIF(s.revenue, 0) AS tacos,
    s.orders::numeric / NULLIF(s.clicks, 0) AS orders_per_click,

    CASE
      WHEN s.days_seen >= 7 AND s.units >= 20 AND s.confidence_per_price >= 0.5 THEN 'High'
      WHEN s.days_seen >= 3 AND s.units >= 10 THEN 'Medium'
      WHEN s.days_seen >= 2 THEN 'Low'
      ELSE 'Very Low'
    END AS confidence_label,

    s.days_seen >= 3
      AND s.units >= 10
      AND s.confidence_per_price >= 0.3 AS is_effective_price_point,

    s.days_seen >= 7
      AND s.units >= 20
      AND s.confidence_per_price >= 0.5 AS is_modeling_price_point
  FROM scored_base s
),

ranked AS (
  SELECT
    s.*,

    ROW_NUMBER() OVER (
      PARTITION BY
        s."userId",
        s.marketplace,
        s.sku
      ORDER BY
        s.profit_per_day DESC NULLS LAST,
        s.price ASC
    ) AS profit_rank,

    ROW_NUMBER() OVER (
      PARTITION BY
        s."userId",
        s.marketplace,
        s.sku
      ORDER BY
        s.revenue_per_day DESC NULLS LAST,
        s.price ASC
    ) AS revenue_rank,

    CASE
      WHEN s.is_modeling_price_point = true THEN
        ROW_NUMBER() OVER (
          PARTITION BY
            s."userId",
            s.marketplace,
            s.sku,
            s.is_modeling_price_point
          ORDER BY
            s.profit_per_day DESC NULLS LAST,
            s.price ASC
        )
      ELSE NULL
    END AS modeling_profit_rank,

    CASE
      WHEN s.is_modeling_price_point = true THEN
        ROW_NUMBER() OVER (
          PARTITION BY
            s."userId",
            s.marketplace,
            s.sku,
            s.is_modeling_price_point
          ORDER BY
            s.revenue_per_day DESC NULLS LAST,
            s.price ASC
        )
      ELSE NULL
    END AS modeling_revenue_rank

  FROM scored s
)

SELECT
  "userId",
  "sellerConnectionId",
  marketplace,
  "marketplaceId",
  sku,
  asin,
  currency_code,
  price,

  days_seen,
  orders,
  units,
  revenue,
  profit_before_ads,
  ads_spend,
  profit,

  impressions,
  clicks,
  ads_units,
  ads_sales_revenue,

  avg_daily_units,
  avg_daily_revenue,
  avg_daily_profit,
  avg_daily_ads_spend,
  stddev_daily_units,

  confidence_per_price,

  revenue_per_day,
  profit_per_day,
  ads_spend_per_day,
  ads_sales_per_day,

  ctr,
  cpc,
  roas,
  acos,
  tacos,
  orders_per_click,

  confidence_label,
  is_effective_price_point,
  is_modeling_price_point,

  profit_rank,
  revenue_rank,
  modeling_profit_rank,
  modeling_revenue_rank

FROM ranked;
