-- ==============================================================================
-- TABLE ALTERATIONS - Add Columns and Modifications
-- ==============================================================================
-- This migration adds columns to existing tables
-- ==============================================================================

-- Add trial date fields to org_product_subscriptions
ALTER TABLE public.org_product_subscriptions
ADD COLUMN IF NOT EXISTS trial_starts_at timestamptz,
ADD COLUMN IF NOT EXISTS trial_ends_at timestamptz;

-- Add comments for clarity
COMMENT ON COLUMN public.org_product_subscriptions.trial_starts_at IS 'When the trial period started (null if not a trial)';
COMMENT ON COLUMN public.org_product_subscriptions.trial_ends_at IS 'When the trial period expires (null if not a trial or no expiration). If status is "trial" and this date has passed, subscription should be considered expired.';

-- Add index for efficient queries on expired trials
CREATE INDEX IF NOT EXISTS idx_subscriptions_trial_expires 
  ON public.org_product_subscriptions(trial_ends_at) 
  WHERE status = 'trial' AND trial_ends_at IS NOT NULL;
