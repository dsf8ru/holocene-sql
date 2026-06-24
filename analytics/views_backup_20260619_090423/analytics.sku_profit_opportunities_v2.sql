CREATE OR REPLACE VIEW analytics.sku_profit_opportunities_v2 AS
WITH base AS (
    SELECT
        bp.*,

        pc.cogs,
        pc.fba_fee,
        pc.amazon_fee_percent,

        COALESCE(dp.ads_spend, 0) AS ads_spend_60d,
        COALESCE(dp.units_sold, bp.units_sold) AS actual_units_60d,
        COALESCE(dp.revenue, bp.current_revenue_60d) AS actual_revenue_60d,

        CASE
            WHEN pc.cogs IS NOT NULL
             AND pc.fba_fee IS NOT NULL
             AND pc.amazon_fee_percent IS NOT NULL
            THEN true
            ELSE false
        END AS has_complete_cost_data,

        CASE
            WHEN pc.cogs IS NOT NULL
             AND pc.fba_fee IS NOT NULL
             AND pc.amazon_fee_percent IS NOT NULL
            THEN
                COALESCE(dp.revenue, bp.current_revenue_60d)
                - (COALESCE(dp.units_sold, bp.units_sold) * pc.cogs)
                - (COALESCE(dp.units_sold, bp.units_sold) * pc.fba_fee)
                - (
                    COALESCE(dp.revenue, bp.current_revenue_60d)
                    * pc.amazon_fee_percent
                    / 100.0
                )
                - COALESCE(dp.ads_spend, 0)
            ELSE NULL
        END AS current_profit_after_ads_60d

    FROM analytics.sku_best_prices_v2 bp
    LEFT JOIN app.product_costs pc
        ON pc."userId" = bp."userId"
       AND pc.marketplace = bp.marketplace
       AND pc.sku = bp.sku
    LEFT JOIN analytics.dashboard_profit_by_sku_v2 dp
        ON dp."userId" = bp."userId"
       AND dp.marketplace = bp.marketplace
       AND dp.sku = bp.sku
),
profit_candidates AS (
    SELECT
        b."userId",
        b.marketplace,
        b.sku,

        mp.candidate_type,
        mp.candidate_price,
        mp.expected_units_60d,
        mp.expected_revenue_60d,

        CASE
            WHEN b.has_complete_cost_data = true
            THEN
                mp.expected_revenue_60d
                - (mp.expected_units_60d * b.cogs)
                - (mp.expected_units_60d * b.fba_fee)
                - (mp.expected_revenue_60d * b.amazon_fee_percent / 100.0)
                - b.ads_spend_60d
            ELSE NULL
        END AS expected_profit_60d

    FROM base b
    JOIN analytics.sku_modeled_prices_v2 mp
        ON mp."userId" = b."userId"
       AND mp.marketplace = b.marketplace
       AND mp.sku = b.sku
),
ranked_profit AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY "userId", marketplace, sku
            ORDER BY
                expected_profit_60d DESC NULLS LAST,
                CASE WHEN candidate_type = 'modeled' THEN 0 ELSE 1 END,
                candidate_price ASC
        ) AS profit_rank
    FROM profit_candidates
)
SELECT
    b."userId",
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
        WHEN rp.expected_profit_60d IS NOT NULL
         AND b.current_profit_after_ads_60d IS NOT NULL
        THEN GREATEST(
            rp.expected_profit_60d - b.current_profit_after_ads_60d,
            0
        )

        WHEN b.has_complete_cost_data = true
         AND b.current_profit_after_ads_60d IS NOT NULL
         AND b.current_revenue_60d > 0
         AND b.revenue_opportunity_60d > 0
        THEN GREATEST(
            b.revenue_opportunity_60d
            * GREATEST(b.current_profit_after_ads_60d / b.current_revenue_60d, 0),
            0
        )

        ELSE NULL
    END AS profit_opportunity_60d

FROM base b
LEFT JOIN ranked_profit rp
    ON rp."userId" = b."userId"
   AND rp.marketplace = b.marketplace
   AND rp.sku = b.sku
   AND rp.profit_rank = 1;
