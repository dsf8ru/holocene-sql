CREATE TABLE IF NOT EXISTS app.optimization_plans (
  id TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  default_goal TEXT NOT NULL,
  min_price_delta_percent NUMERIC(10,2) NOT NULL DEFAULT 10,
  max_price_delta_percent NUMERIC(10,2) NOT NULL DEFAULT 15,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.optimization_plan_items (
  id TEXT PRIMARY KEY,
  plan_id TEXT NOT NULL REFERENCES app.optimization_plans(id) ON DELETE CASCADE,
  "userId" TEXT NOT NULL,
  marketplace TEXT NOT NULL,
  sku TEXT NOT NULL,
  asin TEXT,
  currency_code TEXT,
  goal TEXT NOT NULL,
  min_price_delta_percent NUMERIC(10,2) NOT NULL,
  max_price_delta_percent NUMERIC(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS optimization_plans_user_status_idx
ON app.optimization_plans ("userId", status);

CREATE INDEX IF NOT EXISTS optimization_plan_items_plan_idx
ON app.optimization_plan_items (plan_id);

CREATE INDEX IF NOT EXISTS optimization_plan_items_user_marketplace_sku_idx
ON app.optimization_plan_items ("userId", marketplace, sku);

CREATE UNIQUE INDEX IF NOT EXISTS optimization_plan_items_unique_active_idx
ON app.optimization_plan_items ("userId", marketplace, sku)
WHERE status = 'active';

CREATE UNIQUE INDEX IF NOT EXISTS optimization_plans_one_active_per_user_idx
ON app.optimization_plans ("userId")
WHERE status = 'active';
