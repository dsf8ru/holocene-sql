docker exec -i postgres psql -U holocene -d holocene <<'SQL'
DROP TABLE IF EXISTS analytics.dashboard_product_opportunities_cache;

CREATE TABLE analytics.dashboard_product_opportunities_cache AS
SELECT *
FROM analytics.dashboard_product_opportunities_v2;

CREATE INDEX idx_dashboard_product_opportunities_cache_user_marketplace_sku
ON analytics.dashboard_product_opportunities_cache ("userId", marketplace, sku);
SQL
