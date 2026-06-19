DROP VIEW IF EXISTS analytics.marketplace_metrics_v2 CASCADE;

CREATE OR REPLACE VIEW analytics.marketplace_metrics_v2 AS
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
          WHERE b.order_date >= x.period_start AND b.order_date <= x.period_end AND b.marketplace IS NOT NULL AND b.quantity IS NOT NULL
        )
 SELECT "userId",
    "sellerConnectionId",
    marketplace,
    "marketplaceId",
    max(currency_code) AS currency_code,
    min(order_date) AS period_start_actual,
    max(order_date) AS period_end_actual,
    count(DISTINCT order_date) AS days_with_data,
    sum(quantity) AS units_sold,
    sum(revenue) AS revenue,
    sum(profit) AS profit,
    count(DISTINCT order_date) >= 30 AND sum(quantity) >= 40 AS qualified_marketplace
   FROM period_orders
  GROUP BY "userId", "sellerConnectionId", marketplace, "marketplaceId";
;
