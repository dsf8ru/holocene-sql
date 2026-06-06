CREATE VIEW analytics.sku_price_points_v2 AS
WITH bounds AS (

    SELECT

        "userId",

        marketplace,

        MAX(order_date) AS period_end,

        MAX(order_date) - INTERVAL '59 days' AS period_start

    FROM analytics.base_order_rows_v2

    WHERE marketplace IS NOT NULL

    GROUP BY "userId", marketplace

),

period_orders AS (

    SELECT

        b."userId",

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

    JOIN bounds x

      ON x."userId" = b."userId"

     AND x.marketplace = b.marketplace

    WHERE b.order_date >= x.period_start

      AND b.order_date <= x.period_end

      AND b.sku IS NOT NULL

      AND b.quantity IS NOT NULL

      AND b.price > 0
        ), daily_price AS (
         SELECT period_orders."userId",
            period_orders."sellerConnectionId",
            period_orders.marketplace,
            period_orders."marketplaceId",
            period_orders.sku,
            max(period_orders.asin) AS asin,
            max(period_orders.currency_code) AS currency_code,
            period_orders.price,
            period_orders.order_date,
            sum(period_orders.quantity) AS daily_units,
            sum(period_orders.revenue) AS daily_revenue,
            sum(period_orders.profit) AS daily_profit
           FROM period_orders
          GROUP BY period_orders."userId", period_orders."sellerConnectionId", period_orders.marketplace, period_orders."marketplaceId", period_orders.sku, period_orders.price, period_orders.order_date
        ), sku_totals AS (
         SELECT daily_price."userId",
            daily_price.marketplace,
            daily_price.sku,
            sum(daily_price.daily_units) AS total_units_sold,
            sum(daily_price.daily_revenue) AS total_revenue
           FROM daily_price
          GROUP BY daily_price."userId", daily_price.marketplace, daily_price.sku
        ), price_points AS (
         SELECT dp."userId",
            dp."sellerConnectionId",
            dp.marketplace,
            dp."marketplaceId",
            dp.sku,
            max(dp.asin) AS asin,
            max(dp.currency_code) AS currency_code,
            dp.price,
            count(*) AS days_seen,
            sum(dp.daily_units) AS units_at_price,
            sum(dp.daily_revenue) AS revenue_at_price,
            sum(dp.daily_profit) AS profit_at_price,
            avg(dp.daily_units) AS avg_daily_units_at_price,
            avg(dp.daily_revenue) AS avg_daily_revenue_at_price,
            avg(dp.daily_profit) AS avg_daily_profit_at_price,
            stddev_samp(dp.daily_units) AS stddev_daily_units_at_price,
            sum(dp.daily_units) / NULLIF(t.total_units_sold, 0::numeric) AS units_share,
            sum(dp.daily_revenue) / NULLIF(t.total_revenue, 0::numeric) AS revenue_share,
            sum(dp.daily_revenue) / NULLIF(sum(dp.daily_units), 0::numeric) AS avg_unit_price_at_price
           FROM daily_price dp
             JOIN sku_totals t ON t."userId" = dp."userId" AND t.marketplace = dp.marketplace AND t.sku = dp.sku
          GROUP BY dp."userId", dp."sellerConnectionId", dp.marketplace, dp."marketplaceId", dp.sku, dp.price, t.total_units_sold, t.total_revenue
        ), scored AS (
         SELECT price_points."userId",
            price_points."sellerConnectionId",
            price_points.marketplace,
            price_points."marketplaceId",
            price_points.sku,
            price_points.asin,
            price_points.currency_code,
            price_points.price,
            price_points.days_seen,
            price_points.units_at_price,
            price_points.revenue_at_price,
            price_points.profit_at_price,
            price_points.avg_daily_units_at_price,
            price_points.avg_daily_revenue_at_price,
            price_points.avg_daily_profit_at_price,
            price_points.stddev_daily_units_at_price,
            price_points.units_share,
            price_points.revenue_share,
            price_points.avg_unit_price_at_price,
                CASE
                    WHEN price_points.days_seen < 2 THEN 0::numeric
                    WHEN price_points.avg_daily_units_at_price IS NULL OR price_points.avg_daily_units_at_price = 0::numeric THEN 0::numeric
                    ELSE GREATEST(0::numeric, LEAST(1::numeric, 1::numeric - COALESCE(price_points.stddev_daily_units_at_price, 0::numeric) / NULLIF(price_points.avg_daily_units_at_price, 0::numeric)))
                END AS confidence_per_price
           FROM price_points
        )
 SELECT "userId",
    "sellerConnectionId",
    marketplace,
    "marketplaceId",
    sku,
    asin,
    currency_code,
    price,
    days_seen,
    units_at_price,
    revenue_at_price,
    profit_at_price,
    avg_daily_units_at_price,
    avg_daily_revenue_at_price,
    avg_daily_profit_at_price,
    stddev_daily_units_at_price,
    units_share,
    revenue_share,
    avg_unit_price_at_price,
    confidence_per_price,
    units_at_price > 20::numeric AND confidence_per_price >= 0.5 AS is_effective_price_point,
    units_at_price > 20::numeric AND confidence_per_price >= 0.5 AND units_share >= 0.05 AS is_modeling_price_point
   FROM scored;
