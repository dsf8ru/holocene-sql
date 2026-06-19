DROP VIEW IF EXISTS analytics.base_order_rows_v2 CASCADE;

CREATE OR REPLACE VIEW analytics.base_order_rows_v2 AS
 SELECT o."userId",
    o."sellerConnectionId",
    o.marketplace,
    o."marketplaceId",
    o.sku,
    o.asin,
    o.order_date,
    o.price,
    o.quantity,
    o.currency_code,
    o.price * o.quantity::numeric AS revenue,
    pc.cogs,
    pc.fba_fee,
    pc.amazon_fee_percent,
        CASE
            WHEN pc.amazon_fee_percent IS NOT NULL THEN o.price * o.quantity::numeric * pc.amazon_fee_percent / 100::numeric
            ELSE NULL::numeric
        END AS amazon_fee,
        CASE
            WHEN pc.cogs IS NOT NULL AND pc.fba_fee IS NOT NULL AND pc.amazon_fee_percent IS NOT NULL THEN o.price * o.quantity::numeric - pc.cogs * o.quantity::numeric - pc.fba_fee * o.quantity::numeric - o.price * o.quantity::numeric * pc.amazon_fee_percent / 100::numeric
            ELSE NULL::numeric
        END AS profit_before_ads,
    NULL::numeric AS ads_spend_allocated,
        CASE
            WHEN pc.cogs IS NOT NULL AND pc.fba_fee IS NOT NULL AND pc.amazon_fee_percent IS NOT NULL THEN o.price * o.quantity::numeric - pc.cogs * o.quantity::numeric - pc.fba_fee * o.quantity::numeric - o.price * o.quantity::numeric * pc.amazon_fee_percent / 100::numeric
            ELSE NULL::numeric
        END AS profit,
    NULL::numeric AS your_price,
        CASE
            WHEN pc.cogs IS NOT NULL AND pc.fba_fee IS NOT NULL AND pc.amazon_fee_percent IS NOT NULL THEN true
            ELSE false
        END AS has_complete_costs
   FROM raw.orders o
     LEFT JOIN app.product_costs pc ON pc."userId" = o."userId" AND pc.marketplace = o.marketplace AND pc.sku = o.sku
  WHERE o.sku IS NOT NULL AND o.price IS NOT NULL AND o.quantity IS NOT NULL AND COALESCE(o."orderStatus", ''::text) !~~* '%cancel%'::text;
;
