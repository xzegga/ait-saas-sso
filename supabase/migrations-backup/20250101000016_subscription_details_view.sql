-- ==============================================================================
-- SUBSCRIPTION DETAILS VIEW
-- ==============================================================================
-- View to display complete subscription information for admin panel
-- ==============================================================================

CREATE OR REPLACE VIEW public.v_subscription_details AS
SELECT 
  ops.id,
  o.name as org_name,
  o.id as org_id,
  o.billing_email as org_billing_email,
  p.name as product_name,
  p.id as product_id,
  p.client_id as product_client_id,
  pl.name as plan_name,
  pl.id as plan_id,
  pl.description as plan_description,
  ops.status,
  ops.quantity,
  ops.custom_entitlements,
  ops.trial_starts_at,
  ops.trial_ends_at,
  CASE 
    WHEN ops.status = 'trial' AND ops.trial_ends_at IS NOT NULL AND ops.trial_ends_at < now() THEN true
    ELSE false
  END as is_trial_expired,
  CASE
    WHEN ops.status = 'trial' AND ops.trial_ends_at IS NOT NULL THEN 
      GREATEST(0, EXTRACT(EPOCH FROM (ops.trial_ends_at - now())) / 86400)::integer
    ELSE NULL
  END as days_until_trial_expires,
  pp.price,
  pp.currency,
  ops.created_at,
  ops.updated_at
FROM public.org_product_subscriptions ops
JOIN public.organizations o ON ops.org_id = o.id
JOIN public.products p ON ops.product_id = p.id
JOIN public.plans pl ON ops.plan_id = pl.id
LEFT JOIN public.product_plans pp ON pp.product_id = p.id AND pp.plan_id = pl.id AND pp.deleted_at IS NULL
WHERE o.deleted_at IS NULL 
  AND p.deleted_at IS NULL 
  AND pl.deleted_at IS NULL;

-- Grant select permission to authenticated users
GRANT SELECT ON public.v_subscription_details TO authenticated;

COMMENT ON VIEW public.v_subscription_details IS 'Complete subscription information including organization, product, plan, pricing, and trial expiration details. Useful for admin panel displays.';
