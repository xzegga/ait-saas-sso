-- ==============================================================================
-- 023 - OTP EMAIL TEMPLATES (from original 037)
-- ==============================================================================
-- user_signup_otp, password_reset_otp, user_welcome, password_reset_success
-- ==============================================================================

-- Insert OTP verification email template (generic)
INSERT INTO public.email_templates (name, product_id, subject, body_html, body_text, placeholders, description, is_active)
VALUES (
  'user_signup_otp',
  NULL, -- Generic template
  'Verify your email address',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Verify your email address</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background-color: #f4f4f4; padding: 20px; border-radius: 5px;">
    <h1 style="color: #333; margin-top: 0;">Verify your email address</h1>
    <p>Thank you for signing up! Please use the following code to verify your account:</p>
    <div style="background-color: #fff; border: 2px solid #ddd; border-radius: 5px; padding: 20px; text-align: center; margin: 20px 0;">
      <p style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #333; margin: 0;">{{verification_code}}</p>
    </div>
    <p>This code will expire in 1 hour. If you didn''t request this email, you can safely ignore it.</p>
    <p style="margin-top: 30px; font-size: 12px; color: #666;">This is an automated message, please do not reply to this email.</p>
  </div>
</body>
</html>',
  'Verify your email address

Thank you for signing up! Please use the following code to verify your account:

{{verification_code}}

This code will expire in 1 hour. If you didn''t request this email, you can safely ignore it.

This is an automated message, please do not reply to this email.',
  '["verification_code", "user_name", "user_email", "product_name"]'::jsonb,
  'Email sent to user after signup with OTP verification code',
  true
)
ON CONFLICT (name, product_id) DO UPDATE SET
  subject = EXCLUDED.subject,
  body_html = EXCLUDED.body_html,
  body_text = EXCLUDED.body_text,
  placeholders = EXCLUDED.placeholders,
  description = EXCLUDED.description,
  updated_at = now();

-- Insert password reset OTP email template (generic)
INSERT INTO public.email_templates (name, product_id, subject, body_html, body_text, placeholders, description, is_active)
VALUES (
  'password_reset_otp',
  NULL, -- Generic template
  'Reset your password',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reset your password</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background-color: #f4f4f4; padding: 20px; border-radius: 5px;">
    <h1 style="color: #333; margin-top: 0;">Reset your password</h1>
    <p>You requested to reset your password. Please use the following code to verify your identity:</p>
    <div style="background-color: #fff; border: 2px solid #ddd; border-radius: 5px; padding: 20px; text-align: center; margin: 20px 0;">
      <p style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #333; margin: 0;">{{verification_code}}</p>
    </div>
    <p>This code will expire in 1 hour. If you didn''t request this email, you can safely ignore it.</p>
    <p style="margin-top: 30px; font-size: 12px; color: #666;">This is an automated message, please do not reply to this email.</p>
  </div>
</body>
</html>',
  'Reset your password

You requested to reset your password. Please use the following code to verify your identity:

{{verification_code}}

This code will expire in 1 hour. If you didn''t request this email, you can safely ignore it.

This is an automated message, please do not reply to this email.',
  '["verification_code", "user_name", "user_email", "product_name"]'::jsonb,
  'Email sent to user for password reset with OTP verification code',
  true
)
ON CONFLICT (name, product_id) DO UPDATE SET
  subject = EXCLUDED.subject,
  body_html = EXCLUDED.body_html,
  body_text = EXCLUDED.body_text,
  placeholders = EXCLUDED.placeholders,
  description = EXCLUDED.description,
  updated_at = now();

-- Insert welcome email template (generic)
INSERT INTO public.email_templates (name, product_id, subject, body_html, body_text, placeholders, description, is_active)
VALUES (
  'user_welcome',
  NULL, -- Generic template
  'Welcome to our platform!',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Welcome to our platform!</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background-color: #f4f4f4; padding: 20px; border-radius: 5px;">
    <h1 style="color: #333; margin-top: 0;">Welcome to our platform!</h1>
    <p>Thank you for joining us, {{user_email}}! We''re excited to have you on board.</p>
    <p>You can now access all features of our platform. If you have any questions or need assistance, feel free to reach out to our support team.</p>
    <div style="text-align: center; margin: 30px 0;">
      <a href="{{dashboard_url}}" style="background-color: #007bff; color: #fff; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">Go to Dashboard</a>
    </div>
    <p style="margin-top: 30px; font-size: 12px; color: #666;">This is an automated message, please do not reply to this email.</p>
  </div>
</body>
</html>',
  'Welcome to our platform!

Thank you for joining us, {{user_email}}! We''re excited to have you on board.

You can now access all features of our platform. If you have any questions or need assistance, feel free to reach out to our support team.

Go to Dashboard: {{dashboard_url}}

This is an automated message, please do not reply to this email.',
  '["user_name", "user_email", "product_name", "dashboard_url", "organization_name"]'::jsonb,
  'Welcome email sent to user after successful email verification',
  true
)
ON CONFLICT (name, product_id) DO UPDATE SET
  subject = EXCLUDED.subject,
  body_html = EXCLUDED.body_html,
  body_text = EXCLUDED.body_text,
  placeholders = EXCLUDED.placeholders,
  description = EXCLUDED.description,
  updated_at = now();

-- Insert password reset success email template (generic)
INSERT INTO public.email_templates (name, product_id, subject, body_html, body_text, placeholders, description, is_active)
VALUES (
  'password_reset_success',
  NULL, -- Generic template
  'Your password has been reset',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Your password has been reset</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background-color: #f4f4f4; padding: 20px; border-radius: 5px;">
    <h1 style="color: #333; margin-top: 0;">Password Reset Successful</h1>
    <p>Hello {{user_email}}.</p>
    <p>Your password has been reset successfully. You can now sign in to your account with your new password.</p>
    <div style="text-align: center; margin: 30px 0;">
      <a href="{{signin_url}}" style="background-color: #007bff; color: #fff; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">Sign In</a>
    </div>
    <p style="background-color: #fff3cd; border: 1px solid #ffc107; border-radius: 5px; padding: 15px; margin: 20px 0;">
      <strong>Security Notice:</strong> If you did not reset your password, please contact us immediately as your account may have been compromised.
    </p>
    <p style="margin-top: 30px; font-size: 12px; color: #666;">This is an automated message, please do not reply to this email.</p>
  </div>
</body>
</html>',
  'Password Reset Successful

Hello {{user_email}}.

Your password has been reset successfully. You can now sign in to your account with your new password.

Sign In: {{signin_url}}

Security Notice: If you did not reset your password, please contact us immediately as your account may have been compromised.

This is an automated message, please do not reply to this email.',
  '["user_name", "user_email", "product_name", "signin_url"]'::jsonb,
  'Email sent to user after successful password reset',
  true
)
ON CONFLICT (name, product_id) DO UPDATE SET
  subject = EXCLUDED.subject,
  body_html = EXCLUDED.body_html,
  body_text = EXCLUDED.body_text,
  placeholders = EXCLUDED.placeholders,
  description = EXCLUDED.description,
  updated_at = now();

COMMENT ON TABLE public.email_templates IS 
  'Email templates for system emails. Templates can be generic (product_id = NULL) 
   or product-specific (product_id IS NOT NULL). Product-specific templates 
   override generic templates when sending emails.
   
   Template names:
   - user_signup_otp: OTP code for email verification after signup
   - password_reset_otp: OTP code for password reset verification
   - user_welcome: Welcome email after successful email verification
   - password_reset_success: Confirmation email after password reset';
