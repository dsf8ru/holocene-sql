CREATE MATERIALIZED VIEW analytics.workspace_price_insights_cache_v2 AS

SELECT *

FROM analytics.workspace_price_insights_v2;

CREATE INDEX idx_workspace_price_insights_cache_v2_main

ON analytics.workspace_price_insights_cache_v2 ("userId", marketplace, sku);

CREATE MATERIALIZED VIEW analytics.workspace_summary_cache_v2 AS

SELECT *

FROM analytics.workspace_summary_v2;

CREATE INDEX idx_workspace_summary_cache_v2_main

ON analytics.workspace_summary_cache_v2 (user_id, marketplace, sku);
