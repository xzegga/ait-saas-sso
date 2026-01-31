-- ==============================================================================
-- SUBSCRIPTION VALIDATION AND EXPIRATION FUNCTIONS
-- ==============================================================================
-- Functions to validate subscription access and expire trials automatically
-- ==============================================================================

-- Function to check if a subscription is currently active and accessible
CREATE OR REPLACE FUNCTION public.is_subscription_active(
  p_org_id uuid,
  p_product_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_subscription public.org_product_subscriptions%ROWTYPE;
BEGIN
  -- Get the subscription
  SELECT * INTO v_subscription
  FROM public.org_product_subscriptions
  WHERE org_id = p_org_id
    AND product_id = p_product_id
    AND status IN ('active', 'trial')
  LIMIT 1;

  -- If no subscription found, return false
  IF v_subscription.id IS NULL THEN
    RETURN false;
  END IF;

  -- If status is 'active', it's always accessible
  IF v_subscription.status = 'active' THEN
    RETURN true;
  END IF;

  -- If status is 'trial', check expiration
  IF v_subscription.status = 'trial' THEN
    -- If trial_ends_at is null, trial never expires (unlimited trial)
    IF v_subscription.trial_ends_at IS NULL THEN
      RETURN true;
    END IF;
    
    -- Check if trial has expired
    IF v_subscription.trial_ends_at < now() THEN
      RETURN false;
    END IF;
    
    RETURN true;
  END IF;

  -- For other statuses (past_due, canceled), return false
  RETURN false;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.is_subscription_active(uuid, uuid) TO authenticated, anon;

COMMENT ON FUNCTION public.is_subscription_active(uuid, uuid) IS 'Checks if a subscription is currently active and accessible. Returns true for active subscriptions and non-expired trials.';

-- Function to expire trials that have passed their expiration date
-- Updated to support payment emulation: converts trials to 'active' instead of 'past_due'
CREATE OR REPLACE FUNCTION public.expire_trials()
RETURNS TABLE(
  expired_count integer,
  expired_subscriptions jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired_count integer;
  v_expired_subscriptions jsonb;
  v_payment_emulated boolean := true; -- Set to false when real payment is integrated
BEGIN
  IF v_payment_emulated THEN
    -- Payment emulated: Auto-activate expired trials
    WITH updated AS (
      UPDATE public.org_product_subscriptions
      SET 
        status = 'active',
        updated_at = now()
      WHERE status = 'trial'
        AND trial_ends_at IS NOT NULL
        AND trial_ends_at < now()
      RETURNING id, org_id, product_id, plan_id, trial_ends_at
    )
    SELECT 
      COUNT(*)::integer,
      COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', id,
          'org_id', org_id,
          'product_id', product_id,
          'plan_id', plan_id,
          'expired_at', trial_ends_at,
          'activated_at', now()
        )
      ), '[]'::jsonb)
    INTO v_expired_count, v_expired_subscriptions
    FROM updated;
  ELSE
    -- Real payment: Mark as past_due (original behavior)
    WITH updated AS (
      UPDATE public.org_product_subscriptions
      SET 
        status = 'past_due',
        updated_at = now()
      WHERE status = 'trial'
        AND trial_ends_at IS NOT NULL
        AND trial_ends_at < now()
      RETURNING id, org_id, product_id, trial_ends_at
    )
    SELECT 
      COUNT(*)::integer,
      COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', id,
          'org_id', org_id,
          'product_id', product_id,
          'expired_at', trial_ends_at
        )
      ), '[]'::jsonb)
    INTO v_expired_count, v_expired_subscriptions
    FROM updated;
  END IF;

  RETURN QUERY SELECT 
    COALESCE(v_expired_count, 0),
    COALESCE(v_expired_subscriptions, '[]'::jsonb);
END;
$$;

-- Grant execute permission (typically called by cron job or Edge Function)
GRANT EXECUTE ON FUNCTION public.expire_trials() TO authenticated;

COMMENT ON FUNCTION public.expire_trials() IS 'Expires trials that have passed their expiration date. When payment_emulated=true, converts to active status. When false, converts to past_due. Returns count and details of expired subscriptions. Should be called periodically (e.g., via cron job or Edge Function).';
