-- ==============================================================================
-- FIX PAYMENT PRICES: Allow multiple prices per plan/provider with different billing intervals
-- ==============================================================================
-- This migration modifies the unique constraint on payment_prices to allow
-- multiple prices for the same product_plan_id and provider_id, but with
-- different billing_interval values.
-- ==============================================================================

-- Drop the existing unique constraint
ALTER TABLE public.payment_prices 
DROP CONSTRAINT IF EXISTS payment_prices_product_plan_id_provider_id_key;

-- Add new unique constraint that includes billing_interval
-- This allows multiple prices per plan/provider (one per billing interval)
ALTER TABLE public.payment_prices 
ADD CONSTRAINT payment_prices_unique_per_interval 
UNIQUE (product_plan_id, provider_id, billing_interval);

-- Update comment to reflect the change
COMMENT ON CONSTRAINT payment_prices_unique_per_interval ON public.payment_prices IS 
'Allows multiple prices per product_plan and provider, one per billing_interval (month, year, day, week)';
