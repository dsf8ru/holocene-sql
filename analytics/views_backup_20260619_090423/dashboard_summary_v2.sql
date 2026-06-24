CREATE OR REPLACE VIEW analytics.dashboard_summary_v2 AS
SELECT
    bp."userId",
    bp."sellerConnectionId",
    bp.marketplace,
    bp."marketplaceId",
    MAX(bp.currency_code) AS currency_code,

    COUNT(*) AS qualified_skus,

    SUM(bp.current_revenue_60d) AS qualified_revenue_60d,

    SUM(
        COALESCE(pp.current_profit_60d, 0)
    ) AS qualified_profit_60d,

    ROUND(
        AVG(bp.pricing_activity_score)::numeric,
        2
    ) AS avg_pricing_activity_score,

    ROUND(
        AVG(bp.pricing_evidence_score)::numeric,
        2
    ) AS avg_pricing_evidence_score,

    COUNT(*) FILTER (
        WHERE bp.pricing_activity_label = 'Very Low'
    ) AS very_low_activity_skus,

    COUNT(*) FILTER (
        WHERE bp.pricing_activity_label = 'Low'
    ) AS low_activity_skus,

    COUNT(*) FILTER (
        WHERE bp.pricing_activity_label = 'Medium'
    ) AS medium_activity_skus,

    COUNT(*) FILTER (
        WHERE bp.pricing_activity_label = 'High'
    ) AS high_activity_skus,

    COUNT(*) FILTER (
        WHERE bp.pricing_evidence_label = 'Insufficient'
    ) AS insufficient_evidence_skus,

    COUNT(*) FILTER (
        WHERE bp.pricing_evidence_label = 'Low'
    ) AS low_evidence_skus,

    COUNT(*) FILTER (
        WHERE bp.pricing_evidence_label = 'Medium'
    ) AS medium_evidence_skus,

    COUNT(*) FILTER (
        WHERE bp.pricing_evidence_label = 'High'
    ) AS high_evidence_skus,

    SUM(bp.revenue_opportunity_60d)
        AS revenue_opportunity_60d,

    SUM(
        COALESCE(pp.profit_opportunity_60d, 0)
    ) AS profit_opportunity_60d,

    COUNT(*) FILTER (
        WHERE bp.revenue_opportunity_60d > 0
    ) AS opportunity_skus,

    COUNT(*) FILTER (
        WHERE bp.revenue_opportunity_method = 'model_based'
    ) AS model_based_skus,

    COUNT(*) FILTER (
        WHERE bp.revenue_opportunity_method = 'benchmark_25pct'
    ) AS benchmark_skus,

    COUNT(*) FILTER (
        WHERE pp.has_complete_cost_data = true
    ) AS products_with_costs,

    COUNT(*) FILTER (
        WHERE pp.has_complete_cost_data = false
           OR pp.has_complete_cost_data IS NULL
    ) AS products_missing_costs

FROM analytics.sku_best_prices_v2 bp
LEFT JOIN analytics.sku_profit_opportunities_v2 pp
    ON pp."userId" = bp."userId"
   AND pp.marketplace = bp.marketplace
   AND pp.sku = bp.sku

GROUP BY
    bp."userId",
    bp."sellerConnectionId",
    bp.marketplace,
    bp."marketplaceId";
