DROP VIEW IF EXISTS analytics.sku_best_prices_v2 CASCADE;

CREATE OR REPLACE VIEW analytics.sku_best_prices_v2 AS
 WITH ranked_candidates AS (
         SELECT mp."userId",
            mp."sellerConnectionId",
            mp.marketplace,
            mp."marketplaceId",
            mp.sku,
            mp.asin,
            mp.currency_code,
            mp.candidate_type,
            mp.candidate_price,
            mp.expected_daily_units,
            mp.expected_daily_revenue,
            mp.expected_daily_profit,
            mp.expected_units_60d,
            mp.expected_revenue_60d,
            mp.expected_profit_60d,
            mp.modeling_price_points,
            mp.modeled_candidate_count,
            mp.demand_slope,
            mp.demand_intercept,
            mp.min_modeling_price,
            mp.max_modeling_price,
            mp.price_step,
            mp.source_observed_price,
            row_number() OVER (PARTITION BY mp."userId", mp.marketplace, mp.sku ORDER BY mp.expected_revenue_60d DESC, (
                CASE
                    WHEN mp.candidate_type = 'modeled'::text THEN 0
                    ELSE 1
                END), mp.candidate_price) AS revenue_rank
           FROM analytics.sku_modeled_prices_v2 mp
        ), best_revenue AS (
         SELECT ranked_candidates."userId",
            ranked_candidates."sellerConnectionId",
            ranked_candidates.marketplace,
            ranked_candidates."marketplaceId",
            ranked_candidates.sku,
            ranked_candidates.asin,
            ranked_candidates.currency_code,
            ranked_candidates.candidate_type,
            ranked_candidates.candidate_price,
            ranked_candidates.expected_daily_units,
            ranked_candidates.expected_daily_revenue,
            ranked_candidates.expected_daily_profit,
            ranked_candidates.expected_units_60d,
            ranked_candidates.expected_revenue_60d,
            ranked_candidates.expected_profit_60d,
            ranked_candidates.modeling_price_points,
            ranked_candidates.modeled_candidate_count,
            ranked_candidates.demand_slope,
            ranked_candidates.demand_intercept,
            ranked_candidates.min_modeling_price,
            ranked_candidates.max_modeling_price,
            ranked_candidates.price_step,
            ranked_candidates.source_observed_price,
            ranked_candidates.revenue_rank
           FROM ranked_candidates
          WHERE ranked_candidates.revenue_rank = 1
        )
 SELECT sm."userId",
    sm."sellerConnectionId",
    sm.marketplace,
    sm."marketplaceId",
    sm.sku,
    sm.asin,
    sm.currency_code,
    sm.days_with_data,
    sm.units_sold,
    sm.revenue AS current_revenue_60d,
    sm.profit AS current_profit_60d,
    sm.raw_unique_prices,
    sm.effective_price_points,
    sm.modeling_price_points,
    sm.pricing_activity_score,
    sm.pricing_activity_label,
    sm.modeling_points_score,
    sm.days_score,
    sm.volume_score,
    sm.pricing_evidence_score,
    sm.pricing_evidence_label,
    sm.benchmark_confidence,
    br.candidate_type AS best_revenue_candidate_type,
    br.candidate_price AS best_revenue_price,
    br.expected_units_60d AS best_revenue_expected_units_60d,
    br.expected_revenue_60d AS best_modeled_revenue_60d,
    br.demand_slope,
    br.min_modeling_price,
    br.max_modeling_price,
        CASE
            WHEN br.candidate_price IS NOT NULL THEN 'model_based'::text
            ELSE 'benchmark_25pct'::text
        END AS revenue_opportunity_method,
        CASE
            WHEN br.candidate_price IS NOT NULL THEN GREATEST(br.expected_revenue_60d - sm.revenue, 0::numeric)
            ELSE sm.revenue * 0.25
        END AS raw_revenue_opportunity_60d,
        CASE
            WHEN br.candidate_price IS NOT NULL THEN GREATEST(br.expected_revenue_60d - sm.revenue, 0::numeric)
            ELSE sm.revenue * 0.25 * sm.benchmark_confidence
        END AS revenue_opportunity_60d,
        CASE
            WHEN br.candidate_price IS NOT NULL THEN 'model_based'::text
            ELSE 'benchmark_estimate'::text
        END AS revenue_opportunity_status
   FROM analytics.sku_metrics_v2 sm
     JOIN analytics.marketplace_metrics_v2 mm ON mm."userId" = sm."userId" AND mm.marketplace = sm.marketplace
     LEFT JOIN best_revenue br ON br."userId" = sm."userId" AND br.marketplace = sm.marketplace AND br.sku = sm.sku
  WHERE sm.qualified = true AND mm.qualified_marketplace = true;
;
