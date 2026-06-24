CREATE OR REPLACE VIEW analytics.orders_enriched AS
WITH orders_numbered AS (
  SELECT
    o.id,
    o."userId",
    o.order_date,
    o.marketplace,
    o.sku,
    o.price,
    o.quantity,
    o.currency_code,
    o.imported_at,
    row_number() OVER (
      PARTITION BY
        o."userId",
        o.order_date,
        o.marketplace,
        o.sku
      ORDER BY
        o.price DESC
    ) AS rn
  FROM raw.orders o
),
ads_daily AS (
  SELECT
    ads."userId",
    ads.report_date,
    ads.marketplace,
    ads.sku,
    sum(ads.ads_spend) AS ads_spend,
    sum(ads.clicks) AS clicks,
    sum(ads.impressions) AS impressions,
    sum(ads.ads_units) AS ads_units,
    sum(ads.ads_sales_revenue) AS ads_sales_revenue
  FROM raw.ads ads
  GROUP BY
    ads."userId",
    ads.report_date,
    ads.marketplace,
    ads.sku
)
SELECT
  n."userId",
  n.order_date,
  n.marketplace,
  n.sku,
  n.quantity,
  n.price,
  n.quantity::numeric * n.price AS revenue,

  pc.cogs,
  pc.fba_fee,
  pc.amazon_fee_percent,

  n.quantity::numeric
    * n.price
    * (COALESCE(pc.amazon_fee_percent, 0::numeric) / 100.0)
    AS amazon_fee,

  CASE
    WHEN n.rn = 1 THEN a.ads_spend
    ELSE NULL::numeric
  END AS ads_spend,

  CASE
    WHEN n.rn = 1 THEN a.clicks
    ELSE NULL::bigint
  END AS clicks,

  CASE
    WHEN n.rn = 1 THEN a.impressions
    ELSE NULL::bigint
  END AS impressions,

  n.quantity::numeric * n.price
    - COALESCE(pc.cogs, 0::numeric) * n.quantity::numeric
    - COALESCE(pc.fba_fee, 0::numeric) * n.quantity::numeric
    - n.quantity::numeric
      * n.price
      * (COALESCE(pc.amazon_fee_percent, 0::numeric) / 100.0)
    - COALESCE(
        CASE
          WHEN n.rn = 1 THEN a.ads_spend
          ELSE NULL::numeric
        END,
        0::numeric
      )
    AS row_profit,

  (
    n.quantity::numeric * n.price
      - COALESCE(pc.cogs, 0::numeric) * n.quantity::numeric
      - COALESCE(pc.fba_fee, 0::numeric) * n.quantity::numeric
      - n.quantity::numeric
        * n.price
        * (COALESCE(pc.amazon_fee_percent, 0::numeric) / 100.0)
      - COALESCE(
          CASE
            WHEN n.rn = 1 THEN a.ads_spend
            ELSE NULL::numeric
          END,
          0::numeric
        )
  ) / NULLIF(n.quantity::numeric * n.price, 0::numeric)
    AS row_margin,

  n.currency_code

FROM orders_numbered n

LEFT JOIN ads_daily a
  ON n."userId" = a."userId"
 AND n.order_date = a.report_date
 AND n.marketplace = a.marketplace
 AND n.sku = a.sku

LEFT JOIN app.product_costs pc
  ON n."userId" = pc."userId"
 AND n.sku = pc.sku
 AND n.marketplace = pc.marketplace;
