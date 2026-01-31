-- ==============================================================================
-- COMPLETE USER SIGNUP FUNCTION
-- ==============================================================================
-- This function handles the complete signup flow WITHOUT payment providers:
-- 1. Creates organization (using user name if "same as user" is selected)
-- 2. Assigns user as Owner of the organization
-- 3. Creates trial subscription (if product has trial_days) or active subscription
-- 4. Assigns default product role
-- Note: Payment is emulated - subscriptions are created directly as active/trial
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.fn_complete_user_signup(
  p_user_id uuid,
  p_product_id uuid,
  p_plan_id uuid,
  p_org_name text DEFAULT NULL,
  p_use_user_name boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid;
  v_member_id uuid;
  v_subscription_id uuid;
  v_role_definition_id uuid;
  v_user_full_name text;
  v_org_name text;
  v_product_trial_days integer;
  v_subscription_status text;
  v_user_email text;
BEGIN
  -- Get user's full name and email
  SELECT full_name, email INTO v_user_full_name, v_user_email
  FROM public.profiles
  WHERE id = p_user_id;

  -- Validate user exists
  IF v_user_email IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User profile not found'
    );
  END IF;

  -- Determine organization name
  IF p_use_user_name THEN
    v_org_name := COALESCE(v_user_full_name, 'My Organization');
  ELSE
    v_org_name := COALESCE(p_org_name, 'My Organization');
  END IF;

  -- 1. Create organization
  INSERT INTO public.organizations (name, billing_email)
  VALUES (
    v_org_name,
    v_user_email
  )
  RETURNING id INTO v_org_id;

  -- 2. Add user as member (Owner)
  INSERT INTO public.org_members (org_id, user_id, status)
  VALUES (v_org_id, p_user_id, 'active')
  RETURNING id INTO v_member_id;

  -- 3. Get default role for product
  SELECT id INTO v_role_definition_id
  FROM public.product_role_definitions
  WHERE product_id = p_product_id
    AND is_default = true
  LIMIT 1;

  -- If no default role, try to find "Owner" role
  IF v_role_definition_id IS NULL THEN
    SELECT id INTO v_role_definition_id
    FROM public.product_role_definitions
    WHERE product_id = p_product_id
      AND LOWER(role_name) = 'owner'
    LIMIT 1;
  END IF;

  -- If still no role, try "Member"
  IF v_role_definition_id IS NULL THEN
    SELECT id INTO v_role_definition_id
    FROM public.product_role_definitions
    WHERE product_id = p_product_id
      AND LOWER(role_name) = 'member'
    LIMIT 1;
  END IF;

  -- 4. Assign product role
  IF v_role_definition_id IS NOT NULL THEN
    INSERT INTO public.member_product_roles (member_id, product_id, role_definition_id)
    VALUES (v_member_id, p_product_id, v_role_definition_id)
    ON CONFLICT (member_id, product_id) DO UPDATE
    SET role_definition_id = v_role_definition_id;
  END IF;

  -- 5. Get product trial_days
  SELECT trial_days INTO v_product_trial_days
  FROM public.products
  WHERE id = p_product_id;

  -- 6. Determine subscription status
  -- If product has trial_days, create as 'trial', otherwise 'active'
  -- Payment is emulated - we assume payment is already done
  IF v_product_trial_days IS NOT NULL AND v_product_trial_days > 0 THEN
    v_subscription_status := 'trial';
  ELSE
    -- No trial period, create directly as active (payment emulated)
    v_subscription_status := 'active';
  END IF;

  -- 7. Create subscription
  INSERT INTO public.org_product_subscriptions (
    org_id,
    product_id,
    plan_id,
    status
  )
  VALUES (
    v_org_id,
    p_product_id,
    p_plan_id,
    v_subscription_status
  )
  RETURNING id INTO v_subscription_id;
  -- Trigger validate_trial_dates() will automatically set trial dates if status is 'trial'

  -- Return success with created IDs
  RETURN jsonb_build_object(
    'success', true,
    'org_id', v_org_id,
    'member_id', v_member_id,
    'subscription_id', v_subscription_id,
    'role_definition_id', v_role_definition_id,
    'status', v_subscription_status,
    'trial_days', v_product_trial_days,
    'trial_ends_at', (
      SELECT trial_ends_at 
      FROM public.org_product_subscriptions 
      WHERE id = v_subscription_id
    )
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_complete_user_signup(uuid, uuid, uuid, text, boolean) TO authenticated;

COMMENT ON FUNCTION public.fn_complete_user_signup IS 
  'Complete user signup flow without payment providers: creates organization, assigns user as Owner, creates trial/active subscription (payment emulated), and assigns default product role.';

-- ==============================================================================
-- AUTO-ACTIVATE EXPIRED TRIALS (Payment Emulated)
-- ==============================================================================
-- This function automatically converts expired trials to 'active' status
-- Emulating that payment was already processed
-- Should be called periodically (e.g., via cron job or Edge Function)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.fn_auto_activate_expired_trials()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_updated_count integer;
  v_updated_subscriptions jsonb;
BEGIN
  -- Update expired trials to 'active' (payment emulated)
  WITH updated AS (
    UPDATE public.org_product_subscriptions
    SET 
      status = 'active',
      updated_at = now()
    WHERE status = 'trial'
      AND trial_ends_at IS NOT NULL
      AND trial_ends_at < now()
    RETURNING 
      id,
      org_id,
      product_id,
      plan_id,
      trial_ends_at
  )
  SELECT 
    COUNT(*)::integer,
    COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', id,
        'org_id', org_id,
        'product_id', product_id,
        'plan_id', plan_id,
        'trial_ended_at', trial_ends_at,
        'activated_at', now()
      )
    ), '[]'::jsonb)
  INTO v_updated_count, v_updated_subscriptions
  FROM updated;

  RETURN jsonb_build_object(
    'success', true,
    'updated_count', COALESCE(v_updated_count, 0),
    'updated_subscriptions', COALESCE(v_updated_subscriptions, '[]'::jsonb),
    'message', format('Activated %s expired trial(s)', COALESCE(v_updated_count, 0))
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_auto_activate_expired_trials() TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_auto_activate_expired_trials IS 
  'Automatically converts expired trials to active status, emulating that payment was already processed. Should be called periodically.';
