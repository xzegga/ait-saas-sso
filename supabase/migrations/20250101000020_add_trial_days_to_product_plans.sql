-- ==============================================================================
-- ADD TRIAL DAYS TO PRODUCT PLANS
-- ==============================================================================
-- This migration adds a trial_days field to product_plans table
-- to allow configuring default trial period for each plan-product relationship
-- ==============================================================================

-- Add trial_days column to product_plans
ALTER TABLE public.product_plans
ADD COLUMN IF NOT EXISTS trial_days integer DEFAULT NULL;

-- Add comment for clarity
COMMENT ON COLUMN public.product_plans.trial_days IS 'Default number of trial days for this plan when assigned to this product. NULL means no trial period. This value can be used when creating subscriptions to automatically set trial_starts_at and trial_ends_at.';
