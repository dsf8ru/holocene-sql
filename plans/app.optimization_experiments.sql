CREATE TABLE IF NOT EXISTS app.optimization_experiments (
  id bigserial PRIMARY KEY,

  recommendation_id bigint REFERENCES app.optimization_recommendations(id) ON DELETE SET NULL,
  plan_item_id text REFERENCES app.optimization_plan_items(id) ON DELETE CASCADE,

  userId text NOT NULL,
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
ON app.optimization_experiments (userId, marketplace, sku, started_at DESC);

CREATE INDEX IF NOT EXISTS optimization_experiments_status_idx
ON app.optimization_experiments (status);

