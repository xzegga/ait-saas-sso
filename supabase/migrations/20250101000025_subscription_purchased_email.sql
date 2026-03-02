-- ==============================================================================
-- 025 - SUBSCRIPTION PURCHASED EMAIL (from original 040)
-- ==============================================================================
-- Template subscription_purchased + get_subscription_purchased_email_data
-- ==============================================================================

-- Insert subscription_purchased email template (generic)
INSERT INTO public.email_templates (
  name,
  product_id,
  subject,
  body_html,
  body_text,
  placeholders,
  description,
  is_active
) VALUES (
  'subscription_purchased',
  NULL, -- Generic template
  'Your {{product_name}} Subscription is Active',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Subscription Confirmation</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
    <h1 style="color: #2563eb; margin-top: 0;">Subscription Confirmation</h1>
    <p>Hello {{user_name}},</p>
    <p>Thank you for subscribing to <strong>{{product_name}}</strong>! Your subscription is now active.</p>
  </div>

  <div style="background-color: #ffffff; border: 1px solid #e5e7eb; border-radius: 8px; padding: 20px; margin-bottom: 20px;">
    <h2 style="color: #1f2937; margin-top: 0; border-bottom: 2px solid #e5e7eb; padding-bottom: 10px;">Subscription Details</h2>
    
    <table style="width: 100%; border-collapse: collapse;">
      <tr>
        <td style="padding: 8px 0; color: #6b7280; width: 40%;">Plan:</td>
        <td style="padding: 8px 0; font-weight: bold;">{{plan_name}}</td>
      </tr>
      <tr>
        <td style="padding: 8px 0; color: #6b7280;">Billing Period:</td>
        <td style="padding: 8px 0; font-weight: bold;">{{billing_period}}</td>
      </tr>
      <tr>
        <td style="padding: 8px 0; color: #6b7280;">Price:</td>
        <td style="padding: 8px 0; font-weight: bold;">{{price}}</td>
      </tr>
      <tr>
        <td style="padding: 8px 0; color: #6b7280;">Trial Period:</td>
        <td style="padding: 8px 0; font-weight: bold;">{{trial_days}}</td>
      </tr>
      <tr>
        <td style="padding: 8px 0; color: #6b7280;">Trial Ends:</td>
        <td style="padding: 8px 0; font-weight: bold;">{{trial_ends_at}}</td>
      </tr>
      <tr>
        <td style="padding: 8px 0; color: #6b7280;">Status:</td>
        <td style="padding: 8px 0; font-weight: bold; color: #10b981;">{{status}}</td>
      </tr>
      <tr>
        <td style="padding: 8px 0; color: #6b7280;">Organization:</td>
        <td style="padding: 8px 0; font-weight: bold;">{{organization_name}}</td>
      </tr>
    </table>
  </div>

  <div style="background-color: #eff6ff; border-left: 4px solid #2563eb; padding: 15px; margin-bottom: 20px;">
    <p style="margin: 0; color: #1e40af;">
      <strong>Next Steps:</strong><br>
      You can now access your dashboard and start using {{product_name}}. If you have any questions, please don''t hesitate to contact our support team.
    </p>
  </div>

  <div style="text-align: center; margin-top: 30px;">
    <a href="{{dashboard_url}}" style="display: inline-block; background-color: #2563eb; color: #ffffff; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold;">Go to Dashboard</a>
  </div>

  <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb; color: #6b7280; font-size: 12px; text-align: center;">
    <p>This is an automated email. Please do not reply to this message.<br>
    If you have any questions, please contact our support team.</p>
  </div>
</body>
</html>',
  'Subscription Confirmation

Hello {{user_name}},

Thank you for subscribing to {{product_name}}! Your subscription is now active.

Subscription Details:
- Plan: {{plan_name}}
- Billing Period: {{billing_period}}
- Price: {{price}}
- Trial Period: {{trial_days}}
- Trial Ends: {{trial_ends_at}}
- Status: {{status}}
- Organization: {{organization_name}}

Next Steps:
You can now access your dashboard and start using {{product_name}}. If you have any questions, please don''t hesitate to contact our support team.

Go to Dashboard: {{dashboard_url}}

This is an automated email. Please do not reply to this message.
If you have any questions, please contact our support team.',
  '["user_name", "user_email", "product_name", "plan_name", "billing_period", "price", "trial_days", "trial_ends_at", "status", "organization_name", "dashboard_url"]'::jsonb,
  'Email sent to user after successful subscription purchase/creation',
  true
) ON CONFLICT (name, product_id) DO UPDATE
SET
  subject = EXCLUDED.subject,
  body_html = EXCLUDED.body_html,
  body_text = EXCLUDED.body_text,
  placeholders = EXCLUDED.placeholders,
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  updated_at = now();

-- Function to get subscription purchased email data
-- FIXED: Correct column references and price formatting
CREATE OR REPLACE FUNCTION public.get_subscription_purchased_email_data(
  p_user_id uuid,
  p_subscription_id uuid,
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
  v_plan_name text;
  v_billing_period text;
  v_price text;
  v_trial_days integer;
  v_trial_days_formatted text;
  v_trial_ends_at text;
  v_trial_starts_at timestamptz;
  v_trial_ends_at_ts timestamptz;
  v_status text;
  v_org_name text;
  v_subject text;
  v_body_html text;
  v_body_text text;
  v_placeholders jsonb;
  v_price_amount numeric;
  v_currency text;
  v_product_trial_days integer;
BEGIN
  -- Get user email and name
  SELECT p.email, COALESCE(p.full_name, p.email) INTO v_user_email, v_user_name
  FROM public.profiles p
  WHERE p.id = p_user_id;
  
  IF v_user_email IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  
  -- Get subscription details with plan and billing interval
  -- FIX: org_product_subscriptions has trial_ends_at and trial_starts_at, but NOT trial_days
  -- FIX: product_plan_prices uses product_plan_id (FK to product_plans.id), not product_id + plan_id
  -- FIX: product_plans doesn't have name, need to join with plans table
  SELECT 
    s.status,
    s.trial_starts_at,
    s.trial_ends_at,
    p.name as plan_name,
    bi.label as billing_period_label,
    ppp.price as price_amount,
    ppp.currency
  INTO v_status, v_trial_starts_at, v_trial_ends_at_ts, v_plan_name, v_billing_period, v_price_amount, v_currency
  FROM public.org_product_subscriptions s
  JOIN public.product_plans pp ON pp.product_id = s.product_id AND pp.plan_id = s.plan_id
  JOIN public.plans p ON p.id = s.plan_id
  JOIN public.product_plan_prices ppp ON ppp.product_plan_id = pp.id
    AND ppp.billing_interval = s.billing_interval_id
  JOIN public.billing_intervals bi ON bi.key = s.billing_interval_id
  WHERE s.id = p_subscription_id;
  
  IF v_plan_name IS NULL THEN
    RAISE EXCEPTION 'Subscription not found';
  END IF;
  
  -- Calculate trial_days from dates if available, otherwise get from product
  IF v_trial_starts_at IS NOT NULL AND v_trial_ends_at_ts IS NOT NULL THEN
    v_trial_days := EXTRACT(DAY FROM (v_trial_ends_at_ts - v_trial_starts_at))::integer;
  ELSIF p_product_id IS NOT NULL THEN
    -- Get trial_days from product if subscription dates are not available
    SELECT trial_days INTO v_product_trial_days
    FROM public.products
    WHERE id = p_product_id;
    v_trial_days := v_product_trial_days;
  ELSE
    v_trial_days := NULL;
  END IF;
  
  -- Format price - FIX: Use string concatenation instead of format() to avoid % escaping issues
  IF v_price_amount IS NOT NULL THEN
    v_price := COALESCE(v_currency, 'USD') || ' ' || to_char(v_price_amount, 'FM999999990.00');
  ELSE
    v_price := 'Free';
  END IF;
  
  -- Format billing period
  IF v_billing_period IS NULL THEN
    v_billing_period := 'Monthly';
  END IF;
  
  -- Format trial ends at
  IF v_trial_ends_at_ts IS NOT NULL THEN
    v_trial_ends_at := to_char(v_trial_ends_at_ts::timestamp, 'Month DD, YYYY');
  ELSE
    v_trial_ends_at := 'N/A';
  END IF;
  
  -- Format trial days
  IF v_trial_days IS NOT NULL AND v_trial_days > 0 THEN
    v_trial_days_formatted := v_trial_days::text || ' days';
  ELSE
    v_trial_days_formatted := 'N/A';
  END IF;
  
  -- Get product name if product_id is provided
  IF p_product_id IS NOT NULL THEN
    SELECT name INTO v_product_name
    FROM public.products
    WHERE id = p_product_id;
  END IF;
  
  -- Get user's organization name
  SELECT o.name INTO v_org_name
  FROM public.org_members om
  JOIN public.organizations o ON o.id = om.org_id
  WHERE om.user_id = p_user_id
  ORDER BY om.created_at ASC
  LIMIT 1;
  
  -- Get email template (product-specific or generic)
  SELECT * INTO v_template
  FROM public.get_email_template('subscription_purchased', p_product_id);
  
  IF v_template IS NULL THEN
    RAISE EXCEPTION 'Email template not found: subscription_purchased';
  END IF;
  
  -- Build placeholders object
  v_placeholders := jsonb_build_object(
    'user_name', v_user_name,
    'user_email', v_user_email,
    'product_name', COALESCE(v_product_name, 'our platform'),
    'plan_name', v_plan_name,
    'billing_period', v_billing_period,
    'price', v_price,
    'trial_days', COALESCE(v_trial_days_formatted, 'N/A'),
    'trial_ends_at', COALESCE(v_trial_ends_at, 'N/A'),
    'status', COALESCE(v_status, 'active'),
    'organization_name', COALESCE(v_org_name, ''),
    'dashboard_url', COALESCE(p_dashboard_url, '')
  );
  
  -- Get and render email template
  SELECT 
    r.subject,
    r.body_html,
    r.body_text
  INTO v_subject, v_body_html, v_body_text
  FROM public.render_email_template('subscription_purchased', p_product_id, v_placeholders) r;
  
  RETURN QUERY SELECT v_user_email, v_subject, v_body_html, v_body_text;
END;
$$;

COMMENT ON FUNCTION public.get_subscription_purchased_email_data IS 
  'Gets email data for subscription purchased/created confirmation email. 
   Calculates trial_days from subscription dates or product settings.';

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_subscription_purchased_email_data(uuid, uuid, uuid, text) TO authenticated, anon;
