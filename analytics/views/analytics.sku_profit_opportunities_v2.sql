DROP VIEW IF EXISTS analytics.sku_profit_opportunities_v2 CASCADE;

CREATE OR REPLACE VIEW analytics.sku_profit_opportunities_v2 AS
 WITH base AS (
         SELECT bp."userId",
            bp."sellerConnectionId",
            bp.marketplace,
            bp."marketplaceId",
            bp.sku,
            bp.asin,
            bp.currency_code,
            bp.days_with_data,
            bp.units_sold,
            bp.current_revenue_60d,
            bp.current_profit_60d,
            bp.raw_unique_prices,
            bp.effective_price_points,
            bp.modeling_price_points,
            bp.pricing_activity_score,
            bp.pricing_activity_label,
            bp.modeling_points_score,
            bp.days_score,
            bp.volume_score,
            bp.pricing_evidence_score,
            bp.pricing_evidence_label,
            bp.benchmark_confidence,
            bp.best_revenue_candidate_type,
            bp.best_revenue_price,
            bp.best_revenue_expected_units_60d,
            bp.best_modeled_revenue_60d,
            bp.demand_slope,
            bp.min_modeling_price,
            bp.max_modeling_price,
            bp.revenue_opportunity_method,
            bp.raw_revenue_opportunity_60d,
            bp.revenue_opportunity_60d,
            bp.revenue_opportunity_status,
            pc.cogs,
            pc.fba_fee,
            pc.amazon_fee_percent,
            COALESCE(dp.ads_spend, 0::numeric) AS ads_spend_60d,
            COALESCE(dp.units_sold, bp.units_sold::numeric) AS actual_units_60d,
            COALESCE(dp.revenue, bp.current_revenue_60d) AS actual_revenue_60d,
                CASE
                    WHEN pc.cogs IS NOT NULL AND pc.fba_fee IS NOT NULL AND pc.amazon_fee_percent IS NOT NULL THEN true
                    ELSE false
                END AS has_complete_cost_data,
                CASE
                    WHEN pc.cogs IS NOT NULL AND pc.fba_fee IS NOT NULL AND pc.amazon_fee_percent IS NOT NULL THEN COALESCE(dp.revenue, bp.current_revenue_60d) - COALESCE(dp.units_sold, bp.units_sold::numeric) * pc.cogs - COALESCE(dp.units_sold, bp.units_sold::numeric) * pc.fba_fee - COALESCE(dp.revenue, bp.current_revenue_60d) * pc.amazon_fee_percent / 100.0 - COALESCE(dp.ads_spend, 0::numeric)
                    ELSE NULL::numeric
                END AS current_profit_after_ads_60d
           FROM analytics.sku_best_prices_v2 bp
             LEFT JOIN app.product_costs pc ON pc."userId" = bp."userId" AND pc.marketplace = bp.marketplace AND pc.sku = bp.sku
             LEFT JOIN analytics.dashboard_profit_by_sku_v2 dp ON dp."userId" = bp."userId" AND dp.marketplace = bp.marketplace AND dp.sku = bp.sku
        ), profit_candidates AS (
         SELECT b_1."userId",
            b_1.marketplace,
            b_1.sku,
            mp.candidate_type,
            mp.candidate_price,
            mp.expected_units_60d,
            mp.expected_revenue_60d,
                CASE
                    WHEN b_1.has_complete_cost_data = true THEN mp.expected_revenue_60d - mp.expected_units_60d * b_1.cogs - mp.expected_units_60d * b_1.fba_fee - mp.expected_revenue_60d * b_1.amazon_fee_percent / 100.0 - b_1.ads_spend_60d
                    ELSE NULL::numeric
                END AS expected_profit_60d
           FROM base b_1
             JOIN analytics.sku_modeled_prices_v2 mp ON mp."userId" = b_1."userId" AND mp.marketplace = b_1.marketplace AND mp.sku = b_1.sku
        ), ranked_profit AS (
         SELECT profit_candidates."userId",
            profit_candidates.marketplace,
            profit_candidates.sku,
            profit_candidates.candidate_type,
            profit_candidates.candidate_price,
            profit_candidates.expected_units_60d,
            profit_candidates.expected_revenue_60d,
            profit_candidates.expected_profit_60d,
            row_number() OVER (PARTITION BY profit_candidates."userId", profit_candidates.marketplace, profit_candidates.sku ORDER BY profit_candidates.expected_profit_60d DESC NULLS LAST, (
                CASE
                    WHEN profit_candidates.candidate_type = 'modeled'::text THEN 0
                    ELSE 1
                END), profit_candidates.candidate_price) AS profit_rank
           FROM profit_candidates
        )
 SELECT b."userId",
    b."sellerConnectionId",
    b.marketplace,
    b."marketplaceId",
    b.sku,
    b.asin,
    b.currency_code,
    b.current_revenue_60d,
    b.current_profit_after_ads_60d AS current_profit_60d,
    b.revenue_opportunity_method,
    b.revenue_opportunity_60d,
    b.best_revenue_candidate_type,
    b.best_revenue_price,
    b.best_revenue_expected_units_60d,
    b.best_modeled_revenue_60d,
    rp.candidate_type AS best_profit_candidate_type,
    rp.candidate_price AS best_profit_price,
    rp.expected_units_60d AS best_profit_expected_units_60d,
    rp.expected_revenue_60d AS best_profit_modeled_revenue_60d,
    rp.expected_profit_60d AS best_modeled_profit_60d,
    b.cogs,
    b.fba_fee,
    b.amazon_fee_percent,
    b.ads_spend_60d,
    b.has_complete_cost_data,
        CASE
            WHEN rp.expected_profit_60d IS NOT NULL AND b.current_profit_after_ads_60d IS NOT NULL THEN GREATEST(rp.expected_profit_60d - b.current_profit_after_ads_60d, 0::numeric)
            WHEN b.has_complete_cost_data = true AND b.current_profit_after_ads_60d IS NOT NULL AND b.current_revenue_60d > 0::numeric AND b.revenue_opportunity_60d > 0::numeric THEN GREATEST(b.revenue_opportunity_60d * GREATEST(b.current_profit_after_ads_60d / b.current_revenue_60d, 0::numeric), 0::numeric)
            ELSE NULL::numeric
        END AS profit_opportunity_60d
   FROM base b
     LEFT JOIN ranked_profit rp ON rp."userId" = b."userId" AND rp.marketplace = b.marketplace AND rp.sku = b.sku AND rp.profit_rank = 1;
;
