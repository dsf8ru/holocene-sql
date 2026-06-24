CREATE OR REPLACE VIEW analytics.workspace_day_price_sales_v2 AS
WITH bounds AS (
  SELECT
    b."userId",
    b.marketplace,
    LEAST(MAX(b.order_date), CURRENT_DATE) AS period_end,
    LEAST(MAX(b.order_date), CURRENT_DATE) - INTERVAL '59 days' AS period_start
  FROM analytics.base_order_rows_v2 b
  WHERE b.marketplace IS NOT NULL
  GROUP BY b."userId", b.marketplace
)
SELECT
  b."userId",
  b."sellerConnectionId",
  b.marketplace,
  b."marketplaceId",
  b.sku,
  MAX(b.asin) AS asin,
  b.order_date,
  b.price,
  MAX(b.currency_code) AS currency_code,
  COUNT(*) AS orders,
  SUM(COALESCE(b.quantity, 0)) AS units,
  SUM(COALESCE(b.revenue, 0)) AS revenue,
  SUM(b.profit_before_ads) AS profit_before_ads,
  BOOL_AND(b.has_complete_costs) AS has_complete_costs
FROM analytics.base_order_rows_v2 b
JOIN bounds x
  ON x."userId" = b."userId"
 AND x.marketplace = b.marketplace
WHERE b.order_date >= x.period_start
  AND b.order_date <= x.period_end
  AND b.sku IS NOT NULL
  AND b.price IS NOT NULL
  AND b.price > 0
GROUP BY
  b."userId",
  b."sellerConnectionId",
  b.marketplace,
  b."marketplaceId",
  b.sku,
  b.order_date,
  b.price;
