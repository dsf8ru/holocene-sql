DROP VIEW IF EXISTS analytics.advertising_opportunities_v1;

CREATE VIEW analytics.advertising_opportunities_v1 AS
WITH base AS (
  SELECT
    s.*,

    0.08::numeric AS target_tacos,

    CASE
      WHEN s.roas IS NOT NULL
      THEN LEAST(s.roas, 5) * 0.50
      ELSE NULL
    END AS conservative_roas,

    CASE
      WHEN s.current_revenue_60d > 0
      THEN s.current_revenue_60d * 0.08
      ELSE 0
    END AS target_ads_spend_60d
  FROM analytics.advertising_signals_v1 s
),
calc AS (
  SELECT
    *,

    GREATEST(
      0,
      target_ads_spend_60d - ads_spend_60d
    ) AS additional_ads_spend_60d
  FROM base
)
SELECT
  "userId",
  "sellerConnectionId",
  marketplace,
  "marketplaceId",
  sku,
  asin,
  currency_code,

  current_revenue_60d,
  revenue_opportunity_60d AS pricing_revenue_opportunity_60d,

  ads_days,
  impressions_60d,
  clicks_60d,
  ads_spend_60d,
  ads_units_60d,
  ads_sales_60d,
  ctr,
  cpc,
  roas,
  tacos,

  target_tacos,
  target_ads_spend_60d,
  additional_ads_spend_60d,
  conservative_roas,

  CASE
    WHEN roas >= 3
     AND tacos < target_tacos
     AND ads_spend_60d > 0
     AND current_revenue_60d > 0
    THEN additional_ads_spend_60d * conservative_roas
    ELSE 0
  END AS ads_revenue_opportunity_60d,

  CASE
    WHEN roas >= 3
     AND tacos < target_tacos
     AND ads_spend_60d > 0
     AND current_revenue_60d > 0
     AND additional_ads_spend_60d > 0
    THEN 'ads_expansion'
    WHEN ads_spend_60d = 0
    THEN 'no_ads_data'
    ELSE 'no_ads_expansion_opportunity'
  END AS ads_opportunity_type,

  CASE
    WHEN roas >= 3
     AND tacos < target_tacos
     AND ads_spend_60d > 0
     AND current_revenue_60d > 0
     AND additional_ads_spend_60d > 0
    THEN 'Estimated ads expansion opportunity'
    WHEN ads_spend_60d = 0
    THEN 'No ads data'
    ELSE 'No clear ads expansion opportunity'
  END AS ads_opportunity_label

FROM calc;
