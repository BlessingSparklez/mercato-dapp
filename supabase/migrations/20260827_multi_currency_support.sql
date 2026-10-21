-- Add currency_code column to supplier_products and related financial tables with default 'USD' for legacy compatibility
ALTER TABLE supplier_products ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3) NOT NULL DEFAULT 'USD';

-- `purchase_orders` and `financing_opportunities` belong to other workstreams and are not created by
-- any migration in this repository. They are guarded so a fresh database can still be provisioned;
-- where the tables do exist, the original column additions and backfills still run unchanged.
DO $$
BEGIN
  IF to_regclass('public.purchase_orders') IS NOT NULL THEN
    ALTER TABLE purchase_orders
      ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3) NOT NULL DEFAULT 'USD';
    UPDATE purchase_orders SET currency_code = 'USD' WHERE currency_code IS NULL;
  END IF;

  IF to_regclass('public.financing_opportunities') IS NOT NULL THEN
    ALTER TABLE financing_opportunities
      ADD COLUMN IF NOT EXISTS commercial_currency VARCHAR(3) NOT NULL DEFAULT 'USD';
    -- 'USDC' is four characters; VARCHAR(3) rejected its own default.
    ALTER TABLE financing_opportunities
      ADD COLUMN IF NOT EXISTS settlement_currency VARCHAR(4) NOT NULL DEFAULT 'USDC';
    ALTER TABLE financing_opportunities
      ADD COLUMN IF NOT EXISTS exchange_rate NUMERIC(18, 6);
    ALTER TABLE financing_opportunities
      ADD COLUMN IF NOT EXISTS exchange_rate_source VARCHAR(64);
    ALTER TABLE financing_opportunities
      ADD COLUMN IF NOT EXISTS exchange_rate_timestamp TIMESTAMPTZ;
  END IF;
END
$$;

-- Environments where an earlier revision already applied VARCHAR(3) need the widening explicitly,
-- because ADD COLUMN IF NOT EXISTS leaves an existing column untouched.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'financing_opportunities'
      AND column_name = 'settlement_currency'
      AND character_maximum_length = 3
  ) THEN
    ALTER TABLE financing_opportunities
      ALTER COLUMN settlement_currency TYPE VARCHAR(4);
  END IF;
END
$$;

-- Backfill legacy records explicitly
UPDATE supplier_products SET currency_code = 'USD' WHERE currency_code IS NULL;
