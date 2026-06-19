CREATE TABLE IF NOT EXISTS app.optimization_price_points (
  id bigserial PRIMARY KEY,

  "userId" text NOT NULL,
  marketplace text NOT NULL,
  sku text NOT NULL,
  asin text,
  currency_code text,

  price numeric(10,2) NOT NULL,

  units_60d integer NOT NULL DEFAULT 0,
  orders_60d integer NOT NULL DEFAULT 0,
  revenue_60d numeric NOT NULL DEFAULT 0,
  profit_60d numeric,
  active_days integer NOT NULL DEFAULT 0,

  units_share numeric,
  avg_units_per_day numeric,
  avg_revenue_per_day numeric,
  avg_profit_per_day numeric,

  demand_confidence numeric NOT NULL DEFAULT 0,
  is_effective boolean NOT NULL DEFAULT false,
  is_modeling_point boolean NOT NULL DEFAULT false,

  calculated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS optimization_price_points_user_sku_idx
ON app.optimization_price_points ("userId", marketplace, sku, calculated_at DESC);


CREATE TABLE IF NOT EXISTS app.optimization_recommendations (
  id bigserial PRIMARY KEY,

  plan_item_id text REFERENCES app.optimization_plan_items(id) ON DELETE CASCADE,

  "userId" text NOT NULL,
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
ON app.optimization_recommendations ("userId", marketplace, sku, created_at DESC);

CREATE INDEX IF NOT EXISTS optimization_recommendations_status_idx
ON app.optimization_recommendations (status);


CREATE TABLE IF NOT EXISTS app.optimization_experiments (
  id bigserial PRIMARY KEY,

  recommendation_id bigint REFERENCES app.optimization_recommendations(id) ON DELETE SET NULL,
  plan_item_id text REFERENCES app.optimization_plan_items(id) ON DELETE CASCADE,

  "userId" text NOT NULL,
  marketplace text NOT NULL,
  sku text NOT NULL,
  asin text,
  currency_code text,

  goal text NOT NULL,
  tested_price numeric(10,2) NOT NULL,
  previous_price numeric(10,2),

  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,

  status text NOT NULL DEFAULT 'running',

  units integer,
  orders integer,
  revenue numeric,
  profit numeric,
  ads_spend numeric,

  discount_contaminated boolean NOT NULL DEFAULT false,
  validity_score numeric,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS optimization_experiments_user_sku_idx
ON app.optimization_experiments ("userId", marketplace, sku, started_at DESC);

CREATE INDEX IF NOT EXISTS optimization_experiments_status_idx
ON app.optimization_experiments (status);
