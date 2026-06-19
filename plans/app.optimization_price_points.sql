CREATE TABLE IF NOT EXISTS app.optimization_price_points (
  id bigserial PRIMARY KEY,

  userId text NOT NULL,
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
ON app.optimization_price_points (userId, marketplace, sku, calculated_at DESC);
