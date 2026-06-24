CREATE OR REPLACE VIEW analytics.workspace_summary_v2 AS
WITH price_insights AS (
  SELECT *
  FROM analytics.workspace_price_insights_v2
),

sku_totals AS (
  SELECT
    pi."userId" AS user_id,
    MAX(pi."sellerConnectionId") AS seller_connection_id,
    pi.marketplace,
    MAX(pi."marketplaceId") AS marketplace_id,
    pi.sku,
    MAX(pi.asin) AS asin,
    MAX(pi.currency_code) AS currency_code,

    SUM(pi.days_seen) AS price_days_seen,
    SUM(pi.orders) AS orders,
    SUM(pi.units) AS units,
    SUM(pi.revenue) AS revenue,
    SUM(pi.profit_before_ads) AS profit_before_ads,
    SUM(pi.ads_spend) AS ads_spend,
    SUM(pi.profit) AS profit,

    SUM(pi.impressions) AS impressions,
    SUM(pi.clicks) AS clicks,
    SUM(pi.ads_units) AS ads_units,
    SUM(pi.ads_sales_revenue) AS ads_sales_revenue,

    COUNT(*) AS raw_price_points,
    COUNT(*) FILTER (WHERE pi.is_effective_price_point = true) AS effective_price_points,
    COUNT(*) FILTER (WHERE pi.is_modeling_price_point = true) AS modeling_price_points
  FROM price_insights pi
  GROUP BY
    pi."userId",
    pi.marketplace,
    pi.sku
),

period_days AS (
  SELECT
    a."userId" AS user_id,
    a.marketplace,
    a.sku,
    COUNT(DISTINCT a.order_date) AS period_days
  FROM analytics.workspace_day_price_allocated_v2 a
  GROUP BY
    a."userId",
    a.marketplace,
    a.sku
),

best_revenue AS (
  SELECT DISTINCT ON (user_id, marketplace, sku)
    user_id,
    marketplace,
    sku,
    candidate_price AS best_revenue_price,
    expected_daily_revenue AS best_revenue_per_day,
    expected_daily_profit AS best_revenue_profit_per_day,
    expected_daily_ads_spend AS best_revenue_ads_spend_per_day,
    candidate_type AS best_revenue_candidate_type
  FROM analytics.workspace_modeled_prices_v2
  ORDER BY
    user_id,
    marketplace,
    sku,
    expected_daily_revenue DESC NULLS LAST,
    CASE WHEN candidate_type = 'modeled' THEN 0 ELSE 1 END,
    candidate_price ASC
),

best_profit AS (
  SELECT DISTINCT ON (user_id, marketplace, sku)
    user_id,
    marketplace,
    sku,
    candidate_price AS best_profit_price,
    expected_daily_profit AS best_profit_per_day,
    expected_daily_revenue AS best_profit_revenue_per_day,
    expected_daily_ads_spend AS best_profit_ads_spend_per_day,
    candidate_type AS best_profit_candidate_type
  FROM analytics.workspace_modeled_prices_v2
  ORDER BY
    user_id,
    marketplace,
    sku,
    expected_daily_profit DESC NULLS LAST,
    CASE WHEN candidate_type = 'modeled' THEN 0 ELSE 1 END,
    candidate_price ASC
),

current_price AS (
  SELECT DISTINCT ON (a."userId", a.marketplace, a.sku)
    a."userId" AS user_id,
    a.marketplace,
    a.sku,
    a.price AS current_price
  FROM analytics.workspace_day_price_allocated_v2 a
  ORDER BY
    a."userId",
    a.marketplace,
    a.sku,
    a.order_date DESC,
    a.price DESC
)

SELECT
  st.user_id,
  st.seller_connection_id,
  st.marketplace,
  st.marketplace_id,
  st.sku,
  st.asin,
  st.currency_code,

  cp.current_price,

  st.orders,
  st.units,
  st.revenue,
  st.profit_before_ads,
  st.ads_spend,
  st.profit,

  st.impressions,
  st.clicks,
  st.ads_units,
  st.ads_sales_revenue,

  st.raw_price_points,
  st.effective_price_points,
  st.modeling_price_points,

  br.best_revenue_price,
  br.best_revenue_per_day,
  br.best_revenue_profit_per_day,
  br.best_revenue_ads_spend_per_day,
  br.best_revenue_candidate_type,

  bp.best_profit_price,
  bp.best_profit_per_day,
  bp.best_profit_revenue_per_day,
  bp.best_profit_ads_spend_per_day,
  bp.best_profit_candidate_type,

  st.revenue / NULLIF(pd.period_days, 0) AS current_revenue_per_day,
  st.profit / NULLIF(pd.period_days, 0) AS current_profit_per_day,
  st.ads_spend / NULLIF(pd.period_days, 0) AS current_ads_spend_per_day,

  GREATEST(
    COALESCE(br.best_revenue_per_day, 0) * pd.period_days - st.revenue,
    0
  ) AS revenue_opportunity,

  GREATEST(
    COALESCE(bp.best_profit_per_day, 0) * pd.period_days - st.profit,
    0
  ) AS profit_opportunity,

  st.ads_spend / NULLIF(st.revenue, 0) AS tacos,
  st.ads_sales_revenue / NULLIF(st.ads_spend, 0) AS roas,
  st.ads_spend / NULLIF(st.ads_sales_revenue, 0) AS acos,

  CASE
    WHEN st.modeling_price_points >= 3 THEN 'Strong'
    WHEN st.modeling_price_points = 2 THEN 'Limited'
    ELSE 'Insufficient'
  END AS workspace_evidence_label,

  CASE
    WHEN st.raw_price_points <= 2 THEN 'Low'
    WHEN st.raw_price_points <= 6 THEN 'Medium'
    ELSE 'High'
  END AS pricing_activity_label

FROM sku_totals st
JOIN period_days pd
  ON pd.user_id = st.user_id
 AND pd.marketplace = st.marketplace
 AND pd.sku = st.sku
LEFT JOIN best_revenue br
  ON br.user_id = st.user_id
 AND br.marketplace = st.marketplace
 AND br.sku = st.sku
LEFT JOIN best_profit bp
  ON bp.user_id = st.user_id
 AND bp.marketplace = st.marketplace
 AND bp.sku = st.sku
LEFT JOIN current_price cp
  ON cp.user_id = st.user_id
 AND cp.marketplace = st.marketplace
 AND cp.sku = st.sku;
