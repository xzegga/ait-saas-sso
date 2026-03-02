-- ==============================================================================
-- 015 - EMAIL HELPER: update_confirmation_sent_at
-- ==============================================================================
-- Further email logic: 022 email_sending_functions, 023 otp_email_templates,
-- 024 otp/welcome functions, 025 subscription_purchased_email.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.update_confirmation_sent_at(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public
AS $$
BEGIN
  UPDATE auth.users
  SET confirmation_sent_at = now()
  WHERE id = p_user_id
    AND email_confirmed_at IS NULL;

  IF NOT FOUND THEN
    RAISE NOTICE 'User % is already confirmed or does not exist', p_user_id;
  END IF;
END;
$$;

COMMENT ON FUNCTION public.update_confirmation_sent_at IS
  'Updates confirmation_sent_at in auth.users without confirming the user. Used to register that a confirmation email was sent.';

GRANT EXECUTE ON FUNCTION public.update_confirmation_sent_at(uuid) TO authenticated, anon, service_role;
