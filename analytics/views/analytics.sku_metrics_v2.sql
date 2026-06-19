DROP VIEW IF EXISTS analytics.sku_metrics_v2 CASCADE;

CREATE OR REPLACE VIEW analytics.sku_metrics_v2 AS
 WITH bounds AS (
         SELECT base_order_rows_v2."userId",
            base_order_rows_v2.marketplace,
            LEAST(max(base_order_rows_v2.order_date), CURRENT_DATE) AS period_end,
            LEAST(max(base_order_rows_v2.order_date), CURRENT_DATE) - '59 days'::interval AS period_start
           FROM analytics.base_order_rows_v2
          WHERE base_order_rows_v2.marketplace IS NOT NULL
          GROUP BY base_order_rows_v2."userId", base_order_rows_v2.marketplace
        ), period_orders AS (
         SELECT b."userId",
            b."sellerConnectionId",
            b.marketplace,
            b."marketplaceId",
            b.sku,
            b.asin,
            b.order_date,
            b.price,
            b.quantity,
            b.currency_code,
            b.revenue,
            b.cogs,
            b.fba_fee,
            b.amazon_fee_percent,
            b.amazon_fee,
            b.profit_before_ads,
            b.ads_spend_allocated,
            b.profit,
            b.your_price,
            b.has_complete_costs
           FROM analytics.base_order_rows_v2 b
             JOIN bounds x ON x."userId" = b."userId" AND x.marketplace = b.marketplace
          WHERE b.order_date >= x.period_start AND b.order_date <= x.period_end AND b.sku IS NOT NULL AND b.quantity IS NOT NULL
        ), price_point_counts AS (
         SELECT sku_price_points_v2."userId",
            sku_price_points_v2.marketplace,
            sku_price_points_v2.sku,
            count(*) FILTER (WHERE sku_price_points_v2.is_effective_price_point) AS effective_price_points,
            count(*) FILTER (WHERE sku_price_points_v2.is_modeling_price_point) AS modeling_price_points
           FROM analytics.sku_price_points_v2
          GROUP BY sku_price_points_v2."userId", sku_price_points_v2.marketplace, sku_price_points_v2.sku
        ), sku_base AS (
         SELECT p."userId",
            p."sellerConnectionId",
            p.marketplace,
            p."marketplaceId",
            p.sku,
            max(p.asin) AS asin,
            max(p.currency_code) AS currency_code,
            count(*) AS order_lines,
            count(DISTINCT p.order_date) AS days_with_data,
            sum(p.quantity) AS units_sold,
            sum(p.revenue) AS revenue,
            sum(p.profit) AS profit,
            sum(p.quantity)::numeric / 60.0 * 30.0 AS units_per_30_days,
            sum(p.revenue) / NULLIF(sum(p.quantity), 0)::numeric AS avg_unit_price,
            count(DISTINCT p.price) FILTER (WHERE p.price > 0::numeric) AS raw_unique_prices,
            min(p.price) FILTER (WHERE p.price > 0::numeric) AS min_price,
            max(p.price) FILTER (WHERE p.price > 0::numeric) AS max_price,
            bool_or(p.has_complete_costs) AS has_complete_costs
           FROM period_orders p
          GROUP BY p."userId", p."sellerConnectionId", p.marketplace, p."marketplaceId", p.sku
        ), scored AS (
         SELECT b."userId",
            b."sellerConnectionId",
            b.marketplace,
            b."marketplaceId",
            b.sku,
            b.asin,
            b.currency_code,
            b.order_lines,
            b.days_with_data,
            b.units_sold,
            b.revenue,
            b.profit,
            b.units_per_30_days,
            b.avg_unit_price,
            b.raw_unique_prices,
            b.min_price,
            b.max_price,
            b.has_complete_costs,
            COALESCE(pc.effective_price_points, 0::bigint) AS effective_price_points,
            COALESCE(pc.modeling_price_points, 0::bigint) AS modeling_price_points,
            (b.max_price - b.min_price) / NULLIF(b.avg_unit_price, 0::numeric) * 100::numeric AS price_range_pct,
                CASE
                    WHEN COALESCE(pc.effective_price_points, 0::bigint) <= 1 THEN 1
                    WHEN COALESCE(pc.effective_price_points, 0::bigint) = 2 THEN 2
                    WHEN COALESCE(pc.effective_price_points, 0::bigint) = 3 THEN 3
                    WHEN COALESCE(pc.effective_price_points, 0::bigint) = 4 THEN 4
                    ELSE 5
                END AS pricing_activity_score,
                CASE
                    WHEN COALESCE(pc.effective_price_points, 0::bigint) <= 1 THEN 'Very Low'::text
                    WHEN COALESCE(pc.effective_price_points, 0::bigint) = 2 THEN 'Low'::text
                    WHEN COALESCE(pc.effective_price_points, 0::bigint) = 3 THEN 'Medium'::text
                    WHEN COALESCE(pc.effective_price_points, 0::bigint) = 4 THEN 'High'::text
                    ELSE 'Very High'::text
                END AS pricing_activity_label,
                CASE
                    WHEN COALESCE(pc.modeling_price_points, 0::bigint) <= 1 THEN 0
                    WHEN COALESCE(pc.modeling_price_points, 0::bigint) = 2 THEN 40
                    WHEN COALESCE(pc.modeling_price_points, 0::bigint) = 3 THEN 70
                    WHEN COALESCE(pc.modeling_price_points, 0::bigint) = 4 THEN 90
                    ELSE 100
                END AS modeling_points_score,
            LEAST(100::numeric, b.days_with_data::numeric / 60.0 * 100::numeric) AS days_score,
            LEAST(100::numeric, b.units_sold::numeric / 300.0 * 100::numeric) AS volume_score,
                CASE
                    WHEN COALESCE(pc.modeling_price_points, 0::bigint) <= 1 THEN 0
                    WHEN COALESCE(pc.modeling_price_points, 0::bigint) = 2 THEN 40
                    WHEN COALESCE(pc.modeling_price_points, 0::bigint) = 3 THEN 70
                    WHEN COALESCE(pc.modeling_price_points, 0::bigint) = 4 THEN 90
                    ELSE 100
                END::numeric * 0.60 + LEAST(100::numeric, b.days_with_data::numeric / 60.0 * 100::numeric) * 0.20 + LEAST(100::numeric, b.units_sold::numeric / 300.0 * 100::numeric) * 0.20 AS pricing_evidence_score,
                CASE
                    WHEN COALESCE(pc.modeling_price_points, 0::bigint) <= 1 THEN 0.50
                    WHEN COALESCE(pc.modeling_price_points, 0::bigint) = 2 THEN 0.70
                    WHEN COALESCE(pc.modeling_price_points, 0::bigint) = 3 THEN 0.85
                    ELSE 1.00
                END AS benchmark_confidence,
            b.days_with_data >= 30 AND b.units_sold >= 40 AS qualified
           FROM sku_base b
             LEFT JOIN price_point_counts pc ON pc."userId" = b."userId" AND pc.marketplace = b.marketplace AND pc.sku = b.sku
        )
 SELECT "userId",
    "sellerConnectionId",
    marketplace,
    "marketplaceId",
    sku,
    asin,
    currency_code,
    order_lines,
    days_with_data,
    units_sold,
    revenue,
    profit,
    units_per_30_days,
    avg_unit_price,
    raw_unique_prices,
    min_price,
    max_price,
    has_complete_costs,
    effective_price_points,
    modeling_price_points,
    price_range_pct,
    pricing_activity_score,
    pricing_activity_label,
    modeling_points_score,
    days_score,
    volume_score,
    pricing_evidence_score,
    benchmark_confidence,
    qualified,
        CASE
            WHEN pricing_evidence_score < 40::numeric THEN 'Insufficient'::text
            WHEN pricing_evidence_score < 60::numeric THEN 'Low'::text
            WHEN pricing_evidence_score < 80::numeric THEN 'Medium'::text
            ELSE 'High'::text
        END AS pricing_evidence_label
   FROM scored;
;
