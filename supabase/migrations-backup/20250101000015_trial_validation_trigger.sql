-- ==============================================================================
-- TRIAL VALIDATION TRIGGER
-- ==============================================================================
-- Trigger to automatically set trial dates when status is 'trial'
-- ==============================================================================

-- Trigger function to validate and set trial dates
CREATE OR REPLACE FUNCTION public.validate_trial_dates()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- If status is 'trial', ensure trial dates are set
  IF NEW.status = 'trial' THEN
    -- If trial_starts_at is null, set it to now
    IF NEW.trial_starts_at IS NULL THEN
      NEW.trial_starts_at := now();
    END IF;
    
    -- Note: trial_ends_at can be null for unlimited trials
    -- It should be set explicitly when creating a trial subscription
  END IF;

  -- If status is NOT 'trial', clear trial dates
  IF NEW.status != 'trial' THEN
    NEW.trial_starts_at := NULL;
    NEW.trial_ends_at := NULL;
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS validate_trial_dates_trigger ON public.org_product_subscriptions;
CREATE TRIGGER validate_trial_dates_trigger
  BEFORE INSERT OR UPDATE ON public.org_product_subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_trial_dates();

COMMENT ON FUNCTION public.validate_trial_dates() IS 'Trigger function that automatically sets trial_starts_at when status is set to trial, and clears trial dates when status is changed from trial.';
