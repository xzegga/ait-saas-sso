-- ==============================================================================
-- ADD BILLING INTERVAL TO SUBSCRIPTIONS
-- ==============================================================================
-- This migration adds billing_interval_id to org_product_subscriptions
-- and updates fn_complete_user_signup to accept and store billing_interval
-- ==============================================================================

-- Add billing_interval_id column to org_product_subscriptions
ALTER TABLE public.org_product_subscriptions
ADD COLUMN IF NOT EXISTS billing_interval_id text REFERENCES public.billing_intervals(key) ON UPDATE CASCADE;

COMMENT ON COLUMN public.org_product_subscriptions.billing_interval_id IS 'Billing interval key (references billing_intervals.key). Defines the billing period for this subscription.';

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_subscriptions_billing_interval 
  ON public.org_product_subscriptions(billing_interval_id) 
  WHERE billing_interval_id IS NOT NULL;

-- ==============================================================================
-- UPDATE fn_complete_user_signup TO ACCEPT BILLING INTERVAL
-- ==============================================================================

-- Drop the old function
DROP FUNCTION IF EXISTS public.fn_complete_user_signup(uuid, text, uuid, text, boolean);

-- Create the updated function with billing_interval parameter
CREATE OR REPLACE FUNCTION public.fn_complete_user_signup(
  p_user_id uuid,
  p_product_id text,  -- UUID or client_id
  p_plan_id uuid,
  p_billing_interval text DEFAULT 'month',  -- Billing interval key (e.g., 'month', 'year')
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
  v_actual_product_id uuid;  -- Actual product UUID
  v_is_uuid boolean;
  v_billing_interval text;
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

  -- Validate billing_interval exists
  v_billing_interval := COALESCE(p_billing_interval, 'month');
  IF NOT EXISTS (SELECT 1 FROM public.billing_intervals WHERE key = v_billing_interval AND is_active = true AND deleted_at IS NULL) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Invalid billing interval: %s', v_billing_interval)
    );
  END IF;

  -- Check if p_product_id is a UUID or client_id
  v_is_uuid := p_product_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

  -- Get actual product UUID
  IF v_is_uuid THEN
    SELECT id INTO v_actual_product_id
    FROM public.products
    WHERE id = p_product_id::uuid
      AND status = true
      AND deleted_at IS NULL;
  ELSE
    SELECT id INTO v_actual_product_id
    FROM public.products
    WHERE client_id = p_product_id
      AND status = true
      AND deleted_at IS NULL;
  END IF;

  -- Validate product exists
  IF v_actual_product_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Product not found or inactive'
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

  -- 2. Add user as member (Owner) - Ensure user is associated with organization
  INSERT INTO public.org_members (org_id, user_id, status)
  VALUES (v_org_id, p_user_id, 'active')
  ON CONFLICT (org_id, user_id) DO UPDATE
  SET status = 'active'
  RETURNING id INTO v_member_id;

  -- 3. Get default role for product (using v_actual_product_id)
  SELECT id INTO v_role_definition_id
  FROM public.product_role_definitions
  WHERE product_id = v_actual_product_id
    AND is_default = true
  LIMIT 1;

  -- If no default role, try to find "Owner" role
  IF v_role_definition_id IS NULL THEN
    SELECT id INTO v_role_definition_id
    FROM public.product_role_definitions
    WHERE product_id = v_actual_product_id
      AND LOWER(role_name) = 'owner'
    LIMIT 1;
  END IF;

  -- If still no role, try "Member"
  IF v_role_definition_id IS NULL THEN
    SELECT id INTO v_role_definition_id
    FROM public.product_role_definitions
    WHERE product_id = v_actual_product_id
      AND LOWER(role_name) = 'member'
    LIMIT 1;
  END IF;

  -- 4. Assign product role
  IF v_role_definition_id IS NOT NULL THEN
    INSERT INTO public.member_product_roles (member_id, product_id, role_definition_id)
    VALUES (v_member_id, v_actual_product_id, v_role_definition_id)
    ON CONFLICT (member_id, product_id) DO UPDATE
    SET role_definition_id = v_role_definition_id;
  END IF;

  -- 5. Get product trial_days (using v_actual_product_id)
  SELECT trial_days INTO v_product_trial_days
  FROM public.products
  WHERE id = v_actual_product_id;

  -- 6. Determine subscription status
  -- If product has trial_days, create as 'trial', otherwise 'active'
  -- Payment is emulated - we assume payment is already done
  IF v_product_trial_days IS NOT NULL AND v_product_trial_days > 0 THEN
    v_subscription_status := 'trial';
  ELSE
    -- No trial period, create directly as active (payment emulated)
    v_subscription_status := 'active';
  END IF;

  -- 7. Create subscription with billing_interval_id
  INSERT INTO public.org_product_subscriptions (
    org_id,
    product_id,
    plan_id,
    billing_interval_id,
    status
  )
  VALUES (
    v_org_id,
    v_actual_product_id,
    p_plan_id,
    v_billing_interval,
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
    'billing_interval', v_billing_interval,
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

GRANT EXECUTE ON FUNCTION public.fn_complete_user_signup(uuid, text, uuid, text, text, boolean) TO authenticated;

COMMENT ON FUNCTION public.fn_complete_user_signup(uuid, text, uuid, text, text, boolean) IS 
  'Complete user signup flow without payment providers: creates organization, assigns user as Owner, creates trial/active subscription (payment emulated) with billing_interval, and assigns default product role. Accepts product_id as UUID or client_id (text).';
