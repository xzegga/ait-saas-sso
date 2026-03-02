-- ==============================================================================
-- 022 - EMAIL SENDING FUNCTIONS (from original 035)
-- ==============================================================================
-- get_email_template_data, get_signup_confirmation_email_data,
-- get_admin_new_user_notification_data, get_password_reset_email_data
-- ==============================================================================

-- Function to get email template data (for use by Edge Function or SDK)
-- This function prepares the email data but doesn't send it
CREATE OR REPLACE FUNCTION public.get_email_template_data(
  p_template_name text,
  p_product_id uuid DEFAULT NULL,
  p_placeholders jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_template record;
  v_result jsonb;
BEGIN
  -- Get and render email template
  SELECT * INTO v_template
  FROM public.render_email_template(
    p_template_name,
    p_product_id,
    p_placeholders
  );

  IF v_template.subject IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Email template "%s" not found', p_template_name)
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'subject', v_template.subject,
    'html', v_template.body_html,
    'text', COALESCE(v_template.body_text, '')
  );
END;
$$;

COMMENT ON FUNCTION public.get_email_template_data IS 
  'Gets email template data (subject, html, text) for a given template name and placeholders.
   This function is used by the SDK or Edge Functions to get email content.
   Parameters:
   - p_template_name: Template identifier (e.g., "user_signup_confirmation")
   - p_product_id: Optional product ID for product-specific template
   - p_placeholders: JSON object with placeholder values';

-- Function to get signup confirmation email data
CREATE OR REPLACE FUNCTION public.get_signup_confirmation_email_data(
  p_user_id uuid,
  p_product_id uuid,
  p_verification_link text
)
RETURNS jsonb
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
  v_html text;
  v_text text;
  v_placeholders jsonb;
  v_result jsonb;
BEGIN
  -- Get user information
  SELECT email, full_name INTO v_user_email, v_user_name
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_user_email IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not found'
    );
  END IF;

  -- Get product information
  SELECT name INTO v_product_name
  FROM public.products
  WHERE id = p_product_id;

  IF v_product_name IS NULL THEN
    v_product_name := 'Our Service';
  END IF;

  -- Get and render email template
  SELECT * INTO v_template
  FROM public.render_email_template(
    'user_signup_confirmation',
    p_product_id,
    jsonb_build_object(
      'user_name', COALESCE(v_user_name, 'User'),
      'user_email', v_user_email,
      'product_name', v_product_name,
      'verification_link', p_verification_link
    )
  );

  IF v_template.subject IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Email template not found'
    );
  END IF;

  -- Get email template data
  v_result := public.get_email_template_data(
    'user_signup_confirmation',
    p_product_id,
    jsonb_build_object(
      'user_name', COALESCE(v_user_name, 'User'),
      'user_email', v_user_email,
      'product_name', v_product_name,
      'verification_link', p_verification_link
    )
  );

  IF NOT (v_result->>'success')::boolean THEN
    RETURN v_result;
  END IF;

  -- Return email data with recipient info
  RETURN jsonb_build_object(
    'success', true,
    'to', v_user_email,
    'subject', v_result->>'subject',
    'html', v_result->>'html',
    'text', v_result->>'text',
    'from_name', v_product_name
  );
END;
$$;

COMMENT ON FUNCTION public.get_signup_confirmation_email_data IS 
  'Gets signup confirmation email data (to, subject, html, text) for a user.
   This function is used by the SDK or Edge Functions to get email content.
   Parameters:
   - p_user_id: User ID
   - p_product_id: Product ID
   - p_verification_link: Email verification link from Supabase Auth';

-- Function to get admin notification email data
CREATE OR REPLACE FUNCTION public.get_admin_new_user_notification_data(
  p_user_id uuid,
  p_product_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_template record;
  v_user_email text;
  v_user_name text;
  v_product_name text;
  v_registration_date text;
  v_admin_emails text[];
  v_subject text;
  v_html text;
  v_text text;
  v_result jsonb;
  v_email text;
BEGIN
  -- Get user information
  SELECT email, full_name, created_at INTO v_user_email, v_user_name, v_registration_date
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_user_email IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not found'
    );
  END IF;

  -- Get product information
  SELECT name INTO v_product_name
  FROM public.products
  WHERE id = p_product_id;

  IF v_product_name IS NULL THEN
    v_product_name := 'Our Service';
  END IF;

  -- Get all super admin emails
  -- FIX: super_admins table has email column directly, not user_id
  SELECT ARRAY_AGG(sa.email)
  INTO v_admin_emails
  FROM public.super_admins sa
  WHERE sa.email IS NOT NULL;

  -- If no super admins, return success (no one to notify)
  IF v_admin_emails IS NULL OR array_length(v_admin_emails, 1) = 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'No super admins to notify',
      'recipients', '[]'::jsonb
    );
  END IF;

  -- Get email template data
  v_result := public.get_email_template_data(
    'admin_new_user_notification',
    p_product_id,
    jsonb_build_object(
      'user_name', COALESCE(v_user_name, 'User'),
      'user_email', v_user_email,
      'product_name', v_product_name,
      'registration_date', to_char(v_registration_date, 'YYYY-MM-DD HH24:MI:SS')
    )
  );

  IF NOT (v_result->>'success')::boolean THEN
    RETURN v_result;
  END IF;

  -- Return email data with recipient info
  RETURN jsonb_build_object(
    'success', true,
    'recipients', to_jsonb(v_admin_emails),
    'subject', v_result->>'subject',
    'html', v_result->>'html',
    'text', v_result->>'text',
    'from_name', v_product_name
  );
END;
$$;

COMMENT ON FUNCTION public.get_admin_new_user_notification_data IS 
  'Gets admin notification email data (recipients, subject, html, text) for a new user.
   This function is used by the SDK or Edge Functions to get email content.
   Parameters:
   - p_user_id: New user ID
   - p_product_id: Product ID where user registered';

-- Function to get password reset email data
CREATE OR REPLACE FUNCTION public.get_password_reset_email_data(
  p_user_email text,
  p_reset_link text,
  p_product_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_user_name text;
  v_product_name text;
  v_email_data jsonb;
BEGIN
  -- Get user information by email
  SELECT id, full_name INTO v_user_id, v_user_name
  FROM public.profiles
  WHERE email = p_user_email
  LIMIT 1;

  IF v_user_id IS NULL THEN
    -- Don't reveal that user doesn't exist (security best practice)
    RETURN jsonb_build_object(
      'success', true,
      'to', p_user_email,
      'subject', 'Reset your password',
      'html', '<p>If this email exists, you will receive a password reset link.</p>',
      'text', 'If this email exists, you will receive a password reset link.'
    );
  END IF;

  -- Get product information
  IF p_product_id IS NOT NULL THEN
    SELECT name INTO v_product_name
    FROM public.products
    WHERE id = p_product_id;
  END IF;

  IF v_product_name IS NULL THEN
    -- Try to get from user's active subscription
    SELECT pr.name INTO v_product_name
    FROM public.org_product_subscriptions ops
    INNER JOIN public.organizations o ON o.id = ops.org_id
    INNER JOIN public.org_members om ON om.org_id = o.id
    INNER JOIN public.products pr ON pr.id = ops.product_id
    WHERE om.user_id = v_user_id
      AND ops.status IN ('active', 'trial')
    LIMIT 1;

    IF v_product_name IS NULL THEN
      v_product_name := 'Our Service';
    END IF;
  END IF;

  -- Get email template data
  v_email_data := public.get_email_template_data(
    'password_reset',
    p_product_id,
    jsonb_build_object(
      'user_name', COALESCE(v_user_name, 'User'),
      'user_email', p_user_email,
      'product_name', v_product_name,
      'reset_link', p_reset_link
    )
  );

  IF NOT (v_email_data->>'success')::boolean THEN
    RETURN v_email_data;
  END IF;

  -- Return email data with recipient info
  RETURN jsonb_build_object(
    'success', true,
    'to', p_user_email,
    'subject', v_email_data->>'subject',
    'html', v_email_data->>'html',
    'text', v_email_data->>'text',
    'from_name', v_product_name
  );
END;
$$;

COMMENT ON FUNCTION public.get_password_reset_email_data IS 
  'Gets password reset email data (to, subject, html, text) for a user.
   This function is used by the SDK or Edge Functions to get email content.
   Parameters:
   - p_user_email: User email address
   - p_reset_link: Password reset link from Supabase Auth
   - p_product_id: Optional product ID (will try to detect from user subscription if not provided)';

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_email_template_data(text, uuid, jsonb) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_signup_confirmation_email_data(uuid, uuid, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_admin_new_user_notification_data(uuid, uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_password_reset_email_data(text, text, uuid) TO authenticated, anon;
