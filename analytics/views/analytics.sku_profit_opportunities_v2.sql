CREATE VIEW analytics.sku_profit_opportunities_v2 AS

WITH profit_candidates AS (

    SELECT

        bp."userId",

        bp."sellerConnectionId",

        bp.marketplace,

        bp."marketplaceId",

        bp.sku,

        bp.asin,

        bp.currency_code,

        bp.current_revenue_60d,

        bp.current_profit_60d,

        bp.best_revenue_price,

        bp.best_revenue_expected_units_60d,

        bp.best_modeled_revenue_60d,

        mp.candidate_type,

        mp.candidate_price,

        mp.expected_units_60d,

        mp.expected_revenue_60d,

        pc.cogs,

        pc.fba_fee,

        pc.amazon_fee_percent,

        CASE

            WHEN pc.cogs IS NOT NULL

             AND pc.fba_fee IS NOT NULL

             AND pc.amazon_fee_percent IS NOT NULL

             AND mp.candidate_price IS NOT NULL

             AND mp.expected_units_60d IS NOT NULL

            THEN

                (

                    mp.candidate_price

                    - pc.cogs

                    - pc.fba_fee

                    - (mp.candidate_price * pc.amazon_fee_percent / 100.0)

                )

                * mp.expected_units_60d

            ELSE NULL

        END AS expected_profit_60d

    FROM analytics.sku_best_prices_v2 bp

    JOIN analytics.sku_modeled_prices_v2 mp

        ON mp."userId" = bp."userId"

       AND mp.marketplace = bp.marketplace

       AND mp.sku = bp.sku

    LEFT JOIN app.product_costs pc

        ON pc."userId" = bp."userId"

       AND pc.marketplace = bp.marketplace

       AND pc.sku = bp.sku

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

    bp."userId",

    bp."sellerConnectionId",

    bp.marketplace,

    bp."marketplaceId",

    bp.sku,

    bp.asin,

    bp.currency_code,

    bp.current_revenue_60d,

    bp.current_profit_60d,

    bp.revenue_opportunity_method,

    bp.current_revenue_60d,

    bp.revenue_opportunity_60d,

    bp.best_revenue_candidate_type,

    bp.best_revenue_price,

    bp.best_revenue_expected_units_60d,

    bp.best_modeled_revenue_60d,

    rp.candidate_type AS best_profit_candidate_type,

    rp.candidate_price AS best_profit_price,

    rp.expected_units_60d AS best_profit_expected_units_60d,

    rp.expected_revenue_60d AS best_profit_modeled_revenue_60d,

    rp.expected_profit_60d AS best_modeled_profit_60d,

    rp.cogs,

    rp.fba_fee,

    rp.amazon_fee_percent,

    CASE

        WHEN rp.cogs IS NOT NULL

         AND rp.fba_fee IS NOT NULL

         AND rp.amazon_fee_percent IS NOT NULL

        THEN true

        ELSE false

    END AS has_complete_cost_data,

    CASE

        WHEN rp.expected_profit_60d IS NOT NULL

         AND bp.current_profit_60d IS NOT NULL

        THEN GREATEST(

            rp.expected_profit_60d - bp.current_profit_60d,

            0

        )

        ELSE NULL

    END AS profit_opportunity_60d

FROM analytics.sku_best_prices_v2 bp

LEFT JOIN ranked_profit rp

    ON rp."userId" = bp."userId"

   AND rp.marketplace = bp.marketplace

   AND rp.sku = bp.sku

   AND rp.profit_rank = 1;
