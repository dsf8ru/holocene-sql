CREATE VIEW analytics.sku_metrics_v2 AS
WITH bounds AS (
    SELECT
        MAX(order_date) AS period_end,
        MAX(order_date) - INTERVAL '59 days' AS period_start
    FROM analytics.base_order_rows_v2
),
period_orders AS (
    SELECT b.*
    FROM analytics.base_order_rows_v2 b
    CROSS JOIN bounds x
    WHERE b.order_date >= x.period_start
      AND b.order_date <= x.period_end
      AND b.sku IS NOT NULL
      AND b.quantity IS NOT NULL
),
price_point_counts AS (
    SELECT
        "userId",
        marketplace,
        sku,
        COUNT(*) FILTER (WHERE is_effective_price_point) AS effective_price_points,
        COUNT(*) FILTER (WHERE is_modeling_price_point) AS modeling_price_points
    FROM analytics.sku_price_points_v2
    GROUP BY "userId", marketplace, sku
),
sku_base AS (
    SELECT
        p."userId",
        p."sellerConnectionId",
        p.marketplace,
        p."marketplaceId",
        p.sku,
        MAX(p.asin) AS asin,
        MAX(p.currency_code) AS currency_code,

        COUNT(*) AS order_lines,
        COUNT(DISTINCT p.order_date) AS days_with_data,
        SUM(p.quantity) AS units_sold,
        SUM(p.revenue) AS revenue,
        SUM(p.profit) AS profit,

        SUM(p.quantity)::numeric / 60.0 * 30.0 AS units_per_30_days,
        SUM(p.revenue) / NULLIF(SUM(p.quantity), 0) AS avg_unit_price,

        COUNT(DISTINCT p.price) FILTER (WHERE p.price > 0) AS raw_unique_prices,
        MIN(p.price) FILTER (WHERE p.price > 0) AS min_price,
        MAX(p.price) FILTER (WHERE p.price > 0) AS max_price,

        BOOL_OR(p.has_complete_costs) AS has_complete_costs
    FROM period_orders p
    GROUP BY
        p."userId",
        p."sellerConnectionId",
        p.marketplace,
        p."marketplaceId",
        p.sku
),
scored AS (
    SELECT
        b.*,

        COALESCE(pc.effective_price_points, 0) AS effective_price_points,
        COALESCE(pc.modeling_price_points, 0) AS modeling_price_points,

        (b.max_price - b.min_price)
            / NULLIF(b.avg_unit_price, 0)
            * 100 AS price_range_pct,

        CASE
            WHEN COALESCE(pc.effective_price_points, 0) <= 1 THEN 1
            WHEN COALESCE(pc.effective_price_points, 0) = 2 THEN 2
            WHEN COALESCE(pc.effective_price_points, 0) = 3 THEN 3
            WHEN COALESCE(pc.effective_price_points, 0) = 4 THEN 4
            ELSE 5
        END AS pricing_activity_score,

        CASE
            WHEN COALESCE(pc.effective_price_points, 0) <= 1 THEN 'Very Low'
            WHEN COALESCE(pc.effective_price_points, 0) = 2 THEN 'Low'
            WHEN COALESCE(pc.effective_price_points, 0) = 3 THEN 'Medium'
            WHEN COALESCE(pc.effective_price_points, 0) = 4 THEN 'High'
            ELSE 'Very High'
        END AS pricing_activity_label,

        CASE
            WHEN COALESCE(pc.modeling_price_points, 0) <= 1 THEN 0
            WHEN COALESCE(pc.modeling_price_points, 0) = 2 THEN 40
            WHEN COALESCE(pc.modeling_price_points, 0) = 3 THEN 70
            WHEN COALESCE(pc.modeling_price_points, 0) = 4 THEN 90
            ELSE 100
        END AS modeling_points_score,

        LEAST(100, b.days_with_data::numeric / 60.0 * 100) AS days_score,
        LEAST(100, b.units_sold::numeric / 300.0 * 100) AS volume_score,

        (
            CASE
                WHEN COALESCE(pc.modeling_price_points, 0) <= 1 THEN 0
                WHEN COALESCE(pc.modeling_price_points, 0) = 2 THEN 40
                WHEN COALESCE(pc.modeling_price_points, 0) = 3 THEN 70
                WHEN COALESCE(pc.modeling_price_points, 0) = 4 THEN 90
                ELSE 100
            END * 0.60
            +
            LEAST(100, b.days_with_data::numeric / 60.0 * 100) * 0.20
            +
            LEAST(100, b.units_sold::numeric / 300.0 * 100) * 0.20
        ) AS pricing_evidence_score,

        CASE
            WHEN COALESCE(pc.modeling_price_points, 0) <= 1 THEN 0.40
            WHEN COALESCE(pc.modeling_price_points, 0) = 2 THEN 0.60
            WHEN COALESCE(pc.modeling_price_points, 0) = 3 THEN 0.80
            ELSE 1.00
        END AS benchmark_confidence,

        (
            b.days_with_data >= 30
            AND b.units_sold >= 40
        ) AS qualified

    FROM sku_base b
    LEFT JOIN price_point_counts pc
        ON pc."userId" = b."userId"
       AND pc.marketplace = b.marketplace
       AND pc.sku = b.sku
)
SELECT
    *,

    CASE
        WHEN pricing_evidence_score < 40 THEN 'Insufficient'
        WHEN pricing_evidence_score < 60 THEN 'Low'
        WHEN pricing_evidence_score < 80 THEN 'Medium'
        ELSE 'High'
    END AS pricing_evidence_label

FROM scored;

