DROP VIEW IF EXISTS analytics.workspace_day_price_sales_v2 CASCADE;

CREATE OR REPLACE VIEW analytics.workspace_day_price_sales_v2 AS
 WITH bounds AS (
         SELECT b_1."userId",
            b_1.marketplace,
            LEAST(max(b_1.order_date), CURRENT_DATE) AS period_end,
            LEAST(max(b_1.order_date), CURRENT_DATE) - '59 days'::interval AS period_start
           FROM analytics.base_order_rows_v2 b_1
          WHERE b_1.marketplace IS NOT NULL
          GROUP BY b_1."userId", b_1.marketplace
        )
 SELECT b."userId",
    b."sellerConnectionId",
    b.marketplace,
    b."marketplaceId",
    b.sku,
    max(b.asin) AS asin,
    b.order_date,
    b.price,
    max(b.currency_code) AS currency_code,
    count(*) AS orders,
    sum(COALESCE(b.quantity, 0)) AS units,
    sum(COALESCE(b.revenue, 0::numeric)) AS revenue,
    sum(b.profit_before_ads) AS profit_before_ads,
    bool_and(b.has_complete_costs) AS has_complete_costs
   FROM analytics.base_order_rows_v2 b
     JOIN bounds x ON x."userId" = b."userId" AND x.marketplace = b.marketplace
  WHERE b.order_date >= x.period_start AND b.order_date <= x.period_end AND b.sku IS NOT NULL AND b.price IS NOT NULL AND b.price > 0::numeric
  GROUP BY b."userId", b."sellerConnectionId", b.marketplace, b."marketplaceId", b.sku, b.order_date, b.price;
;
