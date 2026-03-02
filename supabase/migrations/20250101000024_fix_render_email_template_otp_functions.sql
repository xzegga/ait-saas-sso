-- ==============================================================================
-- 024 - OTP/WELCOME EMAIL FUNCTIONS (from original 039 - correct render_email_template calls)
-- ==============================================================================
-- get_signup_otp_email_data, get_password_reset_otp_email_data,
-- get_welcome_email_data, get_password_reset_success_email_data
-- ==============================================================================

-- Fix get_signup_otp_email_data
CREATE OR REPLACE FUNCTION public.get_signup_otp_email_data(
  p_user_id uuid,
  p_verification_code text,
  p_product_id uuid DEFAULT NULL
)
RETURNS TABLE (
  to_email text,
  subject text,
  body_html text,
  body_text text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_template record;
  v_user_email text;
  v_user_name text;
  v_product_name text;
  v_subject text;
  v_body_html text;
  v_body_text text;
  v_placeholders jsonb;
BEGIN
  -- Get user email and name
  SELECT email, COALESCE(full_name, email) INTO v_user_email, v_user_name
  FROM public.profiles
  WHERE id = p_user_id;
  
  IF v_user_email IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  
  -- Get product name if product_id is provided
  IF p_product_id IS NOT NULL THEN
    SELECT name INTO v_product_name
    FROM public.products
    WHERE id = p_product_id;
  END IF;
  
  -- Build placeholders object
  v_placeholders := jsonb_build_object(
    'verification_code', p_verification_code,
    'user_name', v_user_name,
    'user_email', v_user_email,
    'product_name', COALESCE(v_product_name, 'our platform')
  );
  
  -- Get and render email template
  SELECT 
    r.subject,
    r.body_html,
    r.body_text
  INTO v_subject, v_body_html, v_body_text
  FROM public.render_email_template('user_signup_otp', p_product_id, v_placeholders) r;
  
  RETURN QUERY SELECT v_user_email, v_subject, v_body_html, v_body_text;
END;
$$;

-- Fix get_password_reset_otp_email_data
CREATE OR REPLACE FUNCTION public.get_password_reset_otp_email_data(
  p_user_email text,
  p_verification_code text,
  p_product_id uuid DEFAULT NULL
)
RETURNS TABLE (
  to_email text,
  subject text,
  body_html text,
  body_text text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_template record;
  v_user_name text;
  v_product_name text;
  v_subject text;
  v_body_html text;
  v_body_text text;
  v_placeholders jsonb;
BEGIN
  -- Get user name
  SELECT COALESCE(full_name, email) INTO v_user_name
  FROM public.profiles
  WHERE email = p_user_email
  LIMIT 1;
  
  IF v_user_name IS NULL THEN
    v_user_name := p_user_email;
  END IF;
  
  -- Get product name if product_id is provided
  IF p_product_id IS NOT NULL THEN
    SELECT name INTO v_product_name
    FROM public.products
    WHERE id = p_product_id;
  END IF;
  
  -- Build placeholders object
  v_placeholders := jsonb_build_object(
    'verification_code', p_verification_code,
    'user_name', v_user_name,
    'user_email', p_user_email,
    'product_name', COALESCE(v_product_name, 'our platform')
  );
  
  -- Get and render email template
  SELECT 
    r.subject,
    r.body_html,
    r.body_text
  INTO v_subject, v_body_html, v_body_text
  FROM public.render_email_template('password_reset_otp', p_product_id, v_placeholders) r;
  
  RETURN QUERY SELECT p_user_email, v_subject, v_body_html, v_body_text;
END;
$$;

-- Fix get_welcome_email_data
CREATE OR REPLACE FUNCTION public.get_welcome_email_data(
  p_user_id uuid,
  p_product_id uuid DEFAULT NULL,
  p_dashboard_url text DEFAULT NULL
)
RETURNS TABLE (
  to_email text,
  subject text,
  body_html text,
  body_text text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_template record;
  v_user_email text;
  v_user_name text;
  v_product_name text;
  v_org_name text;
  v_subject text;
  v_body_html text;
  v_body_text text;
  v_placeholders jsonb;
BEGIN
  -- Get user email and name
  SELECT p.email, COALESCE(p.full_name, p.email) INTO v_user_email, v_user_name
  FROM public.profiles p
  WHERE p.id = p_user_id;
  
  IF v_user_email IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  
  -- Get product name if product_id is provided
  IF p_product_id IS NOT NULL THEN
    SELECT name INTO v_product_name
    FROM public.products
    WHERE id = p_product_id;
  END IF;
  
  -- Get user's organization name (first one)
  SELECT o.name INTO v_org_name
  FROM public.org_members om
  JOIN public.organizations o ON o.id = om.org_id
  WHERE om.user_id = p_user_id
  ORDER BY om.created_at ASC
  LIMIT 1;
  
  -- Build placeholders object
  v_placeholders := jsonb_build_object(
    'user_name', v_user_name,
    'user_email', v_user_email,
    'product_name', COALESCE(v_product_name, 'our platform'),
    'dashboard_url', COALESCE(p_dashboard_url, ''),
    'organization_name', COALESCE(v_org_name, '')
  );
  
  -- Get and render email template
  SELECT 
    r.subject,
    r.body_html,
    r.body_text
  INTO v_subject, v_body_html, v_body_text
  FROM public.render_email_template('user_welcome', p_product_id, v_placeholders) r;
  
  RETURN QUERY SELECT v_user_email, v_subject, v_body_html, v_body_text;
END;
$$;

-- Fix get_password_reset_success_email_data
CREATE OR REPLACE FUNCTION public.get_password_reset_success_email_data(
  p_user_email text,
  p_product_id uuid DEFAULT NULL,
  p_signin_url text DEFAULT NULL
)
RETURNS TABLE (
  to_email text,
  subject text,
  body_html text,
  body_text text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_template record;
  v_user_name text;
  v_product_name text;
  v_subject text;
  v_body_html text;
  v_body_text text;
  v_placeholders jsonb;
BEGIN
  -- Get user name
  SELECT COALESCE(full_name, email) INTO v_user_name
  FROM public.profiles
  WHERE email = p_user_email
  LIMIT 1;
  
  IF v_user_name IS NULL THEN
    v_user_name := p_user_email;
  END IF;
  
  -- Get product name if product_id is provided
  IF p_product_id IS NOT NULL THEN
    SELECT name INTO v_product_name
    FROM public.products
    WHERE id = p_product_id;
  END IF;
  
  -- Build placeholders object
  v_placeholders := jsonb_build_object(
    'user_name', v_user_name,
    'user_email', p_user_email,
    'product_name', COALESCE(v_product_name, 'our platform'),
    'signin_url', COALESCE(p_signin_url, '')
  );
  
  -- Get and render email template
  SELECT 
    r.subject,
    r.body_html,
    r.body_text
  INTO v_subject, v_body_html, v_body_text
  FROM public.render_email_template('password_reset_success', p_product_id, v_placeholders) r;
  
  RETURN QUERY SELECT p_user_email, v_subject, v_body_html, v_body_text;
END;
$$;

COMMENT ON FUNCTION public.get_signup_otp_email_data IS 
  'Gets email data for signup OTP verification email';

COMMENT ON FUNCTION public.get_password_reset_otp_email_data IS 
  'Gets email data for password reset OTP verification email';

COMMENT ON FUNCTION public.get_welcome_email_data IS 
  'Gets email data for welcome email sent after successful email verification';

COMMENT ON FUNCTION public.get_password_reset_success_email_data IS 
  'Gets email data for password reset success confirmation email';

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_signup_otp_email_data(uuid, text, uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_password_reset_otp_email_data(text, text, uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_welcome_email_data(uuid, uuid, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_password_reset_success_email_data(text, uuid, text) TO authenticated, anon;
