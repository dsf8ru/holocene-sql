CREATE VIEW analytics.dashboard_product_opportunities_v2 AS
SELECT
    bp."userId",
    bp."sellerConnectionId",

    bp.marketplace,
    bp."marketplaceId",

    bp.sku,
    bp.asin,
    bp.currency_code,

    bp.current_revenue_60d,
    bp.revenue_opportunity_60d,

    pp.current_profit_60d,
    pp.profit_opportunity_60d,

    pp.has_complete_cost_data,

    bp.pricing_activity_label,

    bp.pricing_evidence_score,
    bp.pricing_evidence_label

FROM analytics.sku_best_prices_v2 bp

LEFT JOIN analytics.sku_profit_opportunities_v2 pp
    ON pp."userId" = bp."userId"
   AND pp.marketplace = bp.marketplace
   AND pp.sku = bp.sku;
