CREATE VIEW analytics.sku_modeled_prices_v2 AS
WITH modeling_points AS (
    SELECT pp.*
    FROM analytics.sku_price_points_v2 pp
    JOIN analytics.sku_metrics_v2 sm
        ON sm."userId" = pp."userId"
       AND sm.marketplace = pp.marketplace
       AND sm.sku = pp.sku
    JOIN analytics.marketplace_metrics_v2 mm
        ON mm."userId" = pp."userId"
       AND mm.marketplace = pp.marketplace
    WHERE sm.qualified = true
      AND mm.qualified_marketplace = true
      AND pp.is_modeling_price_point = true
),
curve AS (
    SELECT
        "userId",
        "sellerConnectionId",
        marketplace,
        "marketplaceId",
        sku,

        MAX(asin) AS asin,
        MAX(currency_code) AS currency_code,

        COUNT(*) AS modeling_price_points,

        CASE
            WHEN COUNT(*) = 2 THEN 5
            WHEN COUNT(*) = 3 THEN 7
            ELSE 9
        END AS modeled_candidate_count,

MIN(price) AS min_modeling_price,

MAX(price) AS max_modeling_price,
(
    ARRAY_AGG(
        price
        ORDER BY avg_daily_revenue_at_price DESC, price DESC
    )
)[1] AS best_observed_price,
(
    ARRAY_AGG(
        avg_daily_revenue_at_price
        ORDER BY avg_daily_revenue_at_price DESC, price DESC
    )
)[1] AS best_observed_daily_revenue,
        GREATEST(
            0.10,
            ((MIN(price) + MAX(price)) / 2.0) * 0.01
        ) AS price_step,

        REGR_SLOPE(
            avg_daily_units_at_price::float8,
            price::float8
        ) AS demand_slope,

        REGR_INTERCEPT(
            avg_daily_units_at_price::float8,
            price::float8
        ) AS demand_intercept

    FROM modeling_points
    GROUP BY
        "userId",
        "sellerConnectionId",
        marketplace,
        "marketplaceId",
        sku
    HAVING COUNT(*) >= 2
),
observed_candidates AS (
    SELECT
        mp."userId",
        mp."sellerConnectionId",
        mp.marketplace,
        mp."marketplaceId",
        mp.sku,
        mp.asin,
        mp.currency_code,

        'observed'::text AS candidate_type,
        mp.price AS candidate_price,

        mp.avg_daily_units_at_price AS expected_daily_units,
        mp.avg_daily_revenue_at_price AS expected_daily_revenue,
        mp.avg_daily_profit_at_price AS expected_daily_profit,

        mp.avg_daily_units_at_price * 60.0 AS expected_units_60d,
        mp.avg_daily_revenue_at_price * 60.0 AS expected_revenue_60d,
        mp.avg_daily_profit_at_price * 60.0 AS expected_profit_60d,

        c.modeling_price_points,
        c.modeled_candidate_count,

        c.demand_slope,
        c.demand_intercept,

        c.min_modeling_price,
        c.max_modeling_price,

        c.price_step,

        mp.price AS source_observed_price

    FROM modeling_points mp
    JOIN curve c
        ON c."userId" = mp."userId"
       AND c.marketplace = mp.marketplace
       AND c.sku = mp.sku
),

price_grid AS (
    SELECT
        c.*,
        gs.idx,

        CASE
            WHEN c.best_observed_price = c.max_modeling_price THEN
                c.max_modeling_price
                +
                (
                    (c.max_modeling_price * 1.10)
                    - c.max_modeling_price
                )
                * gs.idx::numeric
                / (c.modeled_candidate_count + 1)::numeric

            WHEN c.best_observed_price = c.min_modeling_price THEN
                (c.min_modeling_price * 0.90)
                +
                (
                    c.min_modeling_price
                    - (c.min_modeling_price * 0.90)
                )
                * gs.idx::numeric
                / (c.modeled_candidate_count + 1)::numeric

            ELSE
                c.min_modeling_price
                +
                (
                    c.max_modeling_price - c.min_modeling_price
                )
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
        "userId",
        marketplace,
        sku,
        candidate_price
    )
        "userId",
        "sellerConnectionId",
        marketplace,
        "marketplaceId",
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

        NULL::numeric AS expected_daily_profit,

        (
            GREATEST(
                demand_intercept + demand_slope * candidate_price,
                0
            )::numeric
            * 60.0
        ) AS expected_units_60d,

        (
            candidate_price
            *
            GREATEST(
                demand_intercept + demand_slope * candidate_price,
                0
            )::numeric
            * 60.0
        ) AS expected_revenue_60d,

        NULL::numeric AS expected_profit_60d,

        modeling_price_points,
        modeled_candidate_count,

        demand_slope,
        demand_intercept,

        min_modeling_price,
        max_modeling_price,

        price_step,

        NULL::numeric AS source_observed_price

    FROM (
        SELECT
            pg.*,
            ROUND(
                (
                    ROUND(
                        pg.raw_candidate_price
                        / pg.price_step
                    )
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
