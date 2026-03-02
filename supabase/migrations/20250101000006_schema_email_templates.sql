-- ==============================================================================
-- 006 - EMAIL TEMPLATES (table, get/render functions, trigger, grants, default seed)
-- ==============================================================================

-- Step 1: Create email_templates table
CREATE TABLE IF NOT EXISTS public.email_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL, -- Template identifier: 'user_signup_confirmation', 'password_reset', 'user_invitation', 'admin_new_user_notification'
  product_id uuid REFERENCES public.products(id) ON DELETE CASCADE, -- NULL = generic template, NOT NULL = product-specific
  subject text NOT NULL, -- Email subject with placeholders
  body_html text NOT NULL, -- HTML email body with placeholders
  body_text text, -- Plain text email body with placeholders (optional)
  placeholders jsonb DEFAULT '[]'::jsonb, -- Array of available placeholders: ["user_name", "product_name", "verification_link", etc.]
  description text, -- Description of what this template is used for
  is_active boolean DEFAULT true NOT NULL, -- Enable/disable template
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  deleted_at timestamptz DEFAULT NULL, -- Soft delete support
  
  -- Ensure unique template name per product (or generic if product_id is NULL)
  CONSTRAINT email_templates_name_product_unique UNIQUE (name, product_id)
);

COMMENT ON TABLE public.email_templates IS 
  'Email templates for system emails. Templates can be generic (product_id = NULL) 
   or product-specific (product_id IS NOT NULL). Product-specific templates 
   override generic templates when sending emails.';

COMMENT ON COLUMN public.email_templates.name IS 
  'Template identifier. Valid values: 
   - user_signup_confirmation: Email sent to user after signup to verify email
   - password_reset: Email sent to user to reset password
   - user_invitation: Email sent to invite user to register in a product
   - admin_new_user_notification: Email sent to super admin when new user registers';

COMMENT ON COLUMN public.email_templates.product_id IS 
  'Product ID if this is a product-specific template. NULL means generic template 
   that applies to all products. Product-specific templates override generic ones.';

COMMENT ON COLUMN public.email_templates.placeholders IS 
  'JSON array of available placeholders for this template. 
   Common placeholders: user_name, user_email, product_name, verification_link, 
   reset_link, invitation_link, organization_name, inviter_name, etc.';

-- Step 2: Create indexes
CREATE INDEX IF NOT EXISTS idx_email_templates_name ON public.email_templates(name);
CREATE INDEX IF NOT EXISTS idx_email_templates_product_id ON public.email_templates(product_id);
CREATE INDEX IF NOT EXISTS idx_email_templates_active ON public.email_templates(is_active) WHERE deleted_at IS NULL;

-- Step 3: Create function to get email template (generic or product-specific)
-- This function returns the product-specific template if it exists, otherwise the generic one
CREATE OR REPLACE FUNCTION public.get_email_template(
  p_template_name text,
  p_product_id uuid DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  name text,
  product_id uuid,
  subject text,
  body_html text,
  body_text text,
  placeholders jsonb,
  description text,
  is_active boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    et.id,
    et.name,
    et.product_id,
    et.subject,
    et.body_html,
    et.body_text,
    et.placeholders,
    et.description,
    et.is_active
  FROM public.email_templates et
  WHERE et.name = p_template_name
    AND et.deleted_at IS NULL
    AND et.is_active = true
    AND (
      -- If product_id is provided, try to get product-specific template first
      (p_product_id IS NOT NULL AND et.product_id = p_product_id)
      -- Otherwise, get generic template (product_id IS NULL)
      OR (p_product_id IS NULL AND et.product_id IS NULL)
      -- Or if no product-specific template exists, fallback to generic
      OR (p_product_id IS NOT NULL AND et.product_id IS NULL 
          AND NOT EXISTS (
            SELECT 1 FROM public.email_templates et2
            WHERE et2.name = p_template_name
              AND et2.product_id = p_product_id
              AND et2.deleted_at IS NULL
              AND et2.is_active = true
          ))
    )
  ORDER BY 
    -- Prioritize product-specific templates
    CASE WHEN et.product_id IS NOT NULL THEN 0 ELSE 1 END,
    et.updated_at DESC
  LIMIT 1;
END;
$$;

COMMENT ON FUNCTION public.get_email_template IS 
  'Gets an email template by name, optionally for a specific product.
   Returns product-specific template if it exists, otherwise returns generic template.
   Parameters:
   - p_template_name: Template identifier (e.g., "user_signup_confirmation")
   - p_product_id: Optional product ID for product-specific template
   
   Returns the most specific template available.';

-- Step 4: Create function to render template with placeholders
CREATE OR REPLACE FUNCTION public.render_email_template(
  p_template_name text,
  p_product_id uuid DEFAULT NULL,
  p_placeholders jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE (
  subject text,
  body_html text,
  body_text text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_template record;
  v_subject text;
  v_body_html text;
  v_body_text text;
  v_key text;
  v_value text;
BEGIN
  -- Get the template
  SELECT * INTO v_template
  FROM public.get_email_template(p_template_name, p_product_id);
  
  -- If template not found, return empty
  IF v_template.id IS NULL THEN
    RETURN;
  END IF;
  
  -- Initialize with template content
  v_subject := v_template.subject;
  v_body_html := v_template.body_html;
  v_body_text := COALESCE(v_template.body_text, '');
  
  -- Replace placeholders in subject
  FOR v_key, v_value IN SELECT * FROM jsonb_each_text(p_placeholders)
  LOOP
    v_subject := replace(v_subject, '{{' || v_key || '}}', COALESCE(v_value, ''));
    v_subject := replace(v_subject, '{{ ' || v_key || ' }}', COALESCE(v_value, ''));
  END LOOP;
  
  -- Replace placeholders in HTML body
  FOR v_key, v_value IN SELECT * FROM jsonb_each_text(p_placeholders)
  LOOP
    v_body_html := replace(v_body_html, '{{' || v_key || '}}', COALESCE(v_value, ''));
    v_body_html := replace(v_body_html, '{{ ' || v_key || ' }}', COALESCE(v_value, ''));
  END LOOP;
  
  -- Replace placeholders in text body
  IF v_body_text != '' THEN
    FOR v_key, v_value IN SELECT * FROM jsonb_each_text(p_placeholders)
    LOOP
      v_body_text := replace(v_body_text, '{{' || v_key || '}}', COALESCE(v_value, ''));
      v_body_text := replace(v_body_text, '{{ ' || v_key || ' }}', COALESCE(v_value, ''));
    END LOOP;
  END IF;
  
  RETURN QUERY SELECT v_subject, v_body_html, v_body_text;
END;
$$;

COMMENT ON FUNCTION public.render_email_template IS 
  'Renders an email template by replacing placeholders with provided values.
   Parameters:
   - p_template_name: Template identifier
   - p_product_id: Optional product ID for product-specific template
   - p_placeholders: JSON object with placeholder values (e.g., {"user_name": "John", "verification_link": "https://..."})
   
   Returns rendered subject, body_html, and body_text with placeholders replaced.';

-- Enable RLS (policies in later migration)
ALTER TABLE public.email_templates ENABLE ROW LEVEL SECURITY;

-- Step 5: Create trigger to update updated_at timestamp
CREATE TRIGGER update_email_templates_updated_at
  BEFORE UPDATE ON public.email_templates
  FOR EACH ROW
  EXECUTE FUNCTION moddatetime(updated_at);

-- Step 6: Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.email_templates TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_email_template(text, uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.render_email_template(text, uuid, jsonb) TO authenticated, anon;

-- Step 7: Insert default generic templates
INSERT INTO public.email_templates (name, subject, body_html, body_text, placeholders, description) VALUES
(
  'user_signup_confirmation',
  'Verify your email address - {{product_name}}',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Verify Your Email</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h1 style="color: #2563eb;">Welcome to {{product_name}}!</h1>
    <p>Hello {{user_name}},</p>
    <p>Thank you for registering with {{product_name}}. Please verify your email address by clicking the link below:</p>
    <p style="text-align: center; margin: 30px 0;">
      <a href="{{verification_link}}" style="background-color: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">Verify Email Address</a>
    </p>
    <p>Or copy and paste this link into your browser:</p>
    <p style="word-break: break-all; color: #2563eb;">{{verification_link}}</p>
    <p>This link will expire in 24 hours.</p>
    <p>If you did not create an account, please ignore this email.</p>
    <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
    <p style="color: #666; font-size: 12px;">Best regards,<br>{{product_name}} Team</p>
  </div>
</body>
</html>',
  'Welcome to {{product_name}}!

Hello {{user_name}},

Thank you for registering with {{product_name}}. Please verify your email address by clicking the link below:

{{verification_link}}

This link will expire in 24 hours.

If you did not create an account, please ignore this email.

Best regards,
{{product_name}} Team',
  '["user_name", "user_email", "product_name", "verification_link"]'::jsonb,
  'Email sent to user after signup to verify their email address'
),
(
  'password_reset',
  'Reset your password - {{product_name}}',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Reset Your Password</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h1 style="color: #2563eb;">Reset Your Password</h1>
    <p>Hello {{user_name}},</p>
    <p>We received a request to reset your password for your {{product_name}} account.</p>
    <p>Click the link below to reset your password:</p>
    <p style="text-align: center; margin: 30px 0;">
      <a href="{{reset_link}}" style="background-color: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">Reset Password</a>
    </p>
    <p>Or copy and paste this link into your browser:</p>
    <p style="word-break: break-all; color: #2563eb;">{{reset_link}}</p>
    <p>This link will expire in 1 hour.</p>
    <p>If you did not request a password reset, please ignore this email. Your password will remain unchanged.</p>
    <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
    <p style="color: #666; font-size: 12px;">Best regards,<br>{{product_name}} Team</p>
  </div>
</body>
</html>',
  'Reset Your Password

Hello {{user_name}},

We received a request to reset your password for your {{product_name}} account.

Click the link below to reset your password:

{{reset_link}}

This link will expire in 1 hour.

If you did not request a password reset, please ignore this email. Your password will remain unchanged.

Best regards,
{{product_name}} Team',
  '["user_name", "user_email", "product_name", "reset_link"]'::jsonb,
  'Email sent to user to reset their password'
),
(
  'user_invitation',
  'You have been invited to join {{product_name}}',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Invitation to {{product_name}}</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h1 style="color: #2563eb;">You have been invited!</h1>
    <p>Hello,</p>
    <p><strong>{{inviter_name}}</strong> has invited you to join <strong>{{product_name}}</strong>.</p>
    <p>You have been invited to join the organization: <strong>{{organization_name}}</strong></p>
    <p>Click the link below to accept the invitation and create your account:</p>
    <p style="text-align: center; margin: 30px 0;">
      <a href="{{invitation_link}}" style="background-color: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">Accept Invitation</a>
    </p>
    <p>Or copy and paste this link into your browser:</p>
    <p style="word-break: break-all; color: #2563eb;">{{invitation_link}}</p>
    <p>This invitation will expire in 7 days.</p>
    <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
    <p style="color: #666; font-size: 12px;">Best regards,<br>{{product_name}} Team</p>
  </div>
</body>
</html>',
  'You have been invited!

Hello,

{{inviter_name}} has invited you to join {{product_name}}.

You have been invited to join the organization: {{organization_name}}

Click the link below to accept the invitation and create your account:

{{invitation_link}}

This invitation will expire in 7 days.

Best regards,
{{product_name}} Team',
  '["inviter_name", "inviter_email", "product_name", "organization_name", "invitation_link", "user_role"]'::jsonb,
  'Email sent to invite a user to register in a product and join an organization'
),
(
  'admin_new_user_notification',
  'New user registered in {{product_name}}',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>New User Registration</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h1 style="color: #2563eb;">New User Registration</h1>
    <p>Hello Admin,</p>
    <p>A new user has registered in <strong>{{product_name}}</strong>:</p>
    <ul style="list-style: none; padding: 0;">
      <li><strong>Name:</strong> {{user_name}}</li>
      <li><strong>Email:</strong> {{user_email}}</li>
      <li><strong>Product:</strong> {{product_name}}</li>
      <li><strong>Registration Date:</strong> {{registration_date}}</li>
    </ul>
    <p>You can view the user details in the admin panel.</p>
    <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
    <p style="color: #666; font-size: 12px;">This is an automated notification from {{product_name}}.</p>
  </div>
</body>
</html>',
  'New User Registration

Hello Admin,

A new user has registered in {{product_name}}:

Name: {{user_name}}
Email: {{user_email}}
Product: {{product_name}}
Registration Date: {{registration_date}}

You can view the user details in the admin panel.

This is an automated notification from {{product_name}}.',
  '["user_name", "user_email", "product_name", "registration_date"]'::jsonb,
  'Email sent to super admin when a new user registers in a product'
);
