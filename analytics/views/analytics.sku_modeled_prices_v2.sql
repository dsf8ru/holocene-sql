DROP VIEW IF EXISTS analytics.sku_modeled_prices_v2 CASCADE;

CREATE OR REPLACE VIEW analytics.sku_modeled_prices_v2 AS
 WITH modeling_points AS (
         SELECT pp."userId",
            pp."sellerConnectionId",
            pp.marketplace,
            pp."marketplaceId",
            pp.sku,
            pp.asin,
            pp.currency_code,
            pp.price,
            pp.days_seen,
            pp.units_at_price,
            pp.revenue_at_price,
            pp.profit_at_price,
            pp.avg_daily_units_at_price,
            pp.avg_daily_revenue_at_price,
            pp.avg_daily_profit_at_price,
            pp.stddev_daily_units_at_price,
            pp.units_share,
            pp.revenue_share,
            pp.avg_unit_price_at_price,
            pp.confidence_per_price,
            pp.is_effective_price_point,
            pp.is_modeling_price_point
           FROM analytics.sku_price_points_v2 pp
             JOIN analytics.sku_metrics_v2 sm ON sm."userId" = pp."userId" AND sm.marketplace = pp.marketplace AND sm.sku = pp.sku
             JOIN analytics.marketplace_metrics_v2 mm ON mm."userId" = pp."userId" AND mm.marketplace = pp.marketplace
          WHERE sm.qualified = true AND mm.qualified_marketplace = true AND pp.is_modeling_price_point = true
        ), curve AS (
         SELECT modeling_points."userId",
            modeling_points."sellerConnectionId",
            modeling_points.marketplace,
            modeling_points."marketplaceId",
            modeling_points.sku,
            max(modeling_points.asin) AS asin,
            max(modeling_points.currency_code) AS currency_code,
            count(*) AS modeling_price_points,
                CASE
                    WHEN count(*) = 2 THEN 5
                    WHEN count(*) = 3 THEN 7
                    ELSE 9
                END AS modeled_candidate_count,
            min(modeling_points.price) AS min_modeling_price,
            max(modeling_points.price) AS max_modeling_price,
            (array_agg(modeling_points.price ORDER BY modeling_points.avg_daily_revenue_at_price DESC, modeling_points.price DESC))[1] AS best_observed_price,
            (array_agg(modeling_points.avg_daily_revenue_at_price ORDER BY modeling_points.avg_daily_revenue_at_price DESC, modeling_points.price DESC))[1] AS best_observed_daily_revenue,
            GREATEST(0.10, (min(modeling_points.price) + max(modeling_points.price)) / 2.0 * 0.01) AS price_step,
            regr_slope(modeling_points.avg_daily_units_at_price::double precision, modeling_points.price::double precision) AS demand_slope,
            regr_intercept(modeling_points.avg_daily_units_at_price::double precision, modeling_points.price::double precision) AS demand_intercept
           FROM modeling_points
          GROUP BY modeling_points."userId", modeling_points."sellerConnectionId", modeling_points.marketplace, modeling_points."marketplaceId", modeling_points.sku
         HAVING count(*) >= 2
        ), observed_candidates AS (
         SELECT mp."userId",
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
             JOIN curve c ON c."userId" = mp."userId" AND c.marketplace = mp.marketplace AND c.sku = mp.sku
        ), price_grid AS (
         SELECT c."userId",
            c."sellerConnectionId",
            c.marketplace,
            c."marketplaceId",
            c.sku,
            c.asin,
            c.currency_code,
            c.modeling_price_points,
            c.modeled_candidate_count,
            c.min_modeling_price,
            c.max_modeling_price,
            c.best_observed_price,
            c.best_observed_daily_revenue,
            c.price_step,
            c.demand_slope,
            c.demand_intercept,
            gs.idx,
                CASE
                    WHEN c.best_observed_price = c.max_modeling_price THEN c.max_modeling_price + (c.max_modeling_price * 1.10 - c.max_modeling_price) * gs.idx::numeric / (c.modeled_candidate_count + 1)::numeric
                    WHEN c.best_observed_price = c.min_modeling_price THEN c.min_modeling_price * 0.90 + (c.min_modeling_price - c.min_modeling_price * 0.90) * gs.idx::numeric / (c.modeled_candidate_count + 1)::numeric
                    ELSE c.min_modeling_price + (c.max_modeling_price - c.min_modeling_price) * gs.idx::numeric / (c.modeled_candidate_count + 1)::numeric
                END AS raw_candidate_price
           FROM curve c
             CROSS JOIN LATERAL generate_series(1, c.modeled_candidate_count) gs(idx)
        ), modeled_candidates AS (
         SELECT DISTINCT ON (x."userId", x.marketplace, x.sku, x.candidate_price) x."userId",
            x."sellerConnectionId",
            x.marketplace,
            x."marketplaceId",
            x.sku,
            x.asin,
            x.currency_code,
            'modeled'::text AS candidate_type,
            x.candidate_price,
            GREATEST(x.demand_intercept + x.demand_slope * x.candidate_price::double precision, 0::double precision)::numeric AS expected_daily_units,
            x.candidate_price * GREATEST(x.demand_intercept + x.demand_slope * x.candidate_price::double precision, 0::double precision)::numeric AS expected_daily_revenue,
            NULL::numeric AS expected_daily_profit,
            GREATEST(x.demand_intercept + x.demand_slope * x.candidate_price::double precision, 0::double precision)::numeric * 60.0 AS expected_units_60d,
            x.candidate_price * GREATEST(x.demand_intercept + x.demand_slope * x.candidate_price::double precision, 0::double precision)::numeric * 60.0 AS expected_revenue_60d,
            NULL::numeric AS expected_profit_60d,
            x.modeling_price_points,
            x.modeled_candidate_count,
            x.demand_slope,
            x.demand_intercept,
            x.min_modeling_price,
            x.max_modeling_price,
            x.price_step,
            NULL::numeric AS source_observed_price
           FROM ( SELECT pg."userId",
                    pg."sellerConnectionId",
                    pg.marketplace,
                    pg."marketplaceId",
                    pg.sku,
                    pg.asin,
                    pg.currency_code,
                    pg.modeling_price_points,
                    pg.modeled_candidate_count,
                    pg.min_modeling_price,
                    pg.max_modeling_price,
                    pg.best_observed_price,
                    pg.best_observed_daily_revenue,
                    pg.price_step,
                    pg.demand_slope,
                    pg.demand_intercept,
                    pg.idx,
                    pg.raw_candidate_price,
                    round(round(pg.raw_candidate_price / pg.price_step) * pg.price_step, 2) AS candidate_price
                   FROM price_grid pg) x
          WHERE x.candidate_price > 0::numeric
        )
 SELECT observed_candidates."userId",
    observed_candidates."sellerConnectionId",
    observed_candidates.marketplace,
    observed_candidates."marketplaceId",
    observed_candidates.sku,
    observed_candidates.asin,
    observed_candidates.currency_code,
    observed_candidates.candidate_type,
    observed_candidates.candidate_price,
    observed_candidates.expected_daily_units,
    observed_candidates.expected_daily_revenue,
    observed_candidates.expected_daily_profit,
    observed_candidates.expected_units_60d,
    observed_candidates.expected_revenue_60d,
    observed_candidates.expected_profit_60d,
    observed_candidates.modeling_price_points,
    observed_candidates.modeled_candidate_count,
    observed_candidates.demand_slope,
    observed_candidates.demand_intercept,
    observed_candidates.min_modeling_price,
    observed_candidates.max_modeling_price,
    observed_candidates.price_step,
    observed_candidates.source_observed_price
   FROM observed_candidates
UNION ALL
 SELECT modeled_candidates."userId",
    modeled_candidates."sellerConnectionId",
    modeled_candidates.marketplace,
    modeled_candidates."marketplaceId",
    modeled_candidates.sku,
    modeled_candidates.asin,
    modeled_candidates.currency_code,
    modeled_candidates.candidate_type,
    modeled_candidates.candidate_price,
    modeled_candidates.expected_daily_units,
    modeled_candidates.expected_daily_revenue,
    modeled_candidates.expected_daily_profit,
    modeled_candidates.expected_units_60d,
    modeled_candidates.expected_revenue_60d,
    modeled_candidates.expected_profit_60d,
    modeled_candidates.modeling_price_points,
    modeled_candidates.modeled_candidate_count,
    modeled_candidates.demand_slope,
    modeled_candidates.demand_intercept,
    modeled_candidates.min_modeling_price,
    modeled_candidates.max_modeling_price,
    modeled_candidates.price_step,
    modeled_candidates.source_observed_price
   FROM modeled_candidates;
;
