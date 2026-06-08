DROP TABLE IF EXISTS analytics.dashboard_summary_cache;

CREATE TABLE analytics.dashboard_summary_cache AS
SELECT *
FROM analytics.dashboard_summary_v2;

CREATE INDEX idx_dashboard_summary_cache_user_marketplace
ON analytics.dashboard_summary_cache ("userId", marketplace);
