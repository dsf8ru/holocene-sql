CREATE TABLE IF NOT EXISTS app.optimization_recommendations (
  id bigserial PRIMARY KEY,

  plan_item_id text REFERENCES app.optimization_plan_items(id) ON DELETE CASCADE,

  userId text NOT NULL,
  marketplace text NOT NULL,
  sku text NOT NULL,
  asin text,
  currency_code text,

  goal text NOT NULL,
  algorithm_mode text NOT NULL,
  status text NOT NULL DEFAULT 'new',

  current_price numeric(10,2),
  recommended_price numeric(10,2),

  min_allowed_price numeric(10,2),
  max_allowed_price numeric(10,2),

  pricing_evidence_score numeric,
  pricing_evidence_label text,
  modeling_price_points integer,
  effective_price_points integer,

  expected_revenue_60d numeric,
  expected_profit_60d numeric,
  expected_revenue_uplift numeric,
  expected_profit_uplift numeric,

  reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS optimization_recommendations_user_sku_idx
ON app.optimization_recommendations (userId, marketplace, sku, created_at DESC);

CREATE INDEX IF NOT EXISTS optimization_recommendations_status_idx
ON app.optimization_recommendations (status);
