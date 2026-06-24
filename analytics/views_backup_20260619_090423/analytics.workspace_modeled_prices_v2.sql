CREATE OR REPLACE VIEW analytics.workspace_modeled_prices_v2 AS
WITH modeling_points AS (
  SELECT
    pi.*
  FROM analytics.workspace_price_insights_v2 pi
  WHERE pi.is_modeling_price_point = true
),

curve AS (
  SELECT
    mp."userId" AS user_id,
    MAX(mp."sellerConnectionId") AS seller_connection_id,
    mp.marketplace,
    MAX(mp."marketplaceId") AS marketplace_id,
    mp.sku,
    MAX(mp.asin) AS asin,
    MAX(mp.currency_code) AS currency_code,

    COUNT(*) AS modeling_price_points,

    CASE
      WHEN COUNT(*) = 2 THEN 5
      WHEN COUNT(*) = 3 THEN 7
      ELSE 9
    END AS modeled_candidate_count,

    MIN(mp.price) AS min_modeling_price,
    MAX(mp.price) AS max_modeling_price,

    (
      ARRAY_AGG(
        mp.price
        ORDER BY mp.revenue_per_day DESC NULLS LAST, mp.price DESC
      )
    )[1] AS best_observed_revenue_price,

    (
      ARRAY_AGG(
        mp.price
        ORDER BY mp.profit_per_day DESC NULLS LAST, mp.price DESC
      )
    )[1] AS best_observed_profit_price,

    GREATEST(
      0.10,
      ((MIN(mp.price) + MAX(mp.price)) / 2.0) * 0.01
    ) AS price_step,

    REGR_SLOPE(mp.avg_daily_units::float8, mp.price::float8) AS demand_slope,
    REGR_INTERCEPT(mp.avg_daily_units::float8, mp.price::float8) AS demand_intercept,

    REGR_SLOPE(mp.profit_per_day::float8, mp.price::float8) AS profit_slope,
    REGR_INTERCEPT(mp.profit_per_day::float8, mp.price::float8) AS profit_intercept,

    REGR_SLOPE(mp.ads_spend_per_day::float8, mp.price::float8) AS ads_slope,
    REGR_INTERCEPT(mp.ads_spend_per_day::float8, mp.price::float8) AS ads_intercept

  FROM modeling_points mp
  GROUP BY
    mp."userId",
    mp.marketplace,
    mp.sku
  HAVING COUNT(*) >= 2
),

observed_candidates AS (
  SELECT
    mp."userId" AS user_id,
    mp."sellerConnectionId" AS seller_connection_id,
    mp.marketplace,
    mp."marketplaceId" AS marketplace_id,
    mp.sku,
    mp.asin,
    mp.currency_code,

    'observed'::text AS candidate_type,
    mp.price AS candidate_price,

    mp.avg_daily_units AS expected_daily_units,
    mp.revenue_per_day AS expected_daily_revenue,
    mp.ads_spend_per_day AS expected_daily_ads_spend,
    mp.profit_per_day AS expected_daily_profit,

    c.modeling_price_points,
    c.modeled_candidate_count,

    c.demand_slope,
    c.demand_intercept,
    c.profit_slope,
    c.profit_intercept,
    c.ads_slope,
    c.ads_intercept,

    c.min_modeling_price,
    c.max_modeling_price,
    c.price_step,

    mp.price AS source_observed_price

  FROM modeling_points mp
  JOIN curve c
    ON c.user_id = mp."userId"
   AND c.marketplace = mp.marketplace
   AND c.sku = mp.sku
),

price_grid AS (
  SELECT
    c.*,
    gs.idx,

    CASE
      WHEN c.best_observed_revenue_price = c.max_modeling_price
        OR c.best_observed_profit_price = c.max_modeling_price
      THEN
        c.max_modeling_price
        +
        ((c.max_modeling_price * 1.10) - c.max_modeling_price)
        * gs.idx::numeric
        / (c.modeled_candidate_count + 1)::numeric

      WHEN c.best_observed_revenue_price = c.min_modeling_price
        OR c.best_observed_profit_price = c.min_modeling_price
      THEN
        (c.min_modeling_price * 0.90)
        +
        (c.min_modeling_price - (c.min_modeling_price * 0.90))
        * gs.idx::numeric
        / (c.modeled_candidate_count + 1)::numeric

      ELSE
        c.min_modeling_price
        +
        (c.max_modeling_price - c.min_modeling_price)
        * gs.idx::numeric
        / (c.modeled_candidate_count + 1)::numeric
    END AS raw_candidate_price

  FROM curve c
  CROSS JOIN LATERAL generate_series(
    1,
    c.modeled_candidate_count
  ) AS gs(idx)
),

modeled_candidates AS (
  SELECT DISTINCT ON (
    user_id,
    marketplace,
    sku,
    candidate_price
  )
    user_id,
    seller_connection_id,
    marketplace,
    marketplace_id,
    sku,
    asin,
    currency_code,

    'modeled'::text AS candidate_type,
    candidate_price,

    GREATEST(
      demand_intercept + demand_slope * candidate_price,
      0
    )::numeric AS expected_daily_units,

    (
      candidate_price
      *
      GREATEST(
        demand_intercept + demand_slope * candidate_price,
        0
      )::numeric
    ) AS expected_daily_revenue,

    GREATEST(
      ads_intercept + ads_slope * candidate_price,
      0
    )::numeric AS expected_daily_ads_spend,

    (
      profit_intercept + profit_slope * candidate_price
    )::numeric AS expected_daily_profit,

    modeling_price_points,
    modeled_candidate_count,

    demand_slope,
    demand_intercept,
    profit_slope,
    profit_intercept,
    ads_slope,
    ads_intercept,

    min_modeling_price,
    max_modeling_price,
    price_step,

    NULL::numeric AS source_observed_price

  FROM (
    SELECT
      pg.*,
      ROUND(
        (
          ROUND(pg.raw_candidate_price / pg.price_step)
          * pg.price_step
        )::numeric,
        2
      ) AS candidate_price
    FROM price_grid pg
  ) x
  WHERE candidate_price > 0
)

SELECT * FROM observed_candidates

UNION ALL

SELECT * FROM modeled_candidates;
