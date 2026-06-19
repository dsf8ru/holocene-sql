DROP VIEW IF EXISTS analytics.dashboard_summary_v2 CASCADE;

CREATE OR REPLACE VIEW analytics.dashboard_summary_v2 AS
 SELECT bp."userId",
    bp."sellerConnectionId",
    bp.marketplace,
    bp."marketplaceId",
    max(bp.currency_code) AS currency_code,
    count(*) AS qualified_skus,
    sum(bp.current_revenue_60d) AS qualified_revenue_60d,
    sum(COALESCE(pp.current_profit_60d, 0::numeric)) AS qualified_profit_60d,
    round(avg(bp.pricing_activity_score), 2) AS avg_pricing_activity_score,
    round(avg(bp.pricing_evidence_score), 2) AS avg_pricing_evidence_score,
    count(*) FILTER (WHERE bp.pricing_activity_label = 'Very Low'::text) AS very_low_activity_skus,
    count(*) FILTER (WHERE bp.pricing_activity_label = 'Low'::text) AS low_activity_skus,
    count(*) FILTER (WHERE bp.pricing_activity_label = 'Medium'::text) AS medium_activity_skus,
    count(*) FILTER (WHERE bp.pricing_activity_label = 'High'::text) AS high_activity_skus,
    count(*) FILTER (WHERE bp.pricing_evidence_label = 'Insufficient'::text) AS insufficient_evidence_skus,
    count(*) FILTER (WHERE bp.pricing_evidence_label = 'Low'::text) AS low_evidence_skus,
    count(*) FILTER (WHERE bp.pricing_evidence_label = 'Medium'::text) AS medium_evidence_skus,
    count(*) FILTER (WHERE bp.pricing_evidence_label = 'High'::text) AS high_evidence_skus,
    sum(bp.revenue_opportunity_60d) AS revenue_opportunity_60d,
    sum(COALESCE(pp.profit_opportunity_60d, 0::numeric)) AS profit_opportunity_60d,
    count(*) FILTER (WHERE bp.revenue_opportunity_60d > 0::numeric) AS opportunity_skus,
    count(*) FILTER (WHERE bp.revenue_opportunity_method = 'model_based'::text) AS model_based_skus,
    count(*) FILTER (WHERE bp.revenue_opportunity_method = 'benchmark_25pct'::text) AS benchmark_skus,
    count(*) FILTER (WHERE pp.has_complete_cost_data = true) AS products_with_costs,
    count(*) FILTER (WHERE pp.has_complete_cost_data = false OR pp.has_complete_cost_data IS NULL) AS products_missing_costs
   FROM analytics.sku_best_prices_v2 bp
     LEFT JOIN analytics.sku_profit_opportunities_v2 pp ON pp."userId" = bp."userId" AND pp.marketplace = bp.marketplace AND pp.sku = bp.sku
  GROUP BY bp."userId", bp."sellerConnectionId", bp.marketplace, bp."marketplaceId";
;
