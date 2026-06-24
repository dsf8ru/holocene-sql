DROP VIEW IF EXISTS analytics.advertising_signals_v1;

CREATE VIEW analytics.advertising_signals_v1 AS
WITH ads_60d AS (
  SELECT
    a."userId",
    a."sellerConnectionId",
    a.marketplace,
    a.sku,
    MAX(a.asin) AS asin,
    COUNT(DISTINCT a.report_date) AS ads_days,
    SUM(a.impressions) AS impressions_60d,
    SUM(a.clicks) AS clicks_60d,
    SUM(a.ads_spend) AS ads_spend_60d,
    SUM(a.ads_units) AS ads_units_60d,
    SUM(a.ads_sales_revenue) AS ads_sales_60d
  FROM raw.ads a
  JOIN (
    SELECT
      "userId",
      marketplace,
      MAX(report_date) AS period_end,
      MAX(report_date) - INTERVAL '59 days' AS period_start
    FROM raw.ads
    WHERE marketplace IS NOT NULL
    GROUP BY "userId", marketplace
  ) b
    ON b."userId" = a."userId"
   AND b.marketplace = a.marketplace
  WHERE a.report_date >= b.period_start
    AND a.report_date <= b.period_end
    AND a.sku IS NOT NULL
  GROUP BY a."userId", a."sellerConnectionId", a.marketplace, a.sku
),
joined AS (
  SELECT
    d."userId",
    d."sellerConnectionId",
    d.marketplace,
    d."marketplaceId",
    d.sku,
    d.asin,
    d.currency_code,
    d.current_revenue_60d,
    d.revenue_opportunity_60d,
    COALESCE(a.ads_days, 0) AS ads_days,
    COALESCE(a.impressions_60d, 0) AS impressions_60d,
    COALESCE(a.clicks_60d, 0) AS clicks_60d,
    COALESCE(a.ads_spend_60d, 0) AS ads_spend_60d,
    COALESCE(a.ads_units_60d, 0) AS ads_units_60d,
    COALESCE(a.ads_sales_60d, 0) AS ads_sales_60d,
    CASE WHEN COALESCE(a.impressions_60d, 0) > 0
      THEN COALESCE(a.clicks_60d, 0)::numeric / NULLIF(a.impressions_60d, 0)
    END AS ctr,
    CASE WHEN COALESCE(a.clicks_60d, 0) > 0
      THEN COALESCE(a.ads_spend_60d, 0)::numeric / NULLIF(a.clicks_60d, 0)
    END AS cpc,
    CASE WHEN COALESCE(a.ads_spend_60d, 0) > 0
      THEN COALESCE(a.ads_sales_60d, 0)::numeric / NULLIF(a.ads_spend_60d, 0)
    END AS roas,
    CASE WHEN d.current_revenue_60d > 0
      THEN COALESCE(a.ads_spend_60d, 0)::numeric / NULLIF(d.current_revenue_60d, 0)
    END AS tacos
  FROM analytics.dashboard_product_opportunities_cache d
  LEFT JOIN ads_60d a
    ON a."userId" = d."userId"
   AND a.marketplace = d.marketplace
   AND a.sku = d.sku
)
SELECT
  *,
  CASE
    WHEN ads_spend_60d = 0 THEN 'no_ads'
    WHEN roas >= 5
      AND tacos <= 0.05
      AND (
        ads_spend_60d >= 50
        OR clicks_60d >= 20
        OR ads_units_60d >= 3
      ) THEN 'underinvested'
    WHEN roas < 2 AND ads_spend_60d >= 100 THEN 'inefficient'
    WHEN roas >= 3 AND tacos <= 0.10 THEN 'healthy'
    ELSE 'monitor'
  END AS signal_type,
  CASE
    WHEN ads_spend_60d = 0 THEN 'No ads running'
    WHEN roas >= 5
      AND tacos <= 0.05
      AND (
        ads_spend_60d >= 50
        OR clicks_60d >= 20
        OR ads_units_60d >= 3
      ) THEN 'High ROAS, consider scaling'
    WHEN roas < 2 AND ads_spend_60d >= 100 THEN 'Advertising efficiency concern'
    WHEN roas >= 3 AND tacos <= 0.10 THEN 'Advertising healthy'
    ELSE 'Monitor advertising performance'
  END AS signal_label,
  CASE
    WHEN ads_spend_60d = 0 THEN 1
    WHEN roas >= 5
      AND tacos <= 0.05
      AND (
        ads_spend_60d >= 50
        OR clicks_60d >= 20
        OR ads_units_60d >= 3
      ) THEN 1
    WHEN roas < 2 AND ads_spend_60d >= 100 THEN 1
    WHEN roas >= 3 AND tacos <= 0.10 THEN 2
    ELSE 3
  END AS signal_priority
FROM joined;
