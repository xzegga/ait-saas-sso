-- ==============================================================================
-- 012 - FN_COMPLETE_USER_SIGNUP (with billing_interval)
-- ==============================================================================

SET client_min_messages = WARNING;
DROP FUNCTION IF EXISTS public.fn_complete_user_signup(uuid, text, uuid, text, boolean);
DROP FUNCTION IF EXISTS public.fn_complete_user_signup(uuid, uuid, uuid, text, boolean);
RESET client_min_messages;

CREATE OR REPLACE FUNCTION public.fn_complete_user_signup(
  p_user_id uuid,
  p_product_id text,
  p_plan_id uuid,
  p_billing_interval text DEFAULT 'month',
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
  v_actual_product_id uuid;
  v_is_uuid boolean;
  v_billing_interval text;
BEGIN
  SELECT full_name, email INTO v_user_full_name, v_user_email
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_user_email IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User profile not found');
  END IF;

  v_billing_interval := COALESCE(p_billing_interval, 'month');
  IF NOT EXISTS (SELECT 1 FROM public.billing_intervals WHERE key = v_billing_interval AND is_active = true AND deleted_at IS NULL) THEN
    RETURN jsonb_build_object('success', false, 'error', format('Invalid billing interval: %s', v_billing_interval));
  END IF;

  v_is_uuid := p_product_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

  IF v_is_uuid THEN
    SELECT id INTO v_actual_product_id FROM public.products WHERE id = p_product_id::uuid AND status = true AND deleted_at IS NULL;
  ELSE
    SELECT id INTO v_actual_product_id FROM public.products WHERE client_id = p_product_id AND status = true AND deleted_at IS NULL;
  END IF;

  IF v_actual_product_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Product not found or inactive');
  END IF;

  IF p_use_user_name THEN
    v_org_name := COALESCE(v_user_full_name, 'My Organization');
  ELSE
    v_org_name := COALESCE(p_org_name, 'My Organization');
  END IF;

  INSERT INTO public.organizations (name, billing_email)
  VALUES (v_org_name, v_user_email)
  RETURNING id INTO v_org_id;

  INSERT INTO public.org_members (org_id, user_id, status)
  VALUES (v_org_id, p_user_id, 'active')
  ON CONFLICT (org_id, user_id) DO UPDATE SET status = 'active'
  RETURNING id INTO v_member_id;

  SELECT id INTO v_role_definition_id
  FROM public.product_role_definitions
  WHERE product_id = v_actual_product_id AND is_default = true
  LIMIT 1;

  IF v_role_definition_id IS NULL THEN
    SELECT id INTO v_role_definition_id
    FROM public.product_role_definitions
    WHERE product_id = v_actual_product_id AND LOWER(role_name) = 'owner'
    LIMIT 1;
  END IF;

  IF v_role_definition_id IS NULL THEN
    SELECT id INTO v_role_definition_id
    FROM public.product_role_definitions
    WHERE product_id = v_actual_product_id AND LOWER(role_name) = 'member'
    LIMIT 1;
  END IF;

  IF v_role_definition_id IS NOT NULL THEN
    INSERT INTO public.member_product_roles (member_id, product_id, role_definition_id)
    VALUES (v_member_id, v_actual_product_id, v_role_definition_id)
    ON CONFLICT (member_id, product_id) DO UPDATE SET role_definition_id = v_role_definition_id;
  END IF;

  SELECT trial_days INTO v_product_trial_days FROM public.products WHERE id = v_actual_product_id;

  IF v_product_trial_days IS NOT NULL AND v_product_trial_days > 0 THEN
    v_subscription_status := 'trial';
  ELSE
    v_subscription_status := 'active';
  END IF;

  INSERT INTO public.org_product_subscriptions (org_id, product_id, plan_id, billing_interval_id, status)
  VALUES (v_org_id, v_actual_product_id, p_plan_id, v_billing_interval, v_subscription_status)
  RETURNING id INTO v_subscription_id;

  RETURN jsonb_build_object(
    'success', true,
    'org_id', v_org_id,
    'member_id', v_member_id,
    'subscription_id', v_subscription_id,
    'role_definition_id', v_role_definition_id,
    'status', v_subscription_status,
    'billing_interval', v_billing_interval,
    'trial_days', v_product_trial_days,
    'trial_ends_at', (SELECT trial_ends_at FROM public.org_product_subscriptions WHERE id = v_subscription_id)
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_complete_user_signup(uuid, text, uuid, text, text, boolean) TO authenticated;

COMMENT ON FUNCTION public.fn_complete_user_signup(uuid, text, uuid, text, text, boolean) IS
  'Complete user signup flow: creates organization, assigns user as Owner, creates trial/active subscription with billing_interval, assigns default product role. Accepts product_id as UUID or client_id (text).';
