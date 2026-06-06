
# Holocene Analytics Views

Creation order:

1. sku_price_points_v2

2. marketplace_metrics_v2

3. sku_metrics_v2

4. sku_modeled_prices_v2

5. sku_best_prices_v2

6. sku_profit_opportunities_v2

7. dashboard_product_opportunities_v2

Dependency chain:

raw.orders

↓

base_order_rows_v2

↓

marketplace_metrics_v2

↓

sku_metrics_v2

↓

sku_modeled_prices_v2

↓

sku_best_prices_v2

↓

dashboard_summary_v2

↓

dashboard_product_opportunities_v2

Rebuild order:

DROP VIEW analytics.sku_profit_opportunities_v2;

DROP VIEW analytics.sku_best_prices_v2;

DROP VIEW analytics.sku_modeled_prices_v2;

DROP VIEW analytics.sku_metrics_v2;

DROP VIEW analytics.sku_price_points_v2;

Then recreate in the order above.

