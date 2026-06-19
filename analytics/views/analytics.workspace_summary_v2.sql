DROP VIEW IF EXISTS analytics.workspace_summary_v2 CASCADE;

CREATE OR REPLACE VIEW analytics.workspace_summary_v2 AS
 WITH price_insights AS (
         SELECT workspace_price_insights_v2."userId",
            workspace_price_insights_v2."sellerConnectionId",
            workspace_price_insights_v2.marketplace,
            workspace_price_insights_v2."marketplaceId",
            workspace_price_insights_v2.sku,
            workspace_price_insights_v2.asin,
            workspace_price_insights_v2.currency_code,
            workspace_price_insights_v2.price,
            workspace_price_insights_v2.days_seen,
            workspace_price_insights_v2.orders,
            workspace_price_insights_v2.units,
            workspace_price_insights_v2.revenue,
            workspace_price_insights_v2.profit_before_ads,
            workspace_price_insights_v2.ads_spend,
            workspace_price_insights_v2.profit,
            workspace_price_insights_v2.impressions,
            workspace_price_insights_v2.clicks,
            workspace_price_insights_v2.ads_units,
            workspace_price_insights_v2.ads_sales_revenue,
            workspace_price_insights_v2.avg_daily_units,
            workspace_price_insights_v2.avg_daily_revenue,
            workspace_price_insights_v2.avg_daily_profit,
            workspace_price_insights_v2.avg_daily_ads_spend,
            workspace_price_insights_v2.stddev_daily_units,
            workspace_price_insights_v2.confidence_per_price,
            workspace_price_insights_v2.revenue_per_day,
            workspace_price_insights_v2.profit_per_day,
            workspace_price_insights_v2.ads_spend_per_day,
            workspace_price_insights_v2.ads_sales_per_day,
            workspace_price_insights_v2.ctr,
            workspace_price_insights_v2.cpc,
            workspace_price_insights_v2.roas,
            workspace_price_insights_v2.acos,
            workspace_price_insights_v2.tacos,
            workspace_price_insights_v2.orders_per_click,
            workspace_price_insights_v2.confidence_label,
            workspace_price_insights_v2.is_effective_price_point,
            workspace_price_insights_v2.is_modeling_price_point,
            workspace_price_insights_v2.profit_rank,
            workspace_price_insights_v2.revenue_rank,
            workspace_price_insights_v2.modeling_profit_rank,
            workspace_price_insights_v2.modeling_revenue_rank
           FROM analytics.workspace_price_insights_v2
        ), sku_totals AS (
         SELECT pi."userId" AS user_id,
            max(pi."sellerConnectionId") AS seller_connection_id,
            pi.marketplace,
            max(pi."marketplaceId") AS marketplace_id,
            pi.sku,
            max(pi.asin) AS asin,
            max(pi.currency_code) AS currency_code,
            sum(pi.days_seen) AS price_days_seen,
            sum(pi.orders) AS orders,
            sum(pi.units) AS units,
            sum(pi.revenue) AS revenue,
            sum(pi.profit_before_ads) AS profit_before_ads,
            sum(pi.ads_spend) AS ads_spend,
            sum(pi.profit) AS profit,
            sum(pi.impressions) AS impressions,
            sum(pi.clicks) AS clicks,
            sum(pi.ads_units) AS ads_units,
            sum(pi.ads_sales_revenue) AS ads_sales_revenue,
            count(*) AS raw_price_points,
            count(*) FILTER (WHERE pi.is_effective_price_point = true) AS effective_price_points,
            count(*) FILTER (WHERE pi.is_modeling_price_point = true) AS modeling_price_points
           FROM price_insights pi
          GROUP BY pi."userId", pi.marketplace, pi.sku
        ), period_days AS (
         SELECT a."userId" AS user_id,
            a.marketplace,
            a.sku,
            count(DISTINCT a.order_date) AS period_days
           FROM analytics.workspace_day_price_allocated_v2 a
          GROUP BY a."userId", a.marketplace, a.sku
        ), best_revenue AS (
         SELECT DISTINCT ON (workspace_modeled_prices_v2.user_id, workspace_modeled_prices_v2.marketplace, workspace_modeled_prices_v2.sku) workspace_modeled_prices_v2.user_id,
            workspace_modeled_prices_v2.marketplace,
            workspace_modeled_prices_v2.sku,
            workspace_modeled_prices_v2.candidate_price AS best_revenue_price,
            workspace_modeled_prices_v2.expected_daily_revenue AS best_revenue_per_day,
            workspace_modeled_prices_v2.expected_daily_profit AS best_revenue_profit_per_day,
            workspace_modeled_prices_v2.expected_daily_ads_spend AS best_revenue_ads_spend_per_day,
            workspace_modeled_prices_v2.candidate_type AS best_revenue_candidate_type
           FROM analytics.workspace_modeled_prices_v2
          ORDER BY workspace_modeled_prices_v2.user_id, workspace_modeled_prices_v2.marketplace, workspace_modeled_prices_v2.sku, workspace_modeled_prices_v2.expected_daily_revenue DESC NULLS LAST, (
                CASE
                    WHEN workspace_modeled_prices_v2.candidate_type = 'modeled'::text THEN 0
                    ELSE 1
                END), workspace_modeled_prices_v2.candidate_price
        ), best_profit AS (
         SELECT DISTINCT ON (workspace_modeled_prices_v2.user_id, workspace_modeled_prices_v2.marketplace, workspace_modeled_prices_v2.sku) workspace_modeled_prices_v2.user_id,
            workspace_modeled_prices_v2.marketplace,
            workspace_modeled_prices_v2.sku,
            workspace_modeled_prices_v2.candidate_price AS best_profit_price,
            workspace_modeled_prices_v2.expected_daily_profit AS best_profit_per_day,
            workspace_modeled_prices_v2.expected_daily_revenue AS best_profit_revenue_per_day,
            workspace_modeled_prices_v2.expected_daily_ads_spend AS best_profit_ads_spend_per_day,
            workspace_modeled_prices_v2.candidate_type AS best_profit_candidate_type
           FROM analytics.workspace_modeled_prices_v2
          ORDER BY workspace_modeled_prices_v2.user_id, workspace_modeled_prices_v2.marketplace, workspace_modeled_prices_v2.sku, workspace_modeled_prices_v2.expected_daily_profit DESC NULLS LAST, (
                CASE
                    WHEN workspace_modeled_prices_v2.candidate_type = 'modeled'::text THEN 0
                    ELSE 1
                END), workspace_modeled_prices_v2.candidate_price
        ), current_price AS (
         SELECT DISTINCT ON (a."userId", a.marketplace, a.sku) a."userId" AS user_id,
            a.marketplace,
            a.sku,
            a.price AS current_price
           FROM analytics.workspace_day_price_allocated_v2 a
          ORDER BY a."userId", a.marketplace, a.sku, a.order_date DESC, a.price DESC
        )
 SELECT st.user_id,
    st.seller_connection_id,
    st.marketplace,
    st.marketplace_id,
    st.sku,
    st.asin,
    st.currency_code,
    cp.current_price,
    st.orders,
    st.units,
    st.revenue,
    st.profit_before_ads,
    st.ads_spend,
    st.profit,
    st.impressions,
    st.clicks,
    st.ads_units,
    st.ads_sales_revenue,
    st.raw_price_points,
    st.effective_price_points,
    st.modeling_price_points,
    br.best_revenue_price,
    br.best_revenue_per_day,
    br.best_revenue_profit_per_day,
    br.best_revenue_ads_spend_per_day,
    br.best_revenue_candidate_type,
    bp.best_profit_price,
    bp.best_profit_per_day,
    bp.best_profit_revenue_per_day,
    bp.best_profit_ads_spend_per_day,
    bp.best_profit_candidate_type,
    st.revenue / NULLIF(pd.period_days, 0)::numeric AS current_revenue_per_day,
    st.profit / NULLIF(pd.period_days, 0)::numeric AS current_profit_per_day,
    st.ads_spend / NULLIF(pd.period_days, 0)::numeric AS current_ads_spend_per_day,
    GREATEST(COALESCE(br.best_revenue_per_day, 0::numeric) * pd.period_days::numeric - st.revenue, 0::numeric) AS revenue_opportunity,
    GREATEST(COALESCE(bp.best_profit_per_day, 0::numeric) * pd.period_days::numeric - st.profit, 0::numeric) AS profit_opportunity,
    st.ads_spend / NULLIF(st.revenue, 0::numeric) AS tacos,
    st.ads_sales_revenue / NULLIF(st.ads_spend, 0::numeric) AS roas,
    st.ads_spend / NULLIF(st.ads_sales_revenue, 0::numeric) AS acos,
        CASE
            WHEN st.modeling_price_points >= 3 THEN 'Strong'::text
            WHEN st.modeling_price_points = 2 THEN 'Limited'::text
            ELSE 'Insufficient'::text
        END AS workspace_evidence_label,
        CASE
            WHEN st.raw_price_points <= 2 THEN 'Low'::text
            WHEN st.raw_price_points <= 6 THEN 'Medium'::text
            ELSE 'High'::text
        END AS pricing_activity_label
   FROM sku_totals st
     JOIN period_days pd ON pd.user_id = st.user_id AND pd.marketplace = st.marketplace AND pd.sku = st.sku
     LEFT JOIN best_revenue br ON br.user_id = st.user_id AND br.marketplace = st.marketplace AND br.sku = st.sku
     LEFT JOIN best_profit bp ON bp.user_id = st.user_id AND bp.marketplace = st.marketplace AND bp.sku = st.sku
     LEFT JOIN current_price cp ON cp.user_id = st.user_id AND cp.marketplace = st.marketplace AND cp.sku = st.sku;
;
