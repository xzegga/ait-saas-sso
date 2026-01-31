-- ==============================================================================
-- MOVE TRIAL DAYS FROM PRODUCT_PLANS TO PRODUCTS
-- ==============================================================================
-- This migration moves the trial_days configuration from product_plans to products
-- so that trial period is configured per product, not per plan.
-- ==============================================================================

-- Step 1: Add trial_days to products table
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS trial_days integer DEFAULT NULL;

COMMENT ON COLUMN public.products.trial_days IS 'Default number of trial days for subscriptions to this product. NULL means no trial period. This value is used when creating subscriptions with status "trial" to automatically calculate trial_ends_at.';

-- Step 2: Migrate existing data (if any)
-- If a product has multiple plans with different trial_days, use the maximum
-- This ensures we don't lose any trial period configuration
UPDATE public.products p
SET trial_days = (
  SELECT MAX(pp.trial_days)
  FROM public.product_plans pp
  WHERE pp.product_id = p.id
  AND pp.trial_days IS NOT NULL
)
WHERE EXISTS (
  SELECT 1 FROM public.product_plans pp
  WHERE pp.product_id = p.id
  AND pp.trial_days IS NOT NULL
);

-- Step 3: Remove trial_days from product_plans
ALTER TABLE public.product_plans
DROP COLUMN IF EXISTS trial_days;
